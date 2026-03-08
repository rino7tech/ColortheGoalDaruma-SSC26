import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: {
            SoundPlayer.shared.playSelect()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.shiranui(size: 18))
                Text(title)
                    .font(.shiranui(size: 18))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Image.woodBackground
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 1.5)
            )
            .clipped()
            .foregroundColor(.white)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}
