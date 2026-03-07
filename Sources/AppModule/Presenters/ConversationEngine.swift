import Foundation
import Observation

enum ConversationPhase {
    case inProgress           // 診断中（質問）
    case writingBeforeDiagnosis  // 診断前に願い事を書く（「はい」の場合）
    case ocrConfirmation      // OCR結果の確認
    case result               // 結果
    case ritualOnboarding     // 願い事書き+目入れの説明画面
    case writingAfterResult   // 結果後に願い事を書く
    case drawingEye           // だるまの右目を描く（2回目）
    case drawingLeftEye       // だるまの左目を描く（1回目）
    case closing              // AR後のクロージング
    case congratulations      // 左目描き完了後のおめでとう画面
}

struct ConversationProgress {
    var answered: Int
    var remaining: Int
    var targetTotal: Int

    var total: Int {
        max(targetTotal, 1)
    }

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(answered) / Double(total), 0), 1)
    }
}

struct PresentedQuestion: Identifiable {
    let id = UUID()
    let key: QuestionKey
    var prompt: String
    let responseKind: QuestionResponseKind
    let choices: [QuestionChoice]
    let messageID: UUID
}

@MainActor
final class ConversationEngine: ObservableObject {
    @Published var phase: ConversationPhase = .inProgress {
        didSet { updateStepBackAvailability() }
    }
    @Published var messages: [ChatMessage] = []
    @Published var presentedQuestion: PresentedQuestion?
    @Published var isProcessing: Bool = false
    @Published var result: DarumaResult?
    @Published var ocrText: String = ""  // OCRで解析したテキスト
    @Published var ocrConfirmationStartsInManualEdit: Bool = false
    @Published var ocrFailureMessage: String?
    @Published private(set) var progressState = ConversationProgress(answered: 0, remaining: 1, targetTotal: 1)
    @Published private(set) var reasoningConfidence: Double = 0
    @Published private(set) var reasoningGuess: DarumaColor?
    @Published private(set) var lockedGuess: DarumaColor?
    @Published private(set) var reasoningScores: [DarumaColor: Double] = [:]
    @Published var shouldProceedToEyeAfterResult: Bool = false
    @Published private(set) var canStepBackOneQuestion: Bool = false

    private var wishState = WishState()
    private var askedKeys: Set<QuestionKey> = []
    private var answerRecords: [AnswerRecord] = []
    private var turnCount: Int = 0
    private var reasoner = AkinatorReasoner()
    private var supplementalQueue: [QuestionKey] = []
    private var clarityFollowUpQueue: [QuestionKey] = []
    private var wishIsCleared: Bool? = nil  // 願いが明確かどうか（nil=未回答、true=明確、false=不明確）
    private var categorySelected: Bool = false  // カテゴリが選択されたか
    private var pendingQuestionKey: QuestionKey?
    private var questionHistory: [ConversationCheckpoint] = [] {
        didSet { updateStepBackAvailability() }
    }
    private var recentQuestionKeys: [QuestionKey] = []

    private let fmClient = ConversationCopyClient.shared
    private let resolver = DarumaColorResolver()
    private let logStore = LocalLogStore()

    private let minTurnsBeforeResult = 2
    private let maxTurns = 5
    private let initialQuestionCount = 2

    init() {
    }

    func start() {
        resetState()
        phase = .inProgress
        appendSystemIntro()
        askNextQuestion()
    }

    func reset() {
        resetState()
        phase = .inProgress
        start()
    }

    func moveToWritingAfterResult() {
        phase = .writingAfterResult
    }

    func moveToDrawingEye() {
        shouldProceedToEyeAfterResult = false
        phase = .drawingEye
    }

    func moveToClosing() {
        phase = .closing
    }

    /// Result画面のNextStepから儀式説明画面へ遷移
    func moveToRitualOnboarding() {
        phase = .ritualOnboarding
    }

    /// Closing画面から左目描き画面へ遷移
    func moveToDrawingLeftEye() {
        phase = .drawingLeftEye
    }

