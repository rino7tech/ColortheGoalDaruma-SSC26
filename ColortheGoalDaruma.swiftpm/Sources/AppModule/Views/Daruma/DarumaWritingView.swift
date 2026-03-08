import SwiftUI

enum WritingInstructionMode {
    case none
    case diagnosisPreOCR
    case ritualPostResult
}

/// だるまの裏面に願い事を書く画面
struct DarumaWritingView: View {
    @Bindable var viewModel: DarumaWishWritingViewModel
    let darumaColor: DarumaColor?
    var instructionMode: WritingInstructionMode = .none
    var title: String = "Write your wish"
    var subtitle: String = "Write clearly on the Daruma bottom surface."
    var guidanceText: String? = nil
    var onComplete: ((UIImage?) -> Void)?
    var onOCRComplete: ((String) -> Void)?
    var onImageCaptured: ((UIImage?) -> Void)?
    var onRequestReturnToQuestions: (() -> Void)? = nil
    var onOCRFailureRequestManualEntry: ((String) -> Void)? = nil
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var backgroundViewModel = DarumaSceneViewModel()
    @State private var showInstructionOverlay = false
    @State private var showOCRFailureDialog = false
    @State private var ocrFailureDialogMessage = ""

    var body: some View {
        ZStack {
            // だるまを裏面表示
            DarumaSceneView(viewModel: backgroundViewModel, showsBottomStaticView: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // 毛筆キャンバス（中央に配置）
            CalligraphyCanvasView(
                strokes: $viewModel.strokes,
                isErasing: viewModel.isErasing,
                inkColor: .black,
                lineWidth: canvasLineWidth,
                backgroundColor: .clear,
                onCoordinatorReady: { coordinator in
                    viewModel.canvasCoordinator = coordinator
                }
            )
            .clipShape(Circle())
            .frame(width: 560, height: 560)

            // エラーメッセージ（中央上部）
            if let errorMessage = errorMessage {
                VStack {
                    Text(errorMessage)
                        .foregroundColor(.white)
                        .font(.shiranui(size: 14))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Spacer()
                }
                .padding(.top, 100)
            }

            // 右下にボタンを配置
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 14) {
                        // ペン/消しゴム切り替え
                        PenEraserToggle(isErasing: Binding(
                            get: { viewModel.isErasing },
                            set: { newValue in
                                if newValue { viewModel.switchToEraser() } else { viewModel.switchToPen() }
                            }
                        ))
                        .disabled(isProcessing)

                        // NextStepボタン
                        Button(action: {
                            SoundPlayer.shared.playSelect()
                            Task {
                                await runCompletion()
                            }
                        }) {
                            Group {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    HStack(spacing: 12) {
                                        Text("NextStep")
                                            .font(.shiranui(size: 20))
                                        Image(systemName: "arrow.right")
                                            .font(.shiranui(size: 20))
                                    }
                                }
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
                        .disabled(isProcessing)
                    }
                    .foregroundStyle(.white)
                    .padding(.trailing, 32)
                    .padding(.bottom, 40)
                }
            }

            // 左上に戻るボタンと説明動画
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let onRequestReturnToQuestions {
                            Button(action: {
                                SoundPlayer.shared.playSelect()
                                onRequestReturnToQuestions()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.shiranui(size: 20))
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.white)
                        }

                        // 説明動画
                        VideoPlayerView(resourceName: "daruma_ura", fileExtension: "mov")
                            .frame(width: 260, height: 195)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    Spacer()
                }
                .padding(.leading, 32)
                .padding(.top, 30)
                Spacer()
            }

            if showInstructionOverlay {
                instructionOverlay
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .onAppear {
            updateBackgroundColor()
            showInstructionOverlay = instructionMode != .none
        }
        .onChange(of: darumaColor?.id ?? "default") {
            updateBackgroundColor()
        }
        .background {
            tatamiBackgroundLayer
        }
        .confirmationDialog(
            "We couldn't recognize the handwriting",
            isPresented: $showOCRFailureDialog,
            titleVisibility: .visible
        ) {
            Button("Retry") {
                SoundPlayer.shared.playSelect()
                errorMessage = "Please write a little larger and more clearly, then try again."
            }
            .tint(.black)
            if let onOCRFailureRequestManualEntry {
                Button("Enter Text Instead") {
                    SoundPlayer.shared.playSelect()
                    onOCRFailureRequestManualEntry(ocrFailureDialogMessage)
                }
            }
            Button("Cancel", role: .cancel) {
                SoundPlayer.shared.playSelect()
            }
        } message: {
            Text("You can try again or switch to text input.")
        }
    }

    @ViewBuilder
    private var instructionOverlay: some View {
        switch instructionMode {
        case .none:
            EmptyView()
        case .diagnosisPreOCR:
            DiagnosisPreOCRInstructionSlideOverlay(onStart: dismissInstructionOverlay)
        case .ritualPostResult:
            WritingInstructionSlideOverlay(onStart: dismissInstructionOverlay)
        }
    }

    private func runCompletion() async {
        guard onOCRComplete != nil || onComplete != nil else {
            return
        }
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
        }
        do {
            let shouldOCR = onOCRComplete != nil
            let capturedImage = viewModel.saveDrawingAsImage()
            if shouldOCR {
                onImageCaptured?(capturedImage)
            }
            let result = try await viewModel.performCompletion(shouldPerformOCR: shouldOCR)
            await MainActor.run {
                isProcessing = false
                switch result {
                case .recognizedText(let text):
                    onOCRComplete?(text)
                case .capturedImage(let image):
                    let finalImage = image ?? capturedImage
                    onImageCaptured?(finalImage)
                    onComplete?(finalImage)
                }
            }
        } catch let error as DarumaWishWritingViewModel.CompletionError {
            await MainActor.run {
                isProcessing = false
                switch error {
                case .recognitionFailed(let message):
                    if onOCRFailureRequestManualEntry != nil {
                        ocrFailureDialogMessage = "Failed to recognize your handwriting: \(message)"
                        showOCRFailureDialog = true
                    } else {
                        errorMessage = error.errorDescription
                    }
                case .emptyDrawing, .missingHandlers:
                    errorMessage = error.errorDescription
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    private func dismissInstructionOverlay() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showInstructionOverlay = false
        }
    }

    private func updateBackgroundColor() {
        // だるまの底が手前に来るように、ほぼ真下から見上げる角度に設定
        backgroundViewModel.fixedXRotation = -.pi * 0.5
        backgroundViewModel.fixedYRotation = 0
        backgroundViewModel.enableAutoRotation = false
        backgroundViewModel.customScale = 19.0
        backgroundViewModel.cameraYOffset = -2.3
        backgroundViewModel.cameraZOffset = 3.0
        backgroundViewModel.cameraXOffset = 0.0
        backgroundViewModel.emphasizeBottomLighting = true

        let target = darumaColor ?? .red
        var newScores: [DarumaColor: Double] = [:]
        for color in DarumaColor.allCases {
            newScores[color] = (color == target) ? 1.0 : 0.0
        }
        backgroundViewModel.currentScores = newScores
        backgroundViewModel.targetScores = newScores
        backgroundViewModel.scoreTransitionProgress = 1.0
    }

    private var canvasLineWidth: CGFloat {
        switch instructionMode {
        case .diagnosisPreOCR:
            return 6
        case .ritualPostResult:
            return 6
        case .none:
            return 20
        }
    }

    private var tatamiBackgroundLayer: some View {
        Image.onlyTatamiBackground
            .resizable()
            .scaledToFill()
            .blur(radius: 8)
            .ignoresSafeArea()
            .overlay(Color.black.opacity(0.15).ignoresSafeArea())
    }

    @ViewBuilder
    private func writingSurface(for color: DarumaColor?) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(white: 0.99), Color(white: 0.92)],
                    center: .center,
                    startRadius: 10,
                    endRadius: 300
                )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 8)
    }
}

