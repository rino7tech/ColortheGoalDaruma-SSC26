import SwiftUI

/// だるまコレクション詳細画面（タップで拡大）
struct DarumaCollectionDetailView: View {
    let daruma: SavedDaruma
    let store: DarumaStore
    let onDismiss: () -> Void

    @State private var backgroundViewModel = DarumaSceneViewModel()
    @State private var showEyeDrawing = false
    @State private var showAchievement = false
    @State private var capturedRightEyeImage: UIImage?
    @State private var eyeDrawingViewModel = DarumaEyeDrawingViewModel()

    var body: some View {
        ZStack {
            // 背景：だるまの3Dシーン
            DarumaSceneView(viewModel: backgroundViewModel, showsBottomStaticView: false)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.5), Color.clear, Color.black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )

            // 目の描画オーバーレイ（保存された画像を重ねる）
            eyeOverlay

            VStack(spacing: 0) {
                // 閉じるボタン
                HStack {
                    Button(action: {
                        SoundPlayer.shared.playSelect()
                        onDismiss()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 24)
                    .padding(.top, 56)
                    Spacer()
                }

                // 願い事バブル
                if let wish = daruma.wishSentence {
                    wishBubble(wish: wish)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                }

                Spacer()

                // 下部パネル
                bottomPanel
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .onAppear {
            setupBackground()
        }
        .fullScreenCover(isPresented: $showEyeDrawing) {
            DarumaEyeDrawingView(
                viewModel: eyeDrawingViewModel,
                darumaColor: daruma.darumaColor,
                eyeSide: .right,
                onComplete: { image in
                    capturedRightEyeImage = image
                    showEyeDrawing = false
                    store.fulfillWish(id: daruma.id, rightEyeImageData: image?.jpegData(compressionQuality: 0.8))
                    showAchievement = true
                }
            )
        }
        .fullScreenCover(isPresented: $showAchievement) {
            if let updatedDaruma = store.savedDarumas.first(where: { $0.id == daruma.id }) {
                DarumaAchievementView(
                    daruma: updatedDaruma,
                    onViewCollection: {
                        showAchievement = false
                        onDismiss()
                    },
                    onReturnToTitle: {
                        showAchievement = false
                        onDismiss()
                    }
                )
            }
        }
    }

    // MARK: - 目のオーバーレイ

    private var eyeOverlay: some View {
        ZStack {
            // 左目（+56 offset）
            if let leftEye = daruma.leftEyeImage {
                Image(uiImage: leftEye)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .offset(x: 56, y: -30)
            }

            // 右目（-56 offset）
            if let rightEye = daruma.rightEyeImage ?? capturedRightEyeImage {
                Image(uiImage: rightEye)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .offset(x: -56, y: -30)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 願い事バブル

    private func wishBubble(wish: String) -> some View {
        DarumaGuideBubble(
            minHeight: 80,
            horizontalPadding: 24,
            verticalPadding: 20,
            showsTail: false
        ) {
            HStack(alignment: .top, spacing: 12) {
                Text("Wish.")
                    .font(.shiranui(size: 22))
                    .foregroundStyle(Color.customRed)
                Text(wish)
                    .font(.shiranui(size: 18))
                    .foregroundStyle(.black.opacity(0.85))
                    .lineLimit(3)
            }
        }
    }

    // MARK: - 下部パネル

    private var bottomPanel: some View {
        Group {
            if daruma.isWishFulfilled {
                // 達成済みメッセージ
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                    Text("Both Eyes Are Complete")
                        .font(.shiranui(size: 20))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.yellow, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
            } else {
                // 未達成パネル
                VStack(spacing: 14) {
                    Text("Did Your Wish Come True!?")
                        .font(.shiranui(size: 20))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)

                    Button(action: {
                        SoundPlayer.shared.playSelect()
                        showEyeDrawing = true
                    }) {
                        HStack(spacing: 10) {
                            Text("It Came True! Draw the Right Eye")
                                .font(.shiranui(size: 17))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .foregroundStyle(Color.customRed)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black.opacity(0.26))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - セットアップ

    private func setupBackground() {
        backgroundViewModel.fixedYRotation = 0
        backgroundViewModel.fixedXRotation = 0
        backgroundViewModel.enableAutoRotation = true
        backgroundViewModel.customScale = 9.5
        backgroundViewModel.cameraYOffset = 4.2
        backgroundViewModel.cameraZOffset = -0.8

        var scores: [DarumaColor: Double] = [:]
        for color in DarumaColor.allCases {
            scores[color] = (color == daruma.darumaColor) ? 1.0 : 0.0
        }
        backgroundViewModel.currentScores = scores
        backgroundViewModel.targetScores = scores
        backgroundViewModel.scoreTransitionProgress = 1.0
    }
}
