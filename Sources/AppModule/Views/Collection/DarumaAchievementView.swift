import SwiftUI

/// 願い達成時の記念画面
struct DarumaAchievementView: View {
    let daruma: SavedDaruma
    let onViewCollection: () -> Void
    let onReturnToTitle: () -> Void

    @State private var collectionScene = DarumaCollectionScene()

    var body: some View {
        ZStack {
            Image.tatamiBackground
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blur(radius: 8)

            Color.black.opacity(0.22).ignoresSafeArea()

            DarumaCollectionSceneView(scene: collectionScene) { _ in }
                .allowsHitTesting(false)
                .background(Color.white.opacity(0.01))
                .ignoresSafeArea()
                .offset(y: -34)

            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 72)

                Text("GoalArchived!")
                    .font(.shiranui(size: 50))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 4)

                Text("The right eye is in, and your Daruma is complete.")
                    .font(.shiranui(size: 18))
                    .foregroundStyle(.white.opacity(0.92))

                Spacer()

                Button(action: {
                    SoundPlayer.shared.playSelect()
                    onReturnToTitle()
                }) {
                    Text("Return to Title")
                        .font(.shiranui(size: 18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 320)
                        .frame(height: 58)
                        .background(Color.accentColor)
                        .cornerRadius(32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 84)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            setupCollectionScene()
        }
    }

    private func setupCollectionScene() {
        collectionScene.loadDarumas([daruma])
        collectionScene.setupOverviewCamera()
        collectionScene.focusOnDaruma(toID: daruma.id, cameraZ: 8.4, cameraYOffset: 3.2, animated: false)
        collectionScene.startConfetti()
    }
}
