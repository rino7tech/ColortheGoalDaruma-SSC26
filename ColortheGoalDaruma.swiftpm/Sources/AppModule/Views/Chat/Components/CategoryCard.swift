import SwiftUI

/// カテゴリ選択用の美しいカード
struct CategoryCard: View {
    let title: String
    let detail: String?
    let gradient: [Color]
    let icon: String
    var action: () -> Void

    var body: some View {
        Button(action: {
            SoundPlayer.shared.playSelect()
            action()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.28))

                Image.woodBackground
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 1.2)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        LinearGradient(
                            colors: [
                                gradient.first?.opacity(0.78) ?? .clear,
                                gradient.last?.opacity(0.42) ?? .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    )
                    .overlay(
                        RadialGradient(
                            colors: [Color.white.opacity(0.22), Color.clear],
                            center: .topTrailing,
                            startRadius: 4,
                            endRadius: 120
                        )
                        .offset(x: 20, y: -18)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    )

                HStack(spacing: 10) {
                    ZStack {
                        Image(systemName: icon)
                            .font(.shiranui(size: 18))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)

                    HStack(spacing: 6) {
                        Text(title)
                            .font(.shiranui(size: 20))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 85)
            .contentShape(Rectangle())
            .clipped()
            .shadow(color: (gradient.first ?? .clear).opacity(0.18), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

/// カテゴリごとの色とアイコンを提供
enum CategoryStyle {
    case achievement, money, relationship, health, reset, protection, learning, none

    var gradient: [Color] {
        switch self {
        case .achievement:
            return [Color.yellow.opacity(0.9), Color.orange.opacity(0.8)]
        case .money:
            return [Color.yellow, Color.orange.opacity(0.9)]
        case .relationship:
            return [Color.pink.opacity(0.9), Color.red.opacity(0.6)]
        case .health:
            return [Color.green.opacity(0.9), Color.teal.opacity(0.7)]
        case .reset:
            return [Color.gray.opacity(0.7), Color.blue.opacity(0.6)]
        case .protection:
            return [Color.black.opacity(0.8), Color.gray.opacity(0.6)]
        case .learning:
            return [Color.blue.opacity(0.9), Color.indigo.opacity(0.7)]
        case .none:
            return [Color(white: 0.4), Color(white: 0.3)]
        }
    }

    var icon: String {
        switch self {
        case .achievement:
            return "trophy.fill"
        case .money:
            return "yensign.circle.fill"
        case .relationship:
            return "heart.fill"
        case .health:
            return "cross.fill"
        case .reset:
            return "arrow.counterclockwise.circle.fill"
        case .protection:
            return "shield.fill"
        case .learning:
            return "book.fill"
        case .none:
            return "ellipsis.circle.fill"
        }
    }

    static func from(choice: QuestionChoice) -> CategoryStyle {
        switch choice.canonicalTitle {
        case "Achievement":
            return .achievement
        case "Wealth":
            return .money
        case "Relationships":
            return .relationship
        case "Health":
            return .health
        case "Reset":
            return .reset
        case "Protection":
            return .protection
        case "Learning":
            return .learning
        default:
            return .none
        }
    }
}
