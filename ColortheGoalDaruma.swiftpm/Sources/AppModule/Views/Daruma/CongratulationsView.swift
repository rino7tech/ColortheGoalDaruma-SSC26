import SwiftUI

/// 左目描き完了後のおめでとう画面
struct CongratulationsView: View {
    let darumaColor: DarumaColor
    let onReturnToTop: () -> Void
    @State private var backgroundViewModel = DarumaSceneViewModel()
    @State private var returnToTopTask: Task<Void, Never>?
    @State private var isReturningToTop = false

    var body: some View {
        ZStack {
            // 背景: だるまの3Dシーン
            DarumaSceneView(viewModel: backgroundViewModel, showsBottomStaticView: false)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.3), Color.black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )

            VStack(spacing: 24) {
                Spacer()

                // おめでとうタイトル
                Text("Congratulations!")
                    .font(.shiranui(size: 40))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // 説明テキスト
                VStack(spacing: 12) {
                    Text("Both eyes are complete!\nYour Daruma has witnessed\nyour wish come true.")
                        .font(.shiranui(size: 16))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: 340)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Spacer()

                // トップに戻るボタン
                Button(action: {
                    guard !isReturningToTop else { return }
                    SoundPlayer.shared.playSelect()
                    animateReturnToTop {
                        onReturnToTop()
                    }
                }) {
                    Text("Return to Top")
                        .font(.shiranui(size: 20))
                        .foregroundColor(Color.customRed)
                        .frame(maxWidth: 280)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                }
                .disabled(isReturningToTop)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            setupBackground()
        }
        .onDisappear {
            returnToTopTask?.cancel()
            returnToTopTask = nil
        }
    }

    private func setupBackground() {
        backgroundViewModel.fixedYRotation = 0
        backgroundViewModel.fixedXRotation = 0
        backgroundViewModel.enableAutoRotation = true
        backgroundViewModel.customScale = 5.0

        var scores: [DarumaColor: Double] = [:]
        for color in DarumaColor.allCases {
            scores[color] = (color == darumaColor) ? 1.0 : 0.0
        }
        backgroundViewModel.currentScores = scores
        backgroundViewModel.targetScores = scores
        backgroundViewModel.scoreTransitionProgress = 1.0
    }

    private func animateReturnToTop(completion: @escaping () -> Void) {
        returnToTopTask?.cancel()
        isReturningToTop = true
        backgroundViewModel.enableAutoRotation = false
        backgroundViewModel.manualRotationVelocity = 0

        let duration: Double = 1.2
        let rotationAmount = Double.pi * 1.35
        let cameraPushBack: Float = 2.4
        let cameraLift: Float = 0.25

        let startRotation = backgroundViewModel.manualRotationY
        let endRotation = startRotation + rotationAmount
        let startCameraZ = backgroundViewModel.cameraZOffset
        let endCameraZ = startCameraZ + cameraPushBack
        let startCameraY = backgroundViewModel.cameraYOffset
        let endCameraY = startCameraY + cameraLift

        returnToTopTask = Task { @MainActor in
            let startTime = CFAbsoluteTimeGetCurrent()
            while true {
                if Task.isCancelled { return }

                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                let progress = min(max(elapsed / duration, 0), 1)
                let eased = easeInOutQuad(progress)

                backgroundViewModel.manualRotationY = startRotation + (endRotation - startRotation) * eased
                backgroundViewModel.cameraZOffset = startCameraZ + (endCameraZ - startCameraZ) * Float(eased)
                backgroundViewModel.cameraYOffset = startCameraY + (endCameraY - startCameraY) * Float(eased)

                if progress >= 1 {
                    break
                }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }

            completion()
        }
    }

    private func easeInOutQuad(_ t: Double) -> Double {
        if t < 0.5 {
            return 2 * t * t
        }
        return 1 - pow(-2 * t + 2, 2) / 2
    }
}
