import SwiftUI

struct OnboardingView: View {
    var onStart: (() -> Void)?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.red.opacity(0.2), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Ready to begin the Daruma reading?")
                    .font(.shiranui(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 32)

                Button(action: {
                    SoundPlayer.shared.playSelect()
                    onStart?()
                }) {
                    HStack(spacing: 10) {
                        Text("Start the reading")
                            .font(.shiranui(size: 18))
                        Image(systemName: "arrow.right")
                            .font(.shiranui(size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 20))
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }
}
