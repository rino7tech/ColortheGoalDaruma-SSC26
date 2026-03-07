import Foundation

enum ReasoningQuestionRole {
    case primary
    case fallback
}

enum ReasoningSignal: Hashable {
    case category(WishCategory)
    case stance(WishStance)
    case urgent
    case longTerm
}

struct CandidateProfile {
    let color: DarumaColor
    let signalWeights: [ReasoningSignal: Double]

    func weight(for signal: ReasoningSignal) -> Double {
        signalWeights[signal, default: 0]
    }
}

struct ReasoningQuestionDescriptor {
    let key: QuestionKey
    let signal: ReasoningSignal
    let counterSignal: ReasoningSignal?
    let role: ReasoningQuestionRole
    let decisiveness: Double

    init(
        key: QuestionKey,
        signal: ReasoningSignal,
        counterSignal: ReasoningSignal? = nil,
        role: ReasoningQuestionRole = .primary,
        decisiveness: Double = 1.0
    ) {
        self.key = key
        self.signal = signal
        self.counterSignal = counterSignal
        self.role = role
        self.decisiveness = decisiveness
    }

    func resolvedSignal(for answer: ReasoningAnswer) -> (ReasoningSignal, ReasoningAnswer) {
        if answer == .no, let counterSignal {
            return (counterSignal, .yes)
        }
        return (signal, answer)
    }
}

struct ReasoningParameters {
    let yesMultiplier: Double
    let noMultiplier: Double
    let unknownPenalty: Double
    let lowConfidenceThreshold: Double
    let earlyGuessThreshold: Double

    static let `default` = ReasoningParameters(
        yesMultiplier: 1.0,
        noMultiplier: -0.8,
        unknownPenalty: -0.2,
        lowConfidenceThreshold: 0.38,
        earlyGuessThreshold: 0.72
    )
}

enum ReasoningKnowledgeBase {
    static let parameters = ReasoningParameters.default

    static let candidates: [DarumaColor: CandidateProfile] = {
        var dict: [DarumaColor: CandidateProfile] = [:]
        dict[.gold] = CandidateProfile(
            color: .gold,
            signalWeights: [
                .category(.achievement): 0.9,
                .stance(.attack): 0.85,
                .urgent: 0.8
            ]
        )
        dict[.red] = CandidateProfile(
            color: .red,
            signalWeights: [
                .category(.achievement): 0.6,
                .stance(.attack): 0.5,
                .urgent: 0.4
            ]
        )
        dict[.blue] = CandidateProfile(
            color: .blue,
            signalWeights: [
                .category(.achievement): 0.8,
                .stance(.attack): 0.7,
                .longTerm: 0.5
            ]
        )
        dict[.orange] = CandidateProfile(
            color: .orange,
            signalWeights: [
                .category(.achievement): 0.7,
                .stance(.balance): 0.6,
                .longTerm: 0.4
            ]
        )
        dict[.yellow] = CandidateProfile(
            color: .yellow,
            signalWeights: [
                .category(.money): 0.9,
                .stance(.attack): 0.4
            ]
        )
        dict[.pink] = CandidateProfile(
            color: .pink,
            signalWeights: [
                .category(.relationship): 0.85,
                .stance(.balance): 0.4
            ]
        )
        dict[.purple] = CandidateProfile(
            color: .purple,
            signalWeights: [
                .category(.relationship): 0.8,
                .stance(.defend): 0.6
            ]
        )
        dict[.green] = CandidateProfile(
            color: .green,
            signalWeights: [
                .category(.health): 0.9,
                .stance(.balance): 0.5
            ]
        )
        dict[.white] = CandidateProfile(
            color: .white,
            signalWeights: [
                .category(.learning): 0.9,
                .stance(.balance): 0.4,
                .longTerm: 0.4
            ]
        )
        dict[.silver] = CandidateProfile(
            color: .silver,
            signalWeights: [
                .category(.reset): 0.9,
                .stance(.balance): 0.6
            ]
        )
        dict[.black] = CandidateProfile(
            color: .black,
            signalWeights: [
                .category(.protection): 0.9,
                .stance(.defend): 0.7,
                .urgent: 0.3
            ]
        )
        return dict
    }()

    static let orderedQuestions: [ReasoningQuestionDescriptor] = [
        ReasoningQuestionDescriptor(
            key: .resultVsState,
            signal: .stance(.attack),
            role: .primary,
            decisiveness: 0.95
        ),
        ReasoningQuestionDescriptor(
            key: .momentumPreference,
            signal: .stance(.attack),
            counterSignal: .stance(.defend),
            role: .primary,
            decisiveness: 0.9
        ),
        ReasoningQuestionDescriptor(
            key: .avoidWorstVsGetBest,
            signal: .stance(.defend),
            role: .primary,
            decisiveness: 0.9
        ),
        ReasoningQuestionDescriptor(
            key: .deadline,
            signal: .urgent,
            counterSignal: .longTerm,
            role: .primary,
            decisiveness: 0.85
        ),
        ReasoningQuestionDescriptor(
            key: .moneyFocus,
            signal: .category(.money),
            role: .primary,
            decisiveness: 0.88
        ),
        ReasoningQuestionDescriptor(
            key: .relationshipTemperature,
            signal: .category(.relationship),
            role: .primary,
            decisiveness: 0.8
        ),
        ReasoningQuestionDescriptor(
            key: .healthFocus,
            signal: .category(.health),
            role: .primary,
            decisiveness: 0.75
        ),
        ReasoningQuestionDescriptor(
            key: .studyHabit,
            signal: .category(.learning),
            role: .primary,
            decisiveness: 0.7
        ),
        ReasoningQuestionDescriptor(
            key: .resetNeed,
            signal: .category(.reset),
            role: .fallback,
            decisiveness: 0.65
        ),
        ReasoningQuestionDescriptor(
            key: .supportStyle,
            signal: .category(.relationship),
            counterSignal: .category(.achievement),
            role: .primary,
            decisiveness: 0.72
        ),
        ReasoningQuestionDescriptor(
            key: .protectionNeed,
            signal: .category(.protection),
            role: .primary,
            decisiveness: 0.85
        ),
        ReasoningQuestionDescriptor(
            key: .firstThingChanges,
            signal: .stance(.balance),
            role: .fallback,
            decisiveness: 0.6
        )
    ]

    static let questionMap: [QuestionKey: ReasoningQuestionDescriptor] = {
        Dictionary(uniqueKeysWithValues: orderedQuestions.map { ($0.key, $0) })
    }()

    static func multiplier(for answer: ReasoningAnswer) -> Double {
        switch answer {
        case .yes:
            return parameters.yesMultiplier
        case .no:
            return parameters.noMultiplier
        case .unknown:
            return parameters.unknownPenalty
        }
    }
}
