import SwiftUI

/// どちらの目を描くかを表す列挙型
enum EyeSide {
    case right
    case left
}

/// だるまの目を描く画面
struct DarumaEyeDrawingView: View {
    @Bindable var viewModel: DarumaEyeDrawingViewModel
    let darumaColor: DarumaColor
    var eyeSide: EyeSide = .right
    var leftEyeImage: UIImage? = nil
    var onComplete: ((UIImage?) -> Void)?
    @State private var errorMessage: String?
    @State private var backgroundViewModel: DarumaSceneViewModel
    @State private var isSceneVisible = false
    private let focusCircleDiameter: CGFloat = 500

    init(
        viewModel: DarumaEyeDrawingViewModel,
        darumaColor: DarumaColor,
        eyeSide: EyeSide = .right,
        leftEyeImage: UIImage? = nil,
        onComplete: ((UIImage?) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.darumaColor = darumaColor
        self.eyeSide = eyeSide
        self.leftEyeImage = leftEyeImage
        self.onComplete = onComplete
        _backgroundViewModel = State(initialValue: Self.makeBackgroundViewModel(
            darumaColor: darumaColor,
            eyeSide: eyeSide,
            leftEyeImage: leftEyeImage
        ))
    }

    private var focusCircleXOffset: CGFloat {
        eyeSide == .right ? -56 : 56
    }

    var body: some View {
        ZStack {
            // だるまを正面表示（全画面）
            DarumaSceneView(viewModel: backgroundViewModel, showsBottomStaticView: false)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(isSceneVisible ? 1 : 0)

            // 白い幕（中央のみ透過）
            focusOverlay

            // 丸いフォーカス領域と同じ位置・サイズで描画できるようにする
            CalligraphyCanvasView(
                strokes: $viewModel.strokes,
                isErasing: viewModel.isErasing,
                inkColor: .black,
                lineWidth: 16,
                backgroundColor: .clear,
                onCoordinatorReady: { coordinator in
                    viewModel.canvasCoordinator = coordinator
                }
            )
            .frame(width: focusCircleDiameter, height: focusCircleDiameter)
            .clipShape(Circle())
            .offset(x: focusCircleXOffset)

            // 透明なキャンバスをだるまの上に重ねる
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)

                // タイトル
                Text(eyeSide == .right
                     ? "Draw the Daruma's right eye"
                     : "Draw the Daruma's left eye")
                    .font(.shiranui(size: 24))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .padding(.bottom, 10)

                Text(eyeSide == .right
                     ? "Complete your Daruma by drawing the right eye."
                     : "With your wish in mind, draw the left eye with intention.")
                    .font(.shiranui(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .padding(.bottom, 20)

                // エラーメッセージ
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.shiranui(.callout))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                        .padding(.bottom, 20)
                }

                Spacer()

                Spacer()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 14) {
                // ペン/消しゴム切り替え
                PenEraserToggle(isErasing: Binding(
                    get: { viewModel.isErasing },
                    set: { newValue in
                        if newValue { viewModel.switchToEraser() } else { viewModel.switchToPen() }
                    }
                ))

                Button(action: {
                    SoundPlayer.shared.playSelect()
                    handleComplete()
                }) {
                    HStack(spacing: 12) {
                        Text("NextStep")
                            .font(.shiranui(size: 20))
                        Image(systemName: "arrow.right")
                            .font(.shiranui(size: 20))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.customRed)
                    )
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.trailing, 32)
            .padding(.bottom, 40)
        }
        // 左上に説明動画
        .overlay(alignment: .topLeading) {
            VideoPlayerView(
                resourceName: eyeSide == .right ? "daruma_migi" : "daruma_hidari",
                fileExtension: "mov"
            )
                .frame(width: 260, height: 195)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .padding(.leading, 32)
                .padding(.top, 30)
        }
        .background {
            Image.tatamiBackground
                .resizable()
                .scaledToFill()
                .blur(radius: 8)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.15).ignoresSafeArea())
        }
        .onAppear {
            isSceneVisible = false
            viewModel.clearDrawing()
            viewModel.switchToPen()
            errorMessage = nil
            updateBackgroundColor()
            DispatchQueue.main.async {
                isSceneVisible = true
            }
        }
        .onChange(of: eyeSide) {
            isSceneVisible = false
            updateBackgroundColor()
            DispatchQueue.main.async {
                isSceneVisible = true
            }
        }
    }

    /// 完了ボタンが押されたときの処理
    private func handleComplete() {
        let eyeImage = viewModel.captureEyeImage()

        // 描画が空の場合は警告を表示するが、続行は可能
        if eyeImage == nil {
            errorMessage = "No eye has been drawn. You can still continue."
        }

        onComplete?(eyeImage)
    }

    private func updateBackgroundColor() {
        backgroundViewModel = Self.makeBackgroundViewModel(
            darumaColor: darumaColor,
            eyeSide: eyeSide,
            leftEyeImage: leftEyeImage
        )
    }

    private static func makeBackgroundViewModel(
        darumaColor: DarumaColor,
        eyeSide: EyeSide,
        leftEyeImage: UIImage?
    ) -> DarumaSceneViewModel {
        let vm = DarumaSceneViewModel()
        vm.fixedYRotation = 0
        vm.fixedXRotation = 0
        vm.enableAutoRotation = false
        vm.customScale = 9.5
        vm.cameraXOffset = eyeSide == .right ? -1.0 : 1.0
        vm.cameraYOffset = 4.2
        vm.cameraZOffset = -0.8

        var scores: [DarumaColor: Double] = [:]
        for color in DarumaColor.allCases {
            scores[color] = (color == darumaColor) ? 1.0 : 0.0
        }
        vm.currentScores = scores
        vm.targetScores = scores
        vm.scoreTransitionProgress = 1.0
        vm.leftEyeImage = leftEyeImage
        return vm
    }

    private var focusOverlay: some View {
        ZStack {
            // 画面全体を暗くする（下部もカバー）
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.clear, Color.black.opacity(0.9)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: focusCircleDiameter, height: focusCircleDiameter)
                .offset(x: focusCircleXOffset)
                .blendMode(.destinationOut)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .compositingGroup()
        .allowsHitTesting(false)
    }
}