private struct WritingInstructionSlideOverlay: View {
    let onStart: () -> Void

    var body: some View {
        PagedGuideOverlay(
            overlayOpacity: 0.8,
            pageHeight: 340,
            widthPadding: 40,
            minWidth: 280,
            maxWidth: 720,
            verticalSpacing: 18,
            usesSystemPageIndicator: true,
            showsCTAOnlyOnLastPage: true,
            pages: [
                AnyView(slide(
                    icon: "square.and.pencil",
                    title: "Write your wish on the base of the daruma",
                    message: "Write your wish here in one sentence. Short and clear works best."
                )),
                AnyView(slide(
                    icon: "paintbrush.fill",
                    title: "Experience Japanese Brush Culture",
                    message: "We use a brush-style writing experience so you can enjoy a touch of traditional Japanese culture while writing your wish."
                )),
                AnyView(slide(
                    icon: "checkmark.circle.fill",
                    title: "Start When You're Ready",
                    message: "Press the \"Start Writing\" button and begin writing."
                ))
            ],
            cta: AnyView(
                Button(action: {
                    SoundPlayer.shared.playSelect()
                    onStart()
                }) {
                    Text("Start Writing")
                        .font(.shiranui(size: 20))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.customRed)
                        )
                }
                .buttonStyle(.plain)
            )
        )
    }

    private func slide(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color.customRed)

            Text(title)
                .font(.shiranui(size: 34))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.shiranui(size: 17))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DiagnosisPreOCRInstructionSlideOverlay: View {
    let onStart: () -> Void

    var body: some View {
        PagedGuideOverlay(
            overlayOpacity: 0.8,
            pageHeight: 340,
            widthPadding: 40,
            minWidth: 280,
            maxWidth: 720,
            verticalSpacing: 18,
            usesSystemPageIndicator: true,
            showsCTAOnlyOnLastPage: true,
            pages: [
                AnyView(slide(
                    icon: "square.and.pencil",
                    title: "If You Know Your Wish, Write It",
                    message: "Write your current wish in one sentence. Short and readable helps the diagnosis."
                )),
                AnyView(slide(
                    icon: "text.viewfinder",
                    title: "We'll Read the Text Next",
                    message: "We use text recognition, so write each character large, slowly, and clearly."
                )),
                AnyView(slide(
                    icon: "checkmark.message",
                    title: "You'll Review It After Recognition",
                    message: "You can review the recognized text afterward. If it fails, you can switch to text input."
                ))
            ],
            cta: AnyView(
                Button(action: {
                    SoundPlayer.shared.playSelect()
                    onStart()
                }) {
                    Text("Start Writing")
                        .font(.shiranui(size: 20))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.customRed)
                        )
                }
                .buttonStyle(.plain)
            )
        )
    }

    private func slide(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color.customRed)

            Text(title)
                .font(.shiranui(size: 30))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Text(message)
                .font(.shiranui(size: 17))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
