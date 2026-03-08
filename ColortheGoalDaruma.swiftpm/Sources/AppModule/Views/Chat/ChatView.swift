import SwiftUI
import UIKit
import SceneKit

struct ChatView: View {
    @ObservedObject var engine: ConversationEngine
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var freeformText: String = ""
    @State private var laneDarumaViewModel = ChatLaneDarumaViewModel()
    @State private var hasShownFirstQuestion = false

    private var questionTransitionAnimation: Animation {
        hasShownFirstQuestion ? .linear(duration: laneDarumaViewModel.transitionDuration) : .linear(duration: 0)
    }

    var body: some View {
        ZStack {
            Image.tatamiBackground
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blur(radius: 8)
            ChatLaneBackgroundView(viewModel: laneDarumaViewModel)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            ChatLaneDarumaView(viewModel: laneDarumaViewModel)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 36) {
                progressSection()
                ZStack(alignment: .topLeading) {
                    questionHeader(question: engine.presentedQuestion)
                        .padding(.horizontal, 48)
                        .frame(maxWidth: .infinity)
                }

                // 全ての質問を同じ HStack レイアウトで処理
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 20) {
                        ZStack(alignment: .bottomTrailing) {}
                    }
                    .frame(maxWidth: .infinity)

                    choicesColumn(question: engine.presentedQuestion)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 48)
                .frame(maxHeight: .infinity)
            }
            .padding(.vertical, 40)
            .zIndex(1)
            .onChange(of: engine.reasoningScores) { _, newScores in
                updateDarumaColor(using: newScores)
            }
            .onChange(of: engine.presentedQuestion?.id) { oldId, newId in
                // 質問が変わった時にトランジションをトリガー（初回も含む）
                if newId != nil && oldId != newId {
                    if !hasShownFirstQuestion {
                        hasShownFirstQuestion = true
                    } else {
                        triggerDarumaTransition()
                    }
                }
                // ロード状態を更新
                updateLoadingState()
            }
            .onAppear {
                updateDarumaColor(using: engine.reasoningScores)
                // 初期ロード状態を設定
                updateLoadingState()
            }
        }
    }

    /// 質問文のヘッダー
    private func questionHeader(question: PresentedQuestion?) -> some View {
        if let prompt = question?.prompt {
            return AnyView(
                DarumaGuideBubble {
                    Text("Q. \(prompt)")
                        .font(.shiranui(size: 32))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            )
        } else {
            return AnyView(
                DarumaGuideBubble {
                    LoadingQuestionHeader()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            )
        }
    }

    private func progressSection() -> some View {
        let total = engine.progressState.total
        let answered = engine.phase == .result ? total : engine.progressState.answered

        return HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < answered
                          ? Color.customRed
                          : Color.white.opacity(0.5))
                    .frame(height: 8)
                    .animation(.easeInOut(duration: 0.4), value: answered)
            }
        }
        .padding(.horizontal, 48)
    }

    /// 選択肢のカラム
    @ViewBuilder
    private func choicesColumn(question: PresentedQuestion?) -> some View {
        let isThemeSelection = question?.key == .initialCategorySelection

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let question {
                    switch question.responseKind {
                    case .multipleChoice:
                        if question.key == .initialCategorySelection {
                            categoryGrid(for: question)
                                .padding(.top, 20)
                        } else {
                            ForEach(question.choices) { choice in
                                ChoiceButton(title: choice.title, detail: choice.detail, action: {
                                    engine.selectChoice(choice)
                                })
                                .disabled(engine.isProcessing)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                        removal: .opacity))
                            }
                        }
                    case .freeform:
                        VStack(spacing: 10) {
                            TextField("Write anything you like", text: $freeformText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(4, reservesSpace: true)
                            PrimaryActionButton(
                                title: "Send",
                                systemImage: "paperplane.fill",
                                isDisabled: engine.isProcessing || freeformText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ) {
                                engine.submitFreeformAnswer(freeformText)
                                freeformText = ""
                            }
                            SecondaryActionButton(
                                title: "Skip for now",
                                systemImage: "forward.fill",
                                isDisabled: engine.isProcessing
                            ) {
                                freeformText = ""
                                engine.skipCurrentQuestion()
                            }
                        }
                        .animation(questionTransitionAnimation, value: question.id)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.top, isThemeSelection ? -18 : 0)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func categoryGrid(for question: PresentedQuestion) -> some View {
        let columns = horizontalSizeClass == .compact
            ? [GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(question.choices) { choice in
                let style = CategoryStyle.from(choice: choice)
                CategoryCard(
                    title: choice.title,
                    detail: choice.detail,
                    gradient: style.gradient,
                    icon: style.icon
                ) {
                    engine.selectChoice(choice)
                }
                .disabled(engine.isProcessing)
            }
        }
        .animation(questionTransitionAnimation, value: question.id)
    }

    private func reasoningSnapshots() -> [ColorPredictionSnapshot] {
        let sorted = engine.reasoningScores
            .map { (color: $0.key, score: max(0, $0.value)) }
            .sorted(by: { $0.score > $1.score })
            .prefix(3)
        let total = sorted.reduce(0) { $0 + $1.score }
        guard total > 0 else { return [] }
        return sorted.enumerated().map { index, element in
            let percent = Int((element.score / total * 100).rounded())
            return ColorPredictionSnapshot(id: index, color: element.color, percent: percent)
        }
    }

    private func updateDarumaColor(using scores: [DarumaColor: Double]) {
        laneDarumaViewModel.updateFromScores(scores)
    }

    /// ロード状態を更新（質問がnilの時はローディングアニメーション）
    private func updateLoadingState() {
        laneDarumaViewModel.isLoading = engine.presentedQuestion == nil
    }

    /// 質問が変わった時にだるまのトランジションをトリガー
    private func triggerDarumaTransition() {
        // ViewModelのフラグを使ってトランジションを開始
        // 実際のアニメーションはChatLaneDarumaView内のCoordinatorが処理
        laneDarumaViewModel.beginTransition()
        laneDarumaViewModel.isLaneAnimating = true

        // トランジション完了後にフラグをリセット（アニメーション時間に合わせる）
        let duration = laneDarumaViewModel.transitionDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            Task { @MainActor in
                laneDarumaViewModel.endTransition()
            }
        }
    }

}

