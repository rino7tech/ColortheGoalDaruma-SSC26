import Foundation

struct ExtractedSignals: Codable {
    var inferredCategory: WishCategory?
    var inferredStance: WishStance?
    var deadline: Deadline?
    var obstacle: Obstacle?
    var keywords: [String]
    var confidence: Double

    init(
        inferredCategory: WishCategory? = nil,
        inferredStance: WishStance? = nil,
        deadline: Deadline? = nil,
        obstacle: Obstacle? = nil,
        keywords: [String] = [],
        confidence: Double = 0
    ) {
        self.inferredCategory = inferredCategory
        self.inferredStance = inferredStance
        self.deadline = deadline
        self.obstacle = obstacle
        self.keywords = keywords
        self.confidence = confidence
    }
}

struct ResultCopy: Codable {
    var wishSummary: String
    var reason: String
    var darumaWord: String
    var nextStep: String
    var stopDoing: String
}

actor ConversationCopyClient {
    static let shared = ConversationCopyClient()

    private let fallbackWords = ["Bold", "Shield", "Flow", "Bond"]

    func naturalizeQuestion(
        for spec: QuestionSpec,
        stateSummary: String,
        recentKeys: [QuestionKey] = []
    ) async -> (questionText: String, choices: [QuestionChoice]) {
        _ = stateSummary
        _ = recentKeys
        return (questionText: spec.prompt, choices: spec.choices)
    }

    func extractSignals(from text: String, stateSummary: String) async -> ExtractedSignals? {
        _ = stateSummary
        return heuristicSignals(from: text)
    }

    func generateResultCopy(color: DarumaColor, state: WishState) async -> ResultCopy {
        let summary = fallbackWishSentence(from: state)
        let reason = [
            "\(state.topCategory?.label ?? "Your wish") with a \(state.topStance?.label ?? "balanced") stance matches this color.",
            "The timeframe is \(state.deadline?.label ?? "flexible"), with \(state.obstacle?.label ?? "an unclear obstacle") as the main blocker."
        ].joined(separator: "\n")
        return ResultCopy(
            wishSummary: summary,
            reason: reason,
            darumaWord: fallbackWord(for: state),
            nextStep: "Spend 15 minutes on the first concrete action.",
            stopDoing: "Stop delaying the one task you already know."
        )
    }

    private func heuristicSignals(from text: String) -> ExtractedSignals {
        let lowered = text.lowercased()
        var signal = ExtractedSignals(
            keywords: Array(text.split(separator: " ").prefix(4)).map(String.init),
            confidence: 0.4
        )
        if lowered.contains("relationship") || lowered.contains("love") || lowered.contains("marriage") {
            signal.inferredCategory = .relationship
            signal.confidence = 0.7
        } else if lowered.contains("health") || lowered.contains("body") || lowered.contains("wellness") {
            signal.inferredCategory = .health
            signal.confidence = 0.7
        } else if lowered.contains("income") || lowered.contains("work") || lowered.contains("business") {
            signal.inferredCategory = .money
            signal.confidence = 0.7
        }
        if lowered.contains("protect") || lowered.contains("defend") || lowered.contains("anxiety") {
            signal.inferredStance = .defend
        } else if lowered.contains("challenge") || lowered.contains("win") || lowered.contains("compete") {
            signal.inferredStance = .attack
        }
        if lowered.contains("soon") || lowered.contains("this month") || lowered.contains("urgent") {
            signal.deadline = .short
        } else if lowered.contains("half year") || lowered.contains("six months") {
            signal.deadline = .mid
        }
        if lowered.contains("time") || lowered.contains("schedule") {
            signal.obstacle = .time
        } else if lowered.contains("money") || lowered.contains("budget") {
            signal.obstacle = .money
        }
        return signal
    }

    private func fallbackWishSentence(from state: WishState) -> String {
        if let wish = state.wishSentence, !wish.isEmpty {
            return wish
        }
        let category = state.topCategory?.label ?? "wish"
        let stance = state.topStance?.label.lowercased() ?? "balanced"
        return "A \(stance) step toward your \(category.lowercased()) goal."
    }

    private func fallbackWord(for state: WishState) -> String {
        if let category = state.topCategory {
            return category.label
        }
        return fallbackWords.randomElement() ?? "Focus"
    }
}