    /// 左目描き完了後のおめでとう画面へ遷移
    func moveToCongratulations() {
        phase = .congratulations
    }

    func moveToWritingBeforeDiagnosis() {
        phase = .writingBeforeDiagnosis
    }

    /// 診断前の手書きステップから「願い事は決まってますか？」へ戻す
    func returnToWishClarityQuestionFromWriting() {
        guard phase == .writingBeforeDiagnosis else { return }
        shouldProceedToEyeAfterResult = false
        wishIsCleared = nil
        presentedQuestion = nil
        pendingQuestionKey = nil
        recentQuestionKeys.removeAll()
        askedKeys.remove(.initialWishClarityCheck)
        phase = .inProgress
        askNextQuestion()
    }

    func stepBackOneQuestion() {
        guard phase == .inProgress, questionHistory.count >= 2 else { return }
        questionHistory.removeLast()
        guard let checkpoint = questionHistory.last else { return }
        restore(from: checkpoint)
    }

    func processOCRText(_ text: String) {
        ocrText = text
        ocrConfirmationStartsInManualEdit = false
        ocrFailureMessage = nil
        phase = .ocrConfirmation
    }

    func presentManualEntryAfterOCRFailure(errorMessage: String) {
        ocrText = ""
        ocrConfirmationStartsInManualEdit = true
        ocrFailureMessage = errorMessage
        phase = .ocrConfirmation
    }

    func confirmOCRText() {
        // OCRテキストが正しいと確認された場合、診断を開始
        let confirmedText = ocrText
        clearOCRConfirmationState()
        processWishInputAndFinalize(using: confirmedText)
    }

    func rejectOCRTextAndUseManualInput(_ manualText: String) {
        // OCRテキストが間違っていて、手動入力された場合
        clearOCRConfirmationState()
        processWishInputAndFinalize(using: manualText)
    }

    func returnToWritingBeforeDiagnosisFromOCRConfirmation() {
        guard phase == .ocrConfirmation else { return }
        clearOCRConfirmationState()
        phase = .writingBeforeDiagnosis
    }

    private func processWishInputAndFinalize(using text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        wishState.rawNotes.append(trimmed)
        wishState.setWishSentence(trimmed)
        recordAnswer(text: trimmed, for: .wishInput)
        isProcessing = true
        let summary = wishState.summaryForPrompt()

        Task { [weak self] in
            await self?.finalizeWishInputProcessing(trimmedText: trimmed, summary: summary)
        }
    }

    @MainActor
    private func finalizeWishInputProcessing(trimmedText: String, summary: String) async {
        if let signals = await fmClient.extractSignals(from: trimmedText, stateSummary: summary) {
            applySignals(signals)
        }
        finalizeConversation()
    }

    func selectChoice(_ choice: QuestionChoice) {
        guard let question = presentedQuestion else { return }
        isProcessing = true
        appendUserMessage(choice.title)
        recordAnswer(text: choice.title, for: question.key)

        // カテゴリ選択の処理
        if question.key == .initialCategorySelection {
            categorySelected = true
            applyImpact(choice.impact)  // 「該当なし」以外ならカテゴリスコアが設定される
            presentedQuestion = nil
            isProcessing = false
            advanceConversation()
            return
        }

        // 初期質問の場合、願いの明確さを記録
        if question.key == .initialWishClarityCheck {
            wishIsCleared = (choice.canonicalTitle == "Yes")
            shouldProceedToEyeAfterResult = wishIsCleared == true
            presentedQuestion = nil
            isProcessing = false

            if wishIsCleared == true {
                moveToWritingBeforeDiagnosis()
                return
            }

            advanceConversation()
            return
        }

        applyImpact(choice.impact)
        let reasoningValue = choice.reasoningAnswer ?? .unknown
        reasoner.recordAnswer(for: question.key, answer: reasoningValue)
        updateReasoningSnapshot()
        presentedQuestion = nil
        turnCount += 1
        isProcessing = false
        advanceConversation()
    }