/// ChatView背景用のレーン表示ビュー
private struct ChatLaneBackgroundView: UIViewRepresentable {
    @Bindable var viewModel: ChatLaneDarumaViewModel

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = context.coordinator.scene.scene
        sceneView.pointOfView = context.coordinator.scene.pointOfView
        sceneView.autoenablesDefaultLighting = false
        sceneView.allowsCameraControl = false
        sceneView.backgroundColor = .clear
        sceneView.isOpaque = false
        sceneView.antialiasingMode = .multisampling2X
        sceneView.preferredFramesPerSecond = 30
        sceneView.isPlaying = true

        context.coordinator.start()

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        Task { @MainActor in
            coordinator.stop()
        }
    }

    @MainActor
    final class Coordinator {
        let scene = ChatLaneBackgroundScene()
        let viewModel: ChatLaneDarumaViewModel
        private var displayLink: CADisplayLink?
        private var lastUpdateTime: TimeInterval = 0

        init(viewModel: ChatLaneDarumaViewModel) {
            self.viewModel = viewModel
        }

        func start() {
            lastUpdateTime = CACurrentMediaTime()
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.add(to: .main, forMode: .common)
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func update() {
            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - lastUpdateTime
            lastUpdateTime = currentTime
            let speed = Float(viewModel.laneScrollSpeed)
            scene.updateLaneAnimation(deltaTime: deltaTime, scrollSpeed: speed)
        }
    }
}

private struct ColorPredictionSnapshot: Identifiable {
    let id: Int
    let color: DarumaColor
    let percent: Int
}

private struct ColorChipStack: View {
    let snapshots: [ColorPredictionSnapshot]
    @State private var isLongPressing: Bool = false

    var body: some View {
        if snapshots.isEmpty {
            EmptyView()
        } else {
            let topID = snapshots.first?.id
            VStack(alignment: .trailing, spacing: 6) {
                ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                    let isTop = snapshot.id == topID
                    let percentText = String(format: "%02d", snapshot.percent)

                    HStack(spacing: 10) {
                        // 長押し中はテキストを表示
                        if isLongPressing {
                            Text("\(percentText)% \(snapshot.color.focusKeyword)")
                                .font(.shiranui(size: 14))
                                .monospacedDigit()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                        }

                        DarumaChipImageView(color: snapshot.color, size: isTop ? 42 : 32, variantIndex: index)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(4)
            .contentShape(Rectangle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.2)
                    .onChanged { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isLongPressing = true
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isLongPressing = false
                        }
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLongPressing)
        }
    }
}

/// だるまの形をしたチップ
private struct DarumaChip: View {
    let color: DarumaColor
    let size: CGFloat

    var body: some View {
        ZStack {
            // 本体（楕円）
            Ellipse()
                .fill(LinearGradient(
                    colors: color.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size * 1.1)

            // 顔の部分（白い楕円）
            Ellipse()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.55, height: size * 0.45)
                .offset(y: -size * 0.15)

            // 目（2つの点）
            HStack(spacing: size * 0.12) {
                Circle()
                    .fill(Color.black)
                    .frame(width: size * 0.1, height: size * 0.1)
                Circle()
                    .fill(Color.black)
                    .frame(width: size * 0.1, height: size * 0.1)
            }
            .offset(y: -size * 0.15)
        }
    }
}

private struct DarumaChipImageView: View {
    let color: DarumaColor
    let size: CGFloat
    let variantIndex: Int

    var body: some View {
        Group {
            if let image = darumaChipImage(for: color, variantIndex: variantIndex) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(chipGradient(for: color))
            } else {
                DarumaChip(color: color, size: size)
            }
        }
        .frame(width: size, height: size * 1.1)
        .shadow(color: color.gradient.first?.opacity(0.4) ?? .clear, radius: 6, x: 0, y: 3)
    }
}

private func darumaChipImage(for color: DarumaColor, variantIndex: Int) -> Image? {
    let bundle = Bundle.main
    let variantNames = ["Vector", "Vector-1", "Vector-2"]
    var candidates: [String] = []
    if let variant = variantNames[safe: variantIndex] {
        candidates.append(variant)
    }
    candidates.append(contentsOf: variantNames)

    for name in candidates {
        if let image = templateImage(named: name, bundle: bundle) {
            return image
        }
    }
    return nil
}

private func templateImage(named name: String, bundle: Bundle) -> Image? {
    if bundle.url(forResource: name, withExtension: "pdf", subdirectory: "Image") != nil {
        return Image(name, bundle: bundle).renderingMode(.template)
    }
    if bundle.url(forResource: name, withExtension: "png", subdirectory: "Image") != nil {
        return Image(name, bundle: bundle).renderingMode(.template)
    }
    return nil
}

private func chipGradient(for color: DarumaColor) -> LinearGradient {
    LinearGradient(
        colors: color.gradient,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private struct LoadingQuestionHeader: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.customRed)
                    .frame(width: 10, height: 10)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
