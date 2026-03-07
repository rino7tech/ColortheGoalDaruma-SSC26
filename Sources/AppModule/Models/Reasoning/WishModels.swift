import Foundation
import SwiftUI

enum DarumaColor: String, CaseIterable, Codable, Identifiable {
    case red, white, yellow, blue, green, pink, orange, purple, black, gold, silver

    var id: String { rawValue }

    var title: String {
        switch self {
        case .red: return "Red Daruma"
        case .white: return "White Daruma"
        case .yellow: return "Yellow Daruma"
        case .blue: return "Blue Daruma"
        case .green: return "Green Daruma"
        case .pink: return "Pink Daruma"
        case .orange: return "Orange Daruma"
        case .purple: return "Purple Daruma"
        case .black: return "Black Daruma"
        case .gold: return "Gold Daruma"
        case .silver: return "Silver Daruma"
        }
    }

    var meaning: String {
        switch self {
        case .red:
            return "General good fortune & family harmony"
        case .blue:
            return "Competitive luck & health blessings"
        case .green:
            return "Follow-through & career momentum"
        case .white:
            return "Celebrations & academic success"
        case .pink:
            return "Love, marriage, and safe childbirth"
        case .yellow:
            return "Wealth flow & safe travels"
        case .orange:
            return "Beauty boost & safe journeys"
        case .purple:
            return "Longevity & steady health"
        case .black:
            return "Protection from misfortune & staying in the black"
        case .gold:
            return "Talent boost & sharper decisions"
        case .silver:
            return "Talent awakening & calm focus"
        }
    }

    /// 簡潔にその色のイメージを表すキーワード
    var focusKeyword: String {
        switch self {
        case .red: return "Fortune"
        case .white: return "Scholarship"
        case .yellow: return "Prosperity"
        case .blue: return "Vitality"
        case .green: return "Career"
        case .pink: return "Love"
        case .orange: return "Glow"
        case .purple: return "Longevity"
        case .black: return "Protection"
        case .gold: return "Talent"
        case .silver: return "Calm"
        }
    }

    var gradient: [Color] {
        switch self {
        case .red:
            return [Color.red]
        case .white:
            return [Color.white]
        case .yellow:
            return [Color.yellow]
        case .blue:
            return [Color.blue]
        case .green:
            return [Color.green]
        case .pink:
            return [Color.pink]
        case .orange:
            return [Color.orange]
        case .purple:
            return [Color.purple]
        case .black:
            return [Color.black]
        case .gold:
            return [Color.yellow]
        case .silver:
            return [Color.gray]
        }
    }

    var textureName: String {
        switch self {
        case .red: return "Daruma_texture"
        case .white: return "Daruma_texture"
        case .yellow: return "Daruma_texture"
        case .blue: return "Daruma_texture"
        case .green: return "Daruma_texture"
        case .pink: return "Daruma_texture"
        case .orange: return "Daruma_texture"
        case .purple: return "Daruma_texture"
        case .black: return "Daruma_texture"
        case .gold: return "Daruma_texture"
        case .silver: return "Daruma_texture"
        }
    }
}

enum WishCategory: String, CaseIterable, Codable {
    case achievement, money, relationship, health, reset, protection, learning

    var label: String {
        switch self {
        case .achievement: return "Achievement"
        case .money: return "Wealth"
        case .relationship: return "Relationships"
        case .health: return "Health"
        case .reset: return "Reset"
        case .protection: return "Protection"
        case .learning: return "Learning"
        }
    }
}

enum WishStance: String, CaseIterable, Codable {
    case attack, balance, defend

    var label: String {
        switch self {
        case .attack: return "Bold"
        case .balance: return "Balanced"
        case .defend: return "Protective"
        }
    }
}

enum Deadline: String, CaseIterable, Codable {
    case short, mid, long, none

    var label: String {
        switch self {
        case .short: return "Right away"
        case .mid: return "Measured pace"
        case .long: return "Long term"
        case .none: return "Undecided"
        }
    }
}

enum Obstacle: String, CaseIterable, Codable {
    case time, confidence, habit, people, money, luck, other

    var label: String {
        switch self {
        case .time: return "Time"
        case .confidence: return "Confidence"
        case .habit: return "Habits"
        case .people: return "People & environment"
        case .money: return "Money"
        case .luck: return "Luck"
        case .other: return "Other"
        }
    }
}

struct WishState: Codable {
    var categoryScore: [WishCategory: Double]
    var stanceScore: [WishStance: Double]
    var deadline: Deadline?
    var obstacle: Obstacle?
    var rawNotes: [String]
    var wishSentence: String?

    init() {
        categoryScore = Dictionary(uniqueKeysWithValues: WishCategory.allCases.map { ($0, 0) })
        stanceScore = Dictionary(uniqueKeysWithValues: WishStance.allCases.map { ($0, 0) })
        rawNotes = []
        wishSentence = nil
    }

    mutating func add(category: WishCategory, delta: Double) {
        categoryScore[category, default: 0] += delta
    }

    mutating func add(stance: WishStance, delta: Double) {
        stanceScore[stance, default: 0] += delta
    }

    var topCategory: WishCategory? {
        categoryScore.max(by: { $0.value < $1.value })?.key
    }

    var topStance: WishStance? {
        stanceScore.max(by: { $0.value < $1.value })?.key
    }

    func summaryForPrompt() -> String {
        let cat = topCategory?.label ?? "Uncertain"
        let stance = topStance?.label ?? "Uncertain"
        let deadlineText = deadline?.label ?? "Not set"
        let obstacleText = obstacle?.label ?? "Unknown"
        let notesText = rawNotes.suffix(3).joined(separator: " / ")
        return "Category: \(cat), Stance: \(stance), Deadline: \(deadlineText), Obstacle: \(obstacleText), Notes: \(notesText)"
    }

    mutating func setWishSentence(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        wishSentence = trimmed
    }
}

struct DarumaResult: Identifiable {
    let id = UUID()
    let color: DarumaColor
    let wishSummary: String
    let reason: String
    let darumaWord: String
    let nextStep: String
    let stopDoing: String
    let categoryScores: [WishCategory: Double]

    /// 現状分析（理由を基に）
    var currentAnalysis: String { reason }

    /// 今後のこと（次のステップと手放すことを組み合わせ）
    var futureGuidance: String {
        var parts: [String] = []
        if !nextStep.isEmpty { parts.append(nextStep) }
        if !stopDoing.isEmpty { parts.append(stopDoing) }
        return parts.joined(separator: "\n\n")
    }
}