    func submitFreeformAnswer(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let question = presentedQuestion else { return }
        isProcessing = true
        appendUserMessage(trimmed)
        recordAnswer(text: trimmed, for: question.key)
        wishState.rawNotes.append(trimmed)
        if question.key == .wishInput {
            wishState.setWishSentence(trimmed)
        }
        presentedQuestion = nil
        turnCount += 1

        Task {
            let summary = self.wishState.summaryForPrompt()
            if let signals = await self.fmClient.extractSignals(from: trimmed, stateSummary: summary) {
                await MainActor.run {
                    self.applySignals(signals)
                }
            }
            await MainActor.run {
                self.isProcessing = false
                self.advanceConversation()
            }
        }
    }

    func skipCurrentQuestion() {
        guard let question = presentedQuestion else { return }
        appendUserMessage("Nothing to add right now")
        recordAnswer(text: "SKIP", for: question.key)
        reasoner.recordAnswer(for: question.key, answer: .unknown)
        updateReasoningSnapshot()
        presentedQuestion = nil
        turnCount += 1
        advanceConversation()
    }

    private func resetState() {
        wishState = WishState()
        askedKeys = []
        answerRecords = []
        turnCount = 0
        messages = []
        presentedQuestion = nil
        result = nil
        ocrText = ""
        ocrConfirmationStartsInManualEdit = false
        ocrFailureMessage = nil
        isProcessing = false
        reasoner.reset()
        supplementalQueue = []
        clarityFollowUpQueue = [.freeAnswer1, .freeAnswer2]
        wishIsCleared = nil  // 願いの明確さをリセット
        categorySelected = false  // カテゴリ選択をリセット
        shouldProceedToEyeAfterResult = false
        pendingQuestionKey = nil
        questionHistory.removeAll()
        recentQuestionKeys = []
        updateReasoningSnapshot()
        phase = .inProgress
        updateProgressState()
    }

    private func appendSystemIntro() {
        let intro = ChatMessage(
            sender: .assistant,
            text: "Hello! We'll clarify your wish together and find the Daruma color that fits best. Answer at your own pace."
        )
        messages.append(intro)
    }

    private func appendAssistantMessage(_ text: String) -> ChatMessage {
        let message = ChatMessage(sender: .assistant, text: text)
        messages.append(message)
        return message
    }

    private func appendUserMessage(_ text: String) {
        let message = ChatMessage(sender: .user, text: text)
        messages.append(message)
    }

    private func recordAnswer(text: String, for key: QuestionKey) {
        answerRecords.append(AnswerRecord(key: key, response: text))
    }

