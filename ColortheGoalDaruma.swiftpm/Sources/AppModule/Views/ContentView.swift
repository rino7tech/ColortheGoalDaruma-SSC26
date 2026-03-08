import SwiftUI

struct ContentView: View {
    var darumaStore: DarumaStore? = nil
    var onReturnToTop: (() -> Void)? = nil
    var onShowCollection: (() -> Void)? = nil
    @StateObject private var engine = ConversationEngine()
    @State private var writingViewModel = DarumaWishWritingViewModel()
    @State private var eyeDrawingViewModel = DarumaEyeDrawingViewModel()
    @State private var wishImage: UIImage?
    /// 左目画像
    @State private var eyeImage: UIImage?
    /// 右目画像（drawingEyeフェーズで取得）
    @State private var rightEyeImage: UIImage?
    @State private var arPlacementColor: DarumaColor?
    @State private var isShowingARPlacement = false
    @State private var hasStartedConversation = false
    @State private var showOnboardingOverlay = true

    private var resultPhaseTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: ScreenTransitionModifier(opacity: 0, scale: 1.03, x: 42, y: 8, blur: 10),
                identity: ScreenTransitionModifier(opacity: 1, scale: 1, x: 0, y: 0, blur: 0)
            ),
            removal: .modifier(
                active: ScreenTransitionModifier(opacity: 0, scale: 0.985, x: -26, y: 0, blur: 6),
                identity: ScreenTransitionModifier(opacity: 1, scale: 1, x: 0, y: 0, blur: 0)
            )
        )
    }

    var body: some View {
        ZStack {
            if isShowingARPlacement, let color = arPlacementColor {
                DarumaARPlacementView(
                    color: color,
                    eyeImage: eyeImage,
                    wishImage: nil,
                    onDrawRightEye: {
                        arPlacementColor = nil
                        isShowingARPlacement = false
                        eyeDrawingViewModel = DarumaEyeDrawingViewModel()
                        engine.moveToDrawingEye()
                    },
                    onReturnToTitle: {
                        dismissARPlacementToTitle()
                    }
                )
                .transition(.opacity)
            } else {
                mainStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }

        }
        .preferredColorScheme(.light)
        .sheet(isPresented: ocrConfirmationSheetBinding) {
            OCRConfirmationView(
                ocrText: engine.ocrText,
                startsInManualEditing: engine.ocrConfirmationStartsInManualEdit,
                failureMessage: engine.ocrFailureMessage,
                onConfirm: {
                    engine.confirmOCRText()
                },
                onRejectAndEdit: { manualText in
                    engine.rejectOCRTextAndUseManualInput(manualText)
                },
                onRetryOCR: {
                    writingViewModel = DarumaWishWritingViewModel()
                    updateWishImage(with: nil)
                    engine.returnToWritingBeforeDiagnosisFromOCRConfirmation()
                }
            )
            .interactiveDismissDisabled(true)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !hasStartedConversation {
                hasStartedConversation = true
                engine.start()
            }
        }
    }

    @ViewBuilder
    private var mainStage: some View {
        ZStack {
            switch engine.phase {
            case .inProgress:
                ZStack {
                    ChatView(engine: engine)

                    // オンボーディングオーバーレイ（3ページスワイプ）
                    if showOnboardingOverlay {
                        SplashOnboardingView {
                            withAnimation { showOnboardingOverlay = false }
                        }
                        .transition(.opacity)
                    }
                }

            case .writingBeforeDiagnosis, .ocrConfirmation:
                // 診断前に願い事を書く（「はい」を選んだ場合）
                DarumaWritingView(
                    viewModel: writingViewModel,
                    darumaColor: nil,
                    instructionMode: .diagnosisPreOCR,
                    title: "Write your wish before diagnosis",
                    subtitle: "Capture your current wish in your own words.",
                    onOCRComplete: { recognizedText in
                        let rawImage = writingViewModel.saveDrawingAsImage()
                        updateWishImage(with: rawImage)
                        engine.processOCRText(recognizedText)
                    },
                    onImageCaptured: { image in
                        updateWishImage(with: image)
                    },
                    onRequestReturnToQuestions: {
                        engine.returnToWishClarityQuestionFromWriting()
                    },
                    onOCRFailureRequestManualEntry: { failureMessage in
                        engine.presentManualEntryAfterOCRFailure(errorMessage: failureMessage)
                    }
                )

            case .result:
                if let result = engine.result {
                    DarumaDetailView(
                        result: result,
                        onRestart: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                                engine.reset()
                                onReturnToTop?()
                            }
                        },
                        onNext: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                                if engine.shouldProceedToEyeAfterResult {
                                    engine.moveToDrawingLeftEye()
                                } else {
                                    engine.moveToWritingAfterResult()
                                }
                            }
                        },
                        nextButtonTitle: "NextStep"
                    )
                    .transition(resultPhaseTransition)
                } else {
                    ProgressView()
                        .tint(Color.customRed)
                }

            case .ritualOnboarding:
                // 願い事書き+目入れの説明画面
                if let result = engine.result {
                    RitualOnboardingView(darumaColor: result.color) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                            engine.moveToWritingAfterResult()
                        }
                    }
                }

            case .writingAfterResult:
                // 結果後に願い事を書く
                if let result = engine.result {
                    DarumaWritingView(
                        viewModel: writingViewModel,
                        darumaColor: result.color,
                        instructionMode: .ritualPostResult,
                        title: "Write your wish on the Daruma",
                        subtitle: "Turn your result into one actionable intention.",
                        onComplete: { image in
                            updateWishImage(with: image)
                            engine.moveToDrawingLeftEye()
                        }
                    )
                }

            case .drawingEye:
                // 2回目: だるまの右目を描く
                if let result = engine.result {
                    DarumaEyeDrawingView(
                        viewModel: eyeDrawingViewModel,
                        darumaColor: result.color,
                        leftEyeImage: eyeImage,
                        onComplete: { image in
                            rightEyeImage = image
                            engine.moveToCongratulations()
                        }
                    )
                    .id("right-eye-drawing")
                }

            case .drawingLeftEye:
                // 1回目: だるまの左目を描く
                if let result = engine.result {
                    DarumaEyeDrawingView(
                        viewModel: eyeDrawingViewModel,
                        darumaColor: result.color,
                        eyeSide: .left,
                        onComplete: { image in
                            eyeImage = image
                            presentARPlacement(for: result.color)
                        }
                    )
                    .id("left-eye-drawing")
                }

            case .closing:
                // Closing画面
                if let result = engine.result {
                    ClosingView(
                        darumaColor: result.color,
                        onDrawRightEye: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                                eyeDrawingViewModel = DarumaEyeDrawingViewModel()
                                engine.moveToDrawingEye()
                            }
                        },
                        onStartOver: {
                            saveDaruma(isFulfilled: false)
                            engine.reset()
                            onReturnToTop?()
                        }
                    )
                }

            case .congratulations:
                // 右目描き完了後の達成画面
                if let result = engine.result {
                    DarumaAchievementView(
                        daruma: SavedDaruma(
                            darumaColor: result.color,
                            wishSentence: result.wishSummary,
                            wishImageData: wishImage?.jpegData(compressionQuality: 0.8),
                            leftEyeImageData: eyeImage?.pngData(),
                            rightEyeImageData: rightEyeImage?.pngData(),
                            isWishFulfilled: true
                        ),
                        onViewCollection: {
                            saveDaruma(isFulfilled: true)
                            resetRitualProgressState()
                            engine.reset()
                            if let onShowCollection {
                                onShowCollection()
                            } else {
                                onReturnToTop?()
                            }
                        },
                        onReturnToTitle: {
                            saveDaruma(isFulfilled: true)
                            resetRitualProgressState()
                            engine.reset()
                            onReturnToTop?()
                        }
                    )
                }
        }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.55), value: engine.phase)
    }

    private func presentARPlacement(for color: DarumaColor) {
        arPlacementColor = color
        isShowingARPlacement = true
    }

    private var ocrConfirmationSheetBinding: Binding<Bool> {
        Binding(
            get: { engine.phase == .ocrConfirmation },
            set: { _ in }
        )
    }

    private func dismissARPlacementToTitle() {
        saveDaruma(isFulfilled: false)
        resetRitualProgressState()
        engine.reset()
        DispatchQueue.main.async {
            onReturnToTop?()
        }
    }

    /// だるまをストアに保存する
    private func saveDaruma(isFulfilled: Bool) {
        guard let result = engine.result else { return }
        let daruma = SavedDaruma(
            darumaColor: result.color,
            wishSentence: result.wishSummary,
            wishImageData: wishImage?.jpegData(compressionQuality: 0.8),
            leftEyeImageData: eyeImage?.pngData(),
            rightEyeImageData: rightEyeImage?.jpegData(compressionQuality: 0.8),
            isWishFulfilled: isFulfilled
        )
        darumaStore?.save(daruma)
    }

    private func resetRitualProgressState() {
        writingViewModel = DarumaWishWritingViewModel()
        eyeDrawingViewModel = DarumaEyeDrawingViewModel()
        wishImage = nil
        eyeImage = nil
        rightEyeImage = nil
        arPlacementColor = nil
        isShowingARPlacement = false
    }

    private func updateWishImage(with image: UIImage?) {
        guard let image else {
            wishImage = nil
            return
        }
        wishImage = WishImageProcessor.transparentWishImage(from: image) ?? image
    }

}

private struct ScreenTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: CGFloat
    let x: CGFloat
    let y: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(x: x, y: y)
            .blur(radius: blur)
    }
}
