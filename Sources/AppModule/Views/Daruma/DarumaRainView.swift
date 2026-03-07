import SwiftUI
import SceneKit
import UIKit
import ImageIO

/// ダルマ降下エフェクトを表示するView
struct DarumaRainView: View {
    @State private var viewModel = DarumaRainViewModel()

    /// カメラ演出が完了しUI表示可能になったタイミング
    var onCameraAnimationComplete: (() -> Void)?

    init(onCameraAnimationComplete: (() -> Void)? = nil) {
        self.onCameraAnimationComplete = onCameraAnimationComplete
    }

    var body: some View {
        ZStack {
            Image.tatamiBackground
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blur(radius: 8)
            // 3Dシーン
            GeometryReader { proxy in
                DarumaRainSceneWrapper(viewModel: viewModel)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
            }
            GeometryReader { proxy in
                VStack {
                if viewModel.isNagareboshiVisible {
                    NagareboshiAnimatedView(speedMultiplier: 3.6)
                        .frame(width: proxy.size.width * 0.9)
                        .padding(.top, 8)
                }
                    Spacer(minLength: 0)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            viewModel.startColorAnimation()
        }
        .onDisappear {
            viewModel.stopRain()
        }
        .onChange(of: viewModel.isCameraZoomOutComplete) { _, isComplete in
            if isComplete {
                onCameraAnimationComplete?()
            }
        }
    }
}

private struct NagareboshiAnimatedView: UIViewRepresentable {
    var speedMultiplier: Double = 1.0

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = false
        imageView.backgroundColor = .clear
        let tint = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0)

        if let data = loadNagareboshiData(),
           let animated = makeAnimatedImage(from: data, tint: tint) {
            imageView.image = animated
        } else if let data = loadNagareboshiData(),
                  let image = UIImage(data: data) {
            imageView.image = tintImage(image, color: tint)
        }

        imageView.startAnimating()
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if !uiView.isAnimating {
            uiView.startAnimating()
        }
    }

    private func loadNagareboshiData() -> Data? {
        if let url = Bundle.main.url(forResource: "nagareboshi", withExtension: "png", subdirectory: "Image"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: "nagareboshi", withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }

    private func makeAnimatedImage(from data: Data, tint: UIColor) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return nil }

        var images: [UIImage] = []
        images.reserveCapacity(count)
        var duration: TimeInterval = 0

        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let image = UIImage(cgImage: cgImage)
            images.append(tintImage(image, color: tint))
            duration += frameDuration(at: index, source: source)
        }

        if duration <= 0 {
            duration = Double(count) * 0.1
        }
        duration = max(0.02, duration / max(speedMultiplier, 0.1))

        return UIImage.animatedImage(with: images, duration: duration)
    }


    private func tintImage(_ image: UIImage, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: image.size)
            image.draw(in: rect)
            color.setFill()
            ctx.cgContext.setBlendMode(.sourceAtop)
            ctx.cgContext.fill(rect)
        }
    }

    private func frameDuration(at index: Int, source: CGImageSource) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let pngDict = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any] else {
            return 0.1
        }
        if let unclamped = pngDict[kCGImagePropertyAPNGUnclampedDelayTime] as? Double, unclamped > 0 {
            return unclamped
        }
        if let delay = pngDict[kCGImagePropertyAPNGDelayTime] as? Double, delay > 0 {
            return delay
        }
        return 0.1
    }
}

/// SceneKitビューのUIViewRepresentableラッパー
struct DarumaRainSceneWrapper: UIViewRepresentable {
    @Bindable var viewModel: DarumaRainViewModel

    @MainActor
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = context.coordinator.darumaScene.scene
        sceneView.autoenablesDefaultLighting = false
        sceneView.allowsCameraControl = false
        sceneView.backgroundColor = .clear
        sceneView.isOpaque = false
        sceneView.antialiasingMode = .multisampling2X
        sceneView.preferredFramesPerSecond = 30
        sceneView.isPlaying = true
        sceneView.rendersContinuously = false
        sceneView.pointOfView = context.coordinator.darumaScene.pointOfView

        context.coordinator.start()

        return sceneView
    }

    @MainActor
    func updateUIView(_ uiView: SCNView, context: Context) {
        // ViewModelの状態に応じて更新
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    @MainActor
    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        Task { @MainActor in
            coordinator.stop()
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator {
        let darumaScene: DarumaRainScene
        let viewModel: DarumaRainViewModel

        private var displayLink: CADisplayLink?
        private var lastUpdateTime: TimeInterval = 0
        private var lastSpinVisible: Bool = false

        /// カメラズームアウト開始済みフラグ
        private var hasCameraZoomOutStarted: Bool = false

        /// 全ダルマ動き出し開始済みフラグ
        private var hasAllDarumasStartedMoving: Bool = false
        /// カメラズームアウトを先行開始する進行度
        private let cameraZoomOutStartProgress: Double = 0.76
        /// レーン/降下開始を前倒しする進行度
        private let laneMotionStartProgress: Double = 0.84

        init(viewModel: DarumaRainViewModel) {
            self.viewModel = viewModel
            self.darumaScene = DarumaRainScene()
        }

        /// アニメーション開始
        func start() {
            lastUpdateTime = CACurrentMediaTime()
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.add(to: .main, forMode: .common)
            darumaScene.startCenterDarumaSpinAndColor()
        }

        /// アニメーション停止
        func stop() {
            displayLink?.invalidate()
            displayLink = nil
        }

        /// フレーム更新
        @objc private func update() {
            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - lastUpdateTime
            lastUpdateTime = currentTime

            // 回転中だけ流れ星を表示
            let isSpinning = darumaScene.isCenterDarumaSpinning
            if isSpinning != lastSpinVisible {
                lastSpinVisible = isSpinning
                viewModel.isNagareboshiVisible = isSpinning
            }

            // 色変化アニメーション更新
            viewModel.updateColorAnimation(deltaTime: deltaTime)

            // カメラは色変化完了を待たず、少し早めに引き始める
            if !hasCameraZoomOutStarted,
               viewModel.colorProgress >= cameraZoomOutStartProgress {
                hasCameraZoomOutStarted = true
                darumaScene.startCameraZoomOut()
            }

            // レーン/降下は色変化完了より少し前に開始して待ち感を減らす
            if !hasAllDarumasStartedMoving,
               (viewModel.colorProgress >= laneMotionStartProgress || viewModel.isColorAnimationComplete) {
                hasAllDarumasStartedMoving = true
                darumaScene.startAllDarumasMoving()
                darumaScene.startCenterDarumaFlow()
                if !hasCameraZoomOutStarted {
                    hasCameraZoomOutStarted = true
                    darumaScene.startCameraZoomOut()
                }
                viewModel.startRain()
            }

            // カメラズームアウト完了をViewModelに通知
            if darumaScene.hasCameraZoomOutCompleted && !viewModel.isCameraZoomOutComplete {
                viewModel.isCameraZoomOutComplete = true
            }

            // 等間隔でだるまを生成（isRainingの時のみ）
            if viewModel.isRaining {
                darumaScene.update(deltaTime: deltaTime)
            }

            // レーンの縞々アニメーション更新（降下開始と同時に動かす）
            if hasAllDarumasStartedMoving {
                darumaScene.updateLaneAnimation(deltaTime: deltaTime)
            }

            // 古いダルマを削除
            darumaScene.cleanupOldDarumas()
        }

        func startCenterDarumaFlow() {
            darumaScene.startCenterDarumaFlow()
        }
    }
}
