import Foundation

enum QuestionKey: String, CaseIterable, Codable {
    case initialCategorySelection  // 最初の質問：カテゴリ選択
    case initialWishClarityCheck  // 最初の質問：願いは明確ですか？
    case wishInput                 // 願いを入力
    case resultVsState
    case momentumPreference
    case selfVsEnvironment
    case deadline
    case avoidWorstVsGetBest
    case biggestObstacle
    case firstThingChanges
    case relationshipTemperature
    case healthFocus
    case moneyFocus
    case studyHabit
    case resetNeed
    case protectionNeed
    case supportStyle
    case freeAnswer1
    case freeAnswer2
}

struct ScoreImpact: Codable {
    var categoryDeltas: [WishCategory: Double] = [:]
    var stanceDeltas: [WishStance: Double] = [:]
    var deadline: Deadline?
    var obstacle: Obstacle?

    static var none: ScoreImpact { ScoreImpact() }
}

enum ReasoningAnswer: String, Codable {
    case yes
    case no
    case unknown
}

struct QuestionChoice: Identifiable, Codable {
    let id: UUID
    let title: String
    let detail: String?
    let reasoningAnswer: ReasoningAnswer?
    let impact: ScoreImpact
    let canonicalTitle: String

    init(
        id: UUID = UUID(),
        title: String,
        detail: String? = nil,
        reasoningAnswer: ReasoningAnswer? = nil,
        impact: ScoreImpact = .none,
        canonicalTitle: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.reasoningAnswer = reasoningAnswer
        self.impact = impact
        self.canonicalTitle = canonicalTitle ?? title
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case reasoningAnswer
        case impact
        case canonicalTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.detail = try container.decodeIfPresent(String.self, forKey: .detail)
        self.reasoningAnswer = try container.decodeIfPresent(ReasoningAnswer.self, forKey: .reasoningAnswer)
        self.impact = try container.decode(ScoreImpact.self, forKey: .impact)
        self.canonicalTitle = try container.decodeIfPresent(String.self, forKey: .canonicalTitle) ?? self.title
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(detail, forKey: .detail)
        try container.encode(reasoningAnswer, forKey: .reasoningAnswer)
        try container.encode(impact, forKey: .impact)
        try container.encode(canonicalTitle, forKey: .canonicalTitle)
    }
}

enum QuestionResponseKind: Codable {
    case multipleChoice
    case freeform
}

struct QuestionSpec: Identifiable, Codable {
    let id: UUID
    let key: QuestionKey
    let prompt: String
    let responseKind: QuestionResponseKind
    let choices: [QuestionChoice]
    let allowNaturalization: Bool

    init(
        id: UUID = UUID(),
        key: QuestionKey,
        prompt: String,
        responseKind: QuestionResponseKind,
        choices: [QuestionChoice] = [],
        allowNaturalization: Bool = true
    ) {
        self.id = id
        self.key = key
        self.prompt = prompt
        self.responseKind = responseKind
        self.choices = choices
        self.allowNaturalization = allowNaturalization
    }
}
