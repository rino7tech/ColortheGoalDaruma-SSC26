import Foundation

/// だるま色のキーワード定義
struct ColorKeywordDefinition {
    let color: DarumaColor
    let keywords: [String]
    let isFallback: Bool
}

/// キーワードマッチングによる色判定エンジン
struct KeywordColorMatcher {
    // キーワード定義（赤以外の主要な色）
    private static let primaryDefinitions: [ColorKeywordDefinition] = [
        ColorKeywordDefinition(
            color: .blue,
            keywords: ["competition", "health", "win", "victory", "match", "fitness", "recovery", "championship"],
            isFallback: false
        ),
        ColorKeywordDefinition(
            color: .green,
            keywords: ["career", "work", "promotion", "project", "goal", "achievement", "business", "success"],
            isFallback: false
        ),
        ColorKeywordDefinition(
            color: .white,
            keywords: ["celebration", "study", "exam", "pass", "grade", "graduation", "admission", "milestone"],
            isFallback: false
        ),
        ColorKeywordDefinition(
            color: .pink,
            keywords: ["love", "romance", "marriage", "partner", "proposal", "pregnancy", "childbirth", "baby"],
            isFallback: false
        ),
        ColorKeywordDefinition(
            color: .yellow,
            keywords: ["wealth", "money", "income", "salary", "savings", "investment", "travel", "safe driving"],
            isFallback: false
        ),
        ColorKeywordDefinition(
            color: .orange,
            keywords: ["beauty", "glow", "skin", "diet", "appearance", "style", "travel", "safe driving"],
            isFallback: false
        ),
        ColorKeywordDefinition(
            color: .purple,
            keywords: ["longevity", "healthy aging", "wellness", "prevention", "vitality", "anti-aging", "steady health"],
            isFallback: false
        ),
        ColorKeywordDefinition(
            color: .black,
            keywords: ["protection", "ward off", "safety", "profit", "revenue", "management", "business", "stability"],
            isFallback: false
        ),
        ColorKeywordDefinition(
            color: .gold,
            keywords: ["talent", "decision", "skill", "ability", "growth", "technique", "judgment", "leadership"],
            isFallback: false
        ),
        ColorKeywordDefinition(
            color: .silver,
            keywords: ["awakening", "mind", "mental", "stability", "calm", "peace", "potential", "focus"],
            isFallback: false
        )
    ]

    // フォールバック定義（赤だるま - 意図的にキーワードを限定）
    private static let fallbackDefinition = ColorKeywordDefinition(
        color: .red,
        keywords: ["good fortune", "family harmony", "home safety"],
        isFallback: true
    )

    /// ユーザーの回答からキーワードマッチングで色を判定
    /// - Parameter state: WishState（rawNotesを使用）
    /// - Returns: マッチした色、マッチしなければnil
    func matchColor(from state: WishState) -> DarumaColor? {
        // 全ての回答テキストを結合
        let allText = state.rawNotes.joined(separator: " ")

        // 1. 赤以外の色でマッチング
        var matchCounts: [DarumaColor: Int] = [:]
        for definition in Self.primaryDefinitions {
            let count = countMatches(in: allText, keywords: definition.keywords)
            if count > 0 {
                matchCounts[definition.color] = count
            }
        }

        // 2. 最多マッチの色を返す
        if let bestMatch = matchCounts.max(by: { $0.value < $1.value }) {
            return bestMatch.key
        }

        // 3. どの色もマッチしなかった場合、赤のキーワードをチェック
        let redCount = countMatches(in: allText, keywords: Self.fallbackDefinition.keywords)
        if redCount > 0 {
            return .red
        }

        // 4. 赤もマッチしなければnil（既存エンジンに委譲）
        return nil
    }

    /// テキスト内でマッチしたキーワードの数をカウント
    /// - Parameters:
    ///   - text: 検索対象のテキスト
    ///   - keywords: キーワードリスト
    /// - Returns: マッチしたキーワードの数
    private func countMatches(in text: String, keywords: [String]) -> Int {
        keywords.filter { text.contains($0) }.count
    }
}
