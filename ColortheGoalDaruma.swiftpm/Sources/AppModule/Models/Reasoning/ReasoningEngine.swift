import Foundation

struct ReasoningSnapshot {
    let scores: [DarumaColor: Double]
    let confidence: Double
    let bestCandidate: DarumaColor?
    let lockedGuess: DarumaColor?
    let remainingQuestions: Int
}

struct AkinatorReasoner {
    private(set) var answers: [QuestionKey: ReasoningAnswer] = [:]
    private(set) var scores: [DarumaColor: Double] = [:]
    private(set) var confidence: Double = 0
    private(set) var lockedGuess: DarumaColor?

    init() {
        reset()
    }

    mutating func reset() {
        answers = [:]
        confidence = 0
        lockedGuess = nil
        scores = Dictionary(uniqueKeysWithValues: DarumaColor.allCases.map { ($0, 1.0) })
    }

    mutating func recordAnswer(for key: QuestionKey, answer: ReasoningAnswer) {
        answers[key] = answer
        guard let descriptor = ReasoningKnowledgeBase.questionMap[key] else {
            refreshConfidence()
            return
        }
        let (signal, normalizedAnswer) = descriptor.resolvedSignal(for: answer)
        let multiplier = ReasoningKnowledgeBase.multiplier(for: normalizedAnswer)
        for (color, profile) in ReasoningKnowledgeBase.candidates {
            let base = scores[color] ?? 1.0
            let weight = profile.weight(for: signal)
            let adjusted = max(0.05, base + weight * multiplier)
            scores[color] = adjusted
        }
        refreshConfidence()
    }

    func nextQuestionKey(excluding excluded: Set<QuestionKey> = []) -> QuestionKey? {
        let unansweredAll = ReasoningKnowledgeBase.orderedQuestions.filter { answers[$0.key] == nil }
        guard !unansweredAll.isEmpty else { return nil }

        let pool: [ReasoningQuestionDescriptor]
        let filtered = unansweredAll.filter { !excluded.contains($0.key) }
        if filtered.isEmpty {
            pool = unansweredAll
        } else {
            pool = filtered
        }

        if !answers.isEmpty,
           confidence < ReasoningKnowledgeBase.parameters.lowConfidenceThreshold,
           let fallback = pool.first(where: { $0.role == .fallback }) {
            return fallback.key
        }

        let scored = pool.map { descriptor -> (ReasoningQuestionDescriptor, Double) in
            (descriptor, informationGain(for: descriptor))
        }.sorted { $0.1 > $1.1 }

        guard let best = scored.first else { return nil }
        let threshold = best.1 * 0.82
        let viable = scored.filter { $0.1 >= threshold }
        return (viable.isEmpty ? scored : viable).randomElement()?.0.key
    }

    func remainingQuestionCount() -> Int {
        ReasoningKnowledgeBase.orderedQuestions.filter { answers[$0.key] == nil }.count
    }

    func snapshot() -> ReasoningSnapshot {
        let normalizedScores = normalized()
        let best = normalizedScores.max(by: { $0.value < $1.value })?.key
        return ReasoningSnapshot(
            scores: normalizedScores,
            confidence: confidence,
            bestCandidate: best,
            lockedGuess: lockedGuess,
            remainingQuestions: remainingQuestionCount()
        )
    }

    private mutating func refreshConfidence() {
        let normalizedScores = normalized()
        guard let bestEntry = normalizedScores.max(by: { $0.value < $1.value }) else {
            confidence = 0
            lockedGuess = nil
            return
        }
        confidence = bestEntry.value
        if confidence >= ReasoningKnowledgeBase.parameters.earlyGuessThreshold {
            lockedGuess = bestEntry.key
        } else {
            lockedGuess = nil
        }
    }

    private func normalized() -> [DarumaColor: Double] {
        var clipped: [DarumaColor: Double] = [:]
        for (color, score) in scores {
            clipped[color] = max(score, 0.05)
        }
        let total = clipped.values.reduce(0, +)
        guard total > 0 else {
            let fallbackValue = 1.0 / Double(DarumaColor.allCases.count)
            return Dictionary(uniqueKeysWithValues: DarumaColor.allCases.map { ($0, fallbackValue) })
        }
        return clipped.mapValues { $0 / total }
    }

    private func informationGain(for descriptor: ReasoningQuestionDescriptor) -> Double {
        let probabilities = normalized()
        return probabilities.reduce(0) { partialResult, entry in
            guard let profile = ReasoningKnowledgeBase.candidates[entry.key] else {
                return partialResult
            }
            let primaryWeight = abs(profile.weight(for: descriptor.signal))
            let counterWeight = descriptor.counterSignal.map { abs(profile.weight(for: $0)) } ?? 0
            let magnitude = max(primaryWeight, counterWeight)
            return partialResult + magnitude * entry.value * descriptor.decisiveness
        }
    }
}
