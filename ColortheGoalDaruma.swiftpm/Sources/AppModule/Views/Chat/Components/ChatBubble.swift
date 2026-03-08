import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        GeometryReader { proxy in
            HStack {
                if message.sender == .user { Spacer() }
                MarkdownText(text: message.text)
                    .padding(12)
                    .background(bubbleColor)
                    .foregroundColor(message.sender == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: min(420, proxy.size.width * 0.7), alignment: .leading)
                if message.sender != .user { Spacer() }
            }
        }
        .frame(minHeight: 1)
    }

    private var bubbleColor: Color {
        switch message.sender {
        case .user:
            return Color.accentColor
        case .assistant:
            return Color(.systemGray6)
        case .system:
            return Color(.systemGray5)
        }
    }
}
