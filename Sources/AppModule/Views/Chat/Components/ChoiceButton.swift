import SwiftUI

struct ChoiceButton: View {
    let title: String
    let detail: String?
    var action: () -> Void

    var body: some View {
        Button(action: {
            SoundPlayer.shared.playSelect()
            action()
        }) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.shiranui(size: 24))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail)
                            .font(.shiranui(size: 16))
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.shiranui(.headline))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 28)
            .padding(.horizontal, 28)
            .background(
                Image.woodBackground
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 1.5)
                    .allowsHitTesting(false)
            )
            .clipped()
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