    private func askNextQuestion() {
        guard phase != .result else { return }

        var nextKey: QuestionKey?

        // 0. 願いの明確さチェックを最優先で聞く
        if wishIsCleared == nil {
            nextKey = .initialWishClarityCheck
        }
        // 1. 最初の質問：カテゴリ選択
        else if !categorySelected {
            nextKey = .initialCategorySelection
        }
        // 2. カテゴリ選択後、「該当なし」が選ばれた場合 → 自由記述へ
        else if categorySelected && wishState.topCategory == nil && !askedKeys.contains(.wishInput) {
            nextKey = .wishInput
        }
        // 3. 自由記述完了後は結果へ
        else if categorySelected && wishState.topCategory == nil && askedKeys.contains(.wishInput) {
            finalizeConversation()
            return
        }
        // 4. カテゴリ選択済み → 通常の質問フロー
        else if categorySelected && wishState.topCategory != nil {
            nextKey = reasoner.nextQuestionKey()
            if nextKey == nil {
                nextKey = nextSupplementalQuestionKey()
            }
        }

        if let candidateKey = nextKey, shouldAvoidRepetition(for: candidateKey) {
            let exclusion = Set(recentQuestionKeys + [candidateKey])
            if let alternate = reasoner.nextQuestionKey(excluding: exclusion) {
                nextKey = alternate
            } else {
                enqueueSupplementalQuestions(excluding: exclusion)
                if let supplemental = nextSupplementalQuestionKey() {
                    nextKey = supplemental
                }
            }
        }

        guard let confirmedKey = nextKey,
              let spec = QuestionLibrary.specs[confirmedKey] else {
            finalizeConversation()
            return
        }

        askedKeys.insert(confirmedKey)
        pendingQuestionKey = confirmedKey
        isProcessing = true
        updateProgressState()

        if spec.allowNaturalization {
            Task {
                print("🔍 [ConversationEngine] Calling naturalizeQuestion for spec: \(spec.key.rawValue)")
                print("🔍 [ConversationEngine] Base prompt: \(spec.prompt)")
                let summary = wishState.summaryForPrompt()
                let (naturalizedQuestion, naturalizedChoices) = await fmClient.naturalizeQuestion(
                    for: spec,
                    stateSummary: summary,
                    recentKeys: recentQuestionKeys
                )
                print("🔍 [ConversationEngine] Got naturalized question: \(naturalizedQuestion)")
                print("🔍 [ConversationEngine] Got naturalized choices count: \(naturalizedChoices.count)")
                await MainActor.run {
                    self.presentQuestion(spec: spec, prompt: naturalizedQuestion, choices: naturalizedChoices)
                }
            }
        } else {
            presentQuestion(spec: spec, prompt: spec.prompt, choices: spec.choices)
        }
    }

    private func presentQuestion(spec: QuestionSpec, prompt: String, choices: [QuestionChoice]) {
        guard pendingQuestionKey == spec.key else {
            print("⚠️ [ConversationEngine] Pending question mismatch, skipping presentation")
            if pendingQuestionKey == nil && phase == .inProgress {
                isProcessing = false
                updateProgressState()
            }
            return
        }
        pendingQuestionKey = nil
        let polishedPrompt = polishedQuestionText(prompt)
        presentedQuestion = PresentedQuestion(
            key: spec.key,
            prompt: polishedPrompt,
            responseKind: spec.responseKind,
            choices: choices,
            messageID: UUID()
        )
        isProcessing = false
        print("✅ [ConversationEngine] Updated presentedQuestion with: \(polishedPrompt)")
        trackRecentQuestion(spec.key)

        _ = appendAssistantMessage(polishedPrompt)
        updateProgressState()
        recordCheckpoint()
    }

