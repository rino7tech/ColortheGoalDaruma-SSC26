import Foundation

enum QuestionLibrary {
    static let specs: [QuestionKey: QuestionSpec] = {
        var dict: [QuestionKey: QuestionSpec] = [:]

        // 最初の質問：カテゴリ選択
        dict[.initialCategorySelection] = QuestionSpec(
            key: .initialCategorySelection,
            prompt: "Which of these options best matches your wish?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Achievement",
                    detail: "Hit a goal or complete something meaningful.",
                    impact: ScoreImpact(
                        categoryDeltas: [.achievement: 10.0]
                    )
                ),
                QuestionChoice(
                    title: "Wealth",
                    detail: "Grow your income or improve financial luck.",
                    impact: ScoreImpact(
                        categoryDeltas: [.money: 10.0]
                    )
                ),
                QuestionChoice(
                    title: "Relationships",
                    detail: "Find love, get married, or establish meaningful relations.",
                    impact: ScoreImpact(
                        categoryDeltas: [.relationship: 10.0]
                    )
                ),
                QuestionChoice(
                    title: "Health",
                    detail: "Feel better physically or mentally.",
                    impact: ScoreImpact(
                        categoryDeltas: [.health: 10.0]
                    )
                ),
                QuestionChoice(
                    title: "Reset",
                    detail: "Rebuild, reset, and get back on track.",
                    impact: ScoreImpact(
                        categoryDeltas: [.reset: 10.0]
                    )
                ),
                QuestionChoice(
                    title: "Protection",
                    detail: "Protect what matters and keep trouble away.",
                    impact: ScoreImpact(
                        categoryDeltas: [.protection: 10.0]
                    )
                ),
                QuestionChoice(
                    title: "Learning",
                    detail: "Grow through studying or learning new skills.",
                    impact: ScoreImpact(
                        categoryDeltas: [.learning: 10.0]
                    )
                ),
                QuestionChoice(
                    title: "None of the above",
                    detail: "My wish doesn't fit these options.",
                    impact: .none
                )
            ],
            allowNaturalization: false
        )

        // 最初の質問：願いは明確ですか？
        dict[.initialWishClarityCheck] = QuestionSpec(
            key: .initialWishClarityCheck,
            prompt: "Is your wish already crystal clear?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes",
                    detail: "I know exactly what I want.",
                    impact: .none
                ),
                QuestionChoice(
                    title: "No",
                    detail: "It’s still taking shape.",
                    impact: .none
                )
            ],
            allowNaturalization: false
        )

        // 願いを入力してもらう
        dict[.wishInput] = QuestionSpec(
            key: .wishInput,
            prompt: "What would you like to make happen?",
            responseKind: .freeform
        )

        dict[.resultVsState] = QuestionSpec(
            key: .resultVsState,
            prompt: "Are you in the mood to make a bold move right now?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, I want to go all in",
                    detail: "Take a swing and seize the result.",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.achievement: 0.9, .money: 0.4],
                        stanceDeltas: [.attack: 0.9]
                    )
                ),
                QuestionChoice(
                    title: "Not exactly, I'd rather set things up carefully",
                    detail: "Prioritize rhythm and foundations.",
                    reasoningAnswer: .unknown,
                    impact: ScoreImpact(
                        categoryDeltas: [.reset: 0.7, .learning: 0.4],
                        stanceDeltas: [.balance: 0.7]
                    )
                ),
            ]
        )

        dict[.momentumPreference] = QuestionSpec(
            key: .momentumPreference,
            prompt: "How fast do you want to achieve your wish?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "I want to surge ahead quickly",
                    detail: "I'm willing to stretch if it keeps things moving.",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.achievement: 0.4],
                        stanceDeltas: [.attack: 0.9]
                    )
                ),
                QuestionChoice(
                    title: "I'd like a steady, sustainable rhythm",
                    detail: "Move forward while keeping things balanced.",
                    reasoningAnswer: .unknown,
                    impact: ScoreImpact(
                        stanceDeltas: [.balance: 0.8]
                    )
                ),
            ]
        )

        dict[.selfVsEnvironment] = QuestionSpec(
            key: .selfVsEnvironment,
            prompt: "Are you mainly focused on tuning your inner world?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, I want to work on myself",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.learning: 0.8, .achievement: 0.3],
                        stanceDeltas: [.balance: 0.2]
                    )
                ),
                QuestionChoice(
                    title: "No, I want to influence the world around me",
                    reasoningAnswer: .no,
                    impact: ScoreImpact(
                        categoryDeltas: [.relationship: 0.8, .protection: 0.3],
                        stanceDeltas: [.attack: 0.2]
                    )
                ),
            ]
        )

        dict[.deadline] = QuestionSpec(
            key: .deadline,
            prompt: "Do you want to move on this wish within the next month?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, it's urgent",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        stanceDeltas: [.attack: 0.4],
                        deadline: .short
                    )
                ),
                QuestionChoice(
                    title: "No, I'm thinking long term",
                    reasoningAnswer: .no,
                    impact: ScoreImpact(
                        stanceDeltas: [.balance: 0.2, .defend: 0.3],
                        deadline: .long
                    )
                ),
            ]
        )

        dict[.avoidWorstVsGetBest] = QuestionSpec(
            key: .avoidWorstVsGetBest,
            prompt: "Is your priority avoiding the worst-case scenario?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, I want to shore up my defenses",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.protection: 0.7, .relationship: 0.3],
                        stanceDeltas: [.defend: 0.9]
                    )
                ),
                QuestionChoice(
                    title: "No, I'm going for the best possible outcome",
                    reasoningAnswer: .no,
                    impact: ScoreImpact(
                        categoryDeltas: [.achievement: 0.7, .money: 0.5],
                        stanceDeltas: [.attack: 0.8]
                    )
                ),
            ]
        )

        dict[.biggestObstacle] = QuestionSpec(
            key: .biggestObstacle,
            prompt: "Which obstacle feels closest right now?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Time or habit friction",
                    detail: "Packed schedule makes it hard to stay consistent.",
                    impact: ScoreImpact(obstacle: .time)
                ),
                QuestionChoice(
                    title: "Emotional or confidence swings",
                    detail: "Mood and mindset slow me down.",
                    impact: ScoreImpact(obstacle: .confidence)
                ),
            ]
        )

        dict[.firstThingChanges] = QuestionSpec(
            key: .firstThingChanges,
            prompt: "When it works out, do you see yourself finally exhaling and relaxing?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, I want to drop into a calm mode",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.reset: 0.6, .health: 0.4],
                        stanceDeltas: [.balance: 0.5]
                    )
                ),
                QuestionChoice(
                    title: "No, it would fire up my attack mode",
                    reasoningAnswer: .no,
                    impact: ScoreImpact(
                        categoryDeltas: [.achievement: 0.6, .money: 0.3],
                        stanceDeltas: [.attack: 0.5]
                    )
                ),
            ]
        )

        dict[.relationshipTemperature] = QuestionSpec(
            key: .relationshipTemperature,
            prompt: "Do you feel a strong pull to actively grow your connections right now?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, I want to open things up",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.relationship: 0.8],
                        stanceDeltas: [.attack: 0.2]
                    )
                ),
                QuestionChoice(
                    title: "No, I'd prefer some distance",
                    reasoningAnswer: .no,
                    impact: ScoreImpact(
                        categoryDeltas: [.protection: 0.5, .relationship: 0.3],
                        stanceDeltas: [.defend: 0.4]
                    )
                ),
            ]
        )

        dict[.healthFocus] = QuestionSpec(
            key: .healthFocus,
            prompt: "Is caring for your body or mind the main theme right now?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, it's my top priority",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.health: 0.9],
                        stanceDeltas: [.balance: 0.3]
                    )
                ),
                QuestionChoice(
                    title: "No, something else matters more",
                    reasoningAnswer: .no,
                    impact: ScoreImpact(
                        categoryDeltas: [.achievement: 0.3],
                        stanceDeltas: [.attack: 0.1]
                    )
                ),
            ]
        )

        dict[.moneyFocus] = QuestionSpec(
            key: .moneyFocus,
            prompt: "Is improving results or income the central theme this time?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, I want the numbers to climb",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.money: 0.9, .achievement: 0.3],
                        stanceDeltas: [.attack: 0.4]
                    )
                ),
                QuestionChoice(
                    title: "No, another wish comes first",
                    reasoningAnswer: .no,
                    impact: ScoreImpact(
                        categoryDeltas: [.relationship: 0.3, .protection: 0.3],
                        stanceDeltas: [.balance: 0.2]
                    )
                ),
            ]
        )

        dict[.studyHabit] = QuestionSpec(
            key: .studyHabit,
            prompt: "Do you want to build a steady practice or study habit?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, I want to firm up my foundations",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.learning: 0.8, .reset: 0.3],
                        stanceDeltas: [.balance: 0.4]
                    )
                ),
                QuestionChoice(
                    title: "No, I prefer short bursts of focus",
                    reasoningAnswer: .no,
                    impact: ScoreImpact(
                        categoryDeltas: [.achievement: 0.6],
                        stanceDeltas: [.attack: 0.4]
                    )
                ),
            ]
        )

        dict[.supportStyle] = QuestionSpec(
            key: .supportStyle,
            prompt: "Do you picture moving forward with someone supporting you?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, I want someone alongside me",
                    detail: "Progress feels safer with friends or family.",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.relationship: 0.8],
                        stanceDeltas: [.balance: 0.3]
                    )
                ),
                QuestionChoice(
                    title: "No, I prefer to move forward alone",
                    detail: "I value my own pace",
                    reasoningAnswer: .no,
                    impact: ScoreImpact(
                        categoryDeltas: [.achievement: 0.4, .learning: 0.3],
                        stanceDeltas: [.attack: 0.2]
                    )
                ),
            ]
        )

        dict[.resetNeed] = QuestionSpec(
            key: .resetNeed,
            prompt: "Do you feel the need to reset and rebuild before moving on?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, now is the time to reset",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.reset: 0.9],
                        stanceDeltas: [.balance: 0.4]
                    )
                ),
                QuestionChoice(
                    title: "No, I'd rather keep moving forward",
                    reasoningAnswer: .no,
                    impact: ScoreImpact(
                        categoryDeltas: [.achievement: 0.4],
                        stanceDeltas: [.attack: 0.2]
                    )
                ),
            ]
        )

        dict[.protectionNeed] = QuestionSpec(
            key: .protectionNeed,
            prompt: "Are you currently prioritizing what you need to protect?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Yes, I want to fortify my shield",
                    reasoningAnswer: .yes,
                    impact: ScoreImpact(
                        categoryDeltas: [.protection: 0.9],
                        stanceDeltas: [.defend: 0.5]
                    )
                ),
                QuestionChoice(
                    title: "No, I want to stay on the offensive",
                    reasoningAnswer: .no,
                    impact: ScoreImpact(
                        categoryDeltas: [.achievement: 0.4],
                        stanceDeltas: [.attack: 0.3]
                    )
                ),
            ]
        )

        dict[.freeAnswer1] = QuestionSpec(
            key: .freeAnswer1,
            prompt: "Which state feels closest right now?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "I know what I want but can’t put it into words",
                    detail: "I need help organizing the direction.",
                    impact: .none
                ),
                QuestionChoice(
                    title: "Too many tasks and nothing feels organized",
                    detail: "I need to set priorities.",
                    impact: .none
                ),
                QuestionChoice(
                    title: "I want to start by calming my feelings",
                    detail: "Settle my body and mind.",
                    impact: .none
                ),
                QuestionChoice(
                    title: "I can’t describe it well, so I want to explore together",
                    impact: .none
                )
            ]
        )

        dict[.freeAnswer2] = QuestionSpec(
            key: .freeAnswer2,
            prompt: "Which outcome feels closest to your ideal state?",
            responseKind: .multipleChoice,
            choices: [
                QuestionChoice(
                    title: "Everything is organized and clear",
                    impact: .none
                ),
                QuestionChoice(
                    title: "I can see the first actionable step and feel energized",
                    impact: .none
                ),
                QuestionChoice(
                    title: "I want peace of mind even more than visible change",
                    impact: .none
                ),
                QuestionChoice(
                    title: "I'm not sure yet and want to decide as I reflect",
                    impact: .none
                )
            ]
        )

        return dict
    }()
}
