import SwiftUI

/// AR配置後のガイド画面
struct ClosingView: View {
    let darumaColor: DarumaColor
    let onDrawRightEye: () -> Void
    let onStartOver: () -> Void
    @State private var backgroundViewModel = DarumaSceneViewModel()
    var body: some View {
        ZStack {
            // 背景: だるまシーン（全画面）
            DarumaSceneView(viewModel: backgroundViewModel, showsBottomStaticView: false)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // 右側オーバーレイパネル
            HStack {
                Spacer()
                closingPanel
                    .frame(maxWidth: 400)
                    .padding(.trailing, 48)
                    .padding(.vertical, 60)
            }
        }
        .onAppear {
            setupBackground()
        }
    }

    // MARK: - 右側パネル

    private var closingPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ラベル
            Text("GOAL STEP")
                .font(.shiranui(size: 12))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(3)
                .padding(.bottom, 16)

            // メインタイトル
            Text("Keep moving toward your goal\nfrom here!")
                .font(.shiranui(size: 34))
                .foregroundStyle(.white)
                .lineSpacing(6)
                .padding(.bottom, 28)

            // 区切り線
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
                .padding(.bottom, 24)

            // 説明テキスト
            Text("When your goal is achieved, draw the right eye\nto complete your Daruma.\nWould you like to complete it?")
                .font(.shiranui(size: 15))
                .foregroundStyle(.white.opacity(0.75))
                .lineSpacing(4)
                .padding(.bottom, 40)

            Spacer()

            // プライマリCTAボタン
            Button(action: {
                SoundPlayer.shared.playSelect()
                onDrawRightEye()
            }) {
                HStack(spacing: 12) {
                    Text("Draw the Right Eye")
                        .font(.shiranui(size: 19))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .foregroundStyle(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)

            // セカンダリボタン
            Button(action: {
                SoundPlayer.shared.playSelect()
                onStartOver()
            }) {
                Text("Return to Title")
                    .font(.shiranui(size: 16))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.black.opacity(0.55))
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.3))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - セットアップ

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

}