    private func polishedQuestionText(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return "Shall we move to the next question?"
        }
        text = text.replacingOccurrences(of: "？", with: "?")
        if !text.hasSuffix("?") {
            text += "?"
        }
        return text
    }

    private func nextClarityFollowUpKey() -> QuestionKey? {
        while !clarityFollowUpQueue.isEmpty {
            let candidate = clarityFollowUpQueue.removeFirst()
            if askedKeys.contains(candidate) {
                continue
            }
            return candidate
        }
        return nil
    }

    private func nextSupplementalQuestionKey() -> QuestionKey? {
        while !supplementalQueue.isEmpty {
            let candidate = supplementalQueue.removeFirst()
            if askedKeys.contains(candidate) {
                continue
            }
            return candidate
        }
        return nil
    }

    private func enqueueSupplementalQuestions(excluding exclusion: Set<QuestionKey>) {
        let forbidden = askedKeys.union(exclusion)
        let orderedKeys = ReasoningKnowledgeBase.orderedQuestions.map { $0.key }
        let available = orderedKeys.filter { !forbidden.contains($0) && !supplementalQueue.contains($0) }
        guard !available.isEmpty else { return }
        supplementalQueue.append(contentsOf: available.shuffled().prefix(2))
    }

    private func shouldAvoidRepetition(for key: QuestionKey) -> Bool {
        recentQuestionKeys.contains(key)
    }

    private func updateProgressState() {
        let target = targetQuestionCountForProgress()
        var answered = min(answeredQuestionCountForProgress(), target)
        var remaining = max(target - answered, 0)
        if phase == .result {
            answered = target
            remaining = 0
        }
        progressState = ConversationProgress(
            answered: answered,
            remaining: remaining,
            targetTotal: target
        )
    }

    private func answeredQuestionCountForProgress() -> Int {
        let trackedKeys = Set(ReasoningKnowledgeBase.orderedQuestions.map(\.key) + [
            .initialWishClarityCheck,
            .initialCategorySelection,
            .wishInput
        ])
        return answerRecords.reduce(into: 0) { count, record in
            if trackedKeys.contains(record.key) {
                count += 1
            }
        }
    }

    private func targetQuestionCountForProgress() -> Int {
        if categorySelected && wishState.topCategory == nil {
            return max(initialQuestionCount + 1, 1)
        }
        return max(initialQuestionCount + maxTurns, 1)
    }

    private func trackRecentQuestion(_ key: QuestionKey) {
        recentQuestionKeys.append(key)
        let maxCount = 4
        if recentQuestionKeys.count > maxCount {
            recentQuestionKeys.removeFirst(recentQuestionKeys.count - maxCount)
        }
    }

    private func updateReasoningSnapshot() {
        let snapshot = reasoner.snapshot()
        reasoningConfidence = snapshot.confidence
        reasoningGuess = snapshot.bestCandidate
        lockedGuess = snapshot.lockedGuess
        reasoningScores = snapshot.scores
    }

    private func applyImpact(_ impact: ScoreImpact) {
        for (category, delta) in impact.categoryDeltas {
            wishState.add(category: category, delta: delta)
        }
        for (stance, delta) in impact.stanceDeltas {
            wishState.add(stance: stance, delta: delta)
        }
        if let deadline = impact.deadline {
            wishState.deadline = deadline
        }
        if let obstacle = impact.obstacle {
            wishState.obstacle = obstacle
        }
    }

    private func applySignals(_ signals: ExtractedSignals) {
        if let category = signals.inferredCategory {
            let delta = signals.confidence >= 0.6 ? 1.2 : 0.6
            wishState.add(category: category, delta: delta)
        }
        if let stance = signals.inferredStance {
            let delta = signals.confidence >= 0.6 ? 1.0 : 0.4
            wishState.add(stance: stance, delta: delta)
        }
        if let deadline = signals.deadline, wishState.deadline == nil {
            wishState.deadline = deadline
        }
        if let obstacle = signals.obstacle, wishState.obstacle == nil {
            wishState.obstacle = obstacle
        }
        if !signals.keywords.isEmpty {
            wishState.rawNotes.append(signals.keywords.joined(separator: " "))
        }
    }

    private func reinforceWishState(for color: DarumaColor) {
        guard let profile = ReasoningKnowledgeBase.candidates[color] else { return }
        for (signal, weight) in profile.signalWeights {
            switch signal {
            case .category(let category):
                wishState.add(category: category, delta: weight * 1.2)
            case .stance(let stance):
                wishState.add(stance: stance, delta: weight)
            case .urgent:
                wishState.deadline = .short
            case .longTerm:
                wishState.deadline = .long
            }
        }
        if wishState.deadline == nil {
            wishState.deadline = .mid
        }
    }

    private func advanceConversation() {
        if shouldFinalizeConversation() {
            finalizeConversation()
        } else {
            askNextQuestion()
        }
        updateProgressState()
    }

    private func shouldFinalizeConversation() -> Bool {
        if turnCount >= maxTurns {
            return true
        }
        let snapshot = reasoner.snapshot()
        if let _ = snapshot.lockedGuess, turnCount >= minTurnsBeforeResult {
            return true
        }
        if snapshot.remainingQuestions == 0 && supplementalQueue.isEmpty && presentedQuestion == nil {
            return true
        }
        return false
    }

    private func finalizeConversation() {
        guard phase != .result else { return }
        presentedQuestion = nil
        pendingQuestionKey = nil
        isProcessing = true
        let snapshot = reasoner.snapshot()

        // 色判定の優先順位: キーワードマッチング → Akinator推論 → ルールベース
        let matcher = KeywordColorMatcher()
        let color: DarumaColor
        if let matchedColor = matcher.matchColor(from: wishState) {
            // キーワードマッチング優先
            color = matchedColor
        } else if let lockedGuess = snapshot.lockedGuess {
            // Akinator推論エンジン
            color = lockedGuess
        } else {
            // ルールベースリゾルバー
            color = resolver.resolveColor(from: wishState)
        }

        reinforceWishState(for: color)
        Task {
            let copy = await fmClient.generateResultCopy(color: color, state: wishState)
            let darumaResult = DarumaResult(
                color: color,
                wishSummary: copy.wishSummary,
                reason: copy.reason,
                darumaWord: copy.darumaWord,
                nextStep: copy.nextStep,
                stopDoing: copy.stopDoing,
                categoryScores: wishState.categoryScore
            )
            await MainActor.run {
                self.result = darumaResult
                self.phase = .result
                self.isProcessing = false
                self.updateProgressState()
            }
            logStore.append(log: ConversationLog(
                answers: self.answerRecords,
                color: color,
                wishSummary: copy.wishSummary
            ))
        }
    }

    private func recordCheckpoint() {
        guard phase == .inProgress, let presentedQuestion else { return }
        let checkpoint = ConversationCheckpoint(
            wishState: wishState,
            reasoner: reasoner,
            askedKeys: askedKeys,
            answerRecords: answerRecords,
            turnCount: turnCount,
            messages: messages,
            presentedQuestion: presentedQuestion,
            pendingQuestionKey: pendingQuestionKey,
            supplementalQueue: supplementalQueue,
            clarityFollowUpQueue: clarityFollowUpQueue,
            categorySelected: categorySelected,
            wishIsCleared: wishIsCleared,
            shouldProceedToEyeAfterResult: shouldProceedToEyeAfterResult,
            recentQuestionKeys: recentQuestionKeys
        )
        questionHistory.append(checkpoint)
    }

    private func restore(from checkpoint: ConversationCheckpoint) {
        wishState = checkpoint.wishState
        reasoner = checkpoint.reasoner
        askedKeys = checkpoint.askedKeys
        answerRecords = checkpoint.answerRecords
        turnCount = checkpoint.turnCount
        messages = checkpoint.messages
        presentedQuestion = checkpoint.presentedQuestion
        pendingQuestionKey = checkpoint.pendingQuestionKey
        supplementalQueue = checkpoint.supplementalQueue
        clarityFollowUpQueue = checkpoint.clarityFollowUpQueue
        categorySelected = checkpoint.categorySelected
        wishIsCleared = checkpoint.wishIsCleared
        shouldProceedToEyeAfterResult = checkpoint.shouldProceedToEyeAfterResult
        recentQuestionKeys = checkpoint.recentQuestionKeys
        isProcessing = false
        updateReasoningSnapshot()
        updateProgressState()
    }

    private func updateStepBackAvailability() {
        canStepBackOneQuestion = phase == .inProgress && questionHistory.count >= 2
    }

    private func clearOCRConfirmationState() {
        ocrText = ""
        ocrConfirmationStartsInManualEdit = false
        ocrFailureMessage = nil
    }
}

private struct ConversationCheckpoint {
    let wishState: WishState
    let reasoner: AkinatorReasoner
    let askedKeys: Set<QuestionKey>
    let answerRecords: [AnswerRecord]
    let turnCount: Int
    let messages: [ChatMessage]
    let presentedQuestion: PresentedQuestion?
    let pendingQuestionKey: QuestionKey?
    let supplementalQueue: [QuestionKey]
    let clarityFollowUpQueue: [QuestionKey]
    let categorySelected: Bool
    let wishIsCleared: Bool?
    let shouldProceedToEyeAfterResult: Bool
    let recentQuestionKeys: [QuestionKey]
}
