import SwiftUI
import MetalKit

/// 毛筆風描画キャンバスのSwiftUIラッパー
struct CalligraphyCanvasView: UIViewRepresentable {
    @Binding var strokes: [CalligraphyStroke]
    var isErasing: Bool
    var inkColor: UIColor = .black
    var lineWidth: CGFloat = 20
    var backgroundColor: UIColor = .clear
    var onCoordinatorReady: ((Coordinator) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = CalligraphyMTKView()
        mtkView.layer.isOpaque = false
        mtkView.backgroundColor = .clear

        guard let renderer = CalligraphyRenderer(mtkView: mtkView) else {
            return mtkView
        }

        renderer.inkColor = inkColor
        renderer.baseLineWidth = lineWidth
        renderer.backgroundColor = backgroundColor
        renderer.strokes = strokes

        mtkView.delegate = renderer
        context.coordinator.renderer = renderer
        context.coordinator.mtkView = mtkView
        (mtkView as CalligraphyMTKView).coordinator = context.coordinator
        notifyCoordinatorReady(context.coordinator)

        mtkView.setNeedsDisplay()
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        // Keep coordinator state in sync with latest SwiftUI props (e.g. eraser toggle).
        context.coordinator.parent = self
        renderer.inkColor = inkColor
        renderer.baseLineWidth = lineWidth
        renderer.backgroundColor = backgroundColor
        renderer.strokes = strokes
        notifyCoordinatorReady(context.coordinator)
        uiView.setNeedsDisplay()
    }

    private func notifyCoordinatorReady(_ coordinator: Coordinator) {
        guard let onCoordinatorReady else { return }
        DispatchQueue.main.async {
            onCoordinatorReady(coordinator)
        }
    }

    /// 描画内容をUIImageとしてキャプチャ
    static func captureImage(coordinator: Coordinator) -> UIImage? {
        guard let renderer = coordinator.renderer,
              let mtkView = coordinator.mtkView else { return nil }
        let scale = mtkView.contentScaleFactor
        return renderer.captureImage(viewSize: mtkView.bounds.size, scale: scale)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {
        var parent: CalligraphyCanvasView
        var renderer: CalligraphyRenderer?
        var mtkView: MTKView?
        private var currentStroke: CalligraphyStroke?

        init(parent: CalligraphyCanvasView) {
            self.parent = parent
        }

        /// SwiftUI側の状態だけでなく、レンダラ/タッチ中ストロークも含めて完全にクリア
        func clearCanvas() {
            currentStroke = nil
            parent.strokes.removeAll()
            renderer?.strokes = []
            mtkView?.setNeedsDisplay()
        }

        func stopIdleHint() {
            (mtkView as? CalligraphyMTKView)?.stopIdleHintCycle()
        }

        /// タッチ開始
        func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: view)

            if parent.isErasing {
                // 消しゴムモード: タッチ位置に近いストロークを削除
                eraseStroke(at: location)
            } else {
                // 描画モード: 新しいストロークを開始
                let pressure = touch.type == .pencil ? touch.force / max(touch.maximumPossibleForce, 0.001) : 0.75
                let point = CalligraphyPoint(
                    position: location,
                    pressure: pressure,
                    timestamp: touch.timestamp
                )
                let stroke = CalligraphyStroke(points: [point])
                currentStroke = stroke
                parent.strokes.append(stroke)
                renderer?.strokes = parent.strokes
                mtkView?.setNeedsDisplay()
            }
        }

        /// タッチ移動
        func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: view)

            if parent.isErasing {
                eraseStroke(at: location)
            } else if let stroke = currentStroke {
                // 合体タッチイベントも取得（Apple Pencilの高精度入力）
                if let coalescedTouches = event?.coalescedTouches(for: touch), coalescedTouches.count > 1 {
                    for coalesced in coalescedTouches {
                        let loc = coalesced.location(in: view)
                        let pressure = coalesced.type == .pencil ? coalesced.force / max(coalesced.maximumPossibleForce, 0.001) : 0.75
                        stroke.points.append(CalligraphyPoint(
                            position: loc,
                            pressure: pressure,
                            timestamp: coalesced.timestamp
                        ))
                    }
                } else {
                    let pressure = touch.type == .pencil ? touch.force / max(touch.maximumPossibleForce, 0.001) : 0.75
                    stroke.points.append(CalligraphyPoint(
                        position: location,
                        pressure: pressure,
                        timestamp: touch.timestamp
                    ))
                }
                renderer?.strokes = parent.strokes
                mtkView?.setNeedsDisplay()
            }
        }

        /// タッチ終了
        func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
            guard let touch = touches.first else { return }

            if !parent.isErasing, let stroke = currentStroke {
                let location = touch.location(in: view)
                let pressure = touch.type == .pencil ? touch.force / max(touch.maximumPossibleForce, 0.001) : 0.75
                stroke.points.append(CalligraphyPoint(
                    position: location,
                    pressure: max(pressure, 0.1), // 抜きで最低限の太さを保持
                    timestamp: touch.timestamp
                ))
                renderer?.strokes = parent.strokes
                mtkView?.setNeedsDisplay()
            }
            currentStroke = nil
        }

        /// タッチキャンセル
        func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
            // キャンセル時は現在のストロークを破棄
            if let stroke = currentStroke {
                parent.strokes.removeAll { $0 === stroke }
                renderer?.strokes = parent.strokes
                mtkView?.setNeedsDisplay()
            }
            currentStroke = nil
        }

        /// 消しゴム: なぞった箇所のポイントだけ削除し、前後のセグメントを保持
        private func eraseStroke(at point: CGPoint) {
            let threshold: CGFloat = max(24, parent.lineWidth * 1.6)
            var newStrokes: [CalligraphyStroke] = []

            for stroke in parent.strokes {
                // 消しゴムストローク自体はそのまま保持
                guard !stroke.isEraser else {
                    newStrokes.append(stroke)
                    continue
                }

                // 消しゴム範囲内/外でポイントをセグメントに分割
                var segmentPoints: [CalligraphyPoint] = []
                for pt in stroke.points {
                    let dx = pt.position.x - point.x
                    let dy = pt.position.y - point.y
                    let isErased = dx * dx + dy * dy < threshold * threshold

                    if isErased {
                        // 消去範囲に入った — それまでのセグメントを保存（2点以上あれば有効）
                        if segmentPoints.count >= 2 {
                            newStrokes.append(CalligraphyStroke(points: segmentPoints))
                        }
                        segmentPoints = []
                    } else {
                        segmentPoints.append(pt)
                    }
                }
                // 末尾の残りセグメントを保存
                if segmentPoints.count >= 2 {
                    newStrokes.append(CalligraphyStroke(points: segmentPoints))
                }
            }

            parent.strokes = newStrokes
            renderer?.strokes = newStrokes
            mtkView?.setNeedsDisplay()
        }
    }
}

// MARK: - タッチを受け付けるMTKView

/// タッチイベントをCoordinatorに転送するカスタムMTKView
private class CalligraphyMTKView: MTKView {
    weak var coordinator: CalligraphyCanvasView.Coordinator?
    private let idleDelay: TimeInterval = 1.0
    private let pulseInterval: TimeInterval = 2.0
    private var idleTimer: Timer?
    private var pulseTimer: Timer?
    private var isIdleHintActive = false
    private var isTouching = false
    private var hasInteractedOnce = false
    private let hintImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 86, weight: .regular)
        let image = UIImage(systemName: "pencil.and.scribble", withConfiguration: config)
        let imageView = UIImageView(image: image)
        imageView.tintColor = UIColor.white.withAlphaComponent(0.75)
        imageView.contentMode = .scaleAspectFit
        imageView.alpha = 0
        imageView.isUserInteractionEnabled = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        isMultipleTouchEnabled = false
        setupIdleHintView()
        scheduleIdleHint()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupIdleHintView() {
        addSubview(hintImageView)
        NSLayoutConstraint.activate([
            hintImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            hintImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            hintImageView.widthAnchor.constraint(equalToConstant: 180),
            hintImageView.heightAnchor.constraint(equalToConstant: 180)
        ])
    }

    func stopIdleHintCycle() {
        idleTimer?.invalidate()
        idleTimer = nil
        pulseTimer?.invalidate()
        pulseTimer = nil
        stopIdleHintVisuals()
    }

    private func scheduleIdleHint() {
        guard !hasInteractedOnce else { return }
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.startIdleHintCycle()
            }
        }
    }

    private func startIdleHintCycle() {
        guard !isIdleHintActive, !isTouching else { return }
        isIdleHintActive = true
        runHintPulse()
        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: pulseInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.runHintPulse()
            }
        }
    }

    private func stopIdleHintVisuals() {
        isIdleHintActive = false
        pulseTimer?.invalidate()
        pulseTimer = nil
        hintImageView.layer.removeAllAnimations()
        hintImageView.alpha = 0
    }

    private func runHintPulse() {
        guard isIdleHintActive else { return }
        hintImageView.layer.removeAllAnimations()
        hintImageView.alpha = 0
        UIView.animate(withDuration: 0.45, delay: 0, options: [.curveEaseInOut]) {
            self.hintImageView.alpha = 0.42
        } completion: { _ in
            UIView.animate(withDuration: 0.7, delay: 0.05, options: [.curveEaseInOut]) {
                self.hintImageView.alpha = 0
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouching = true
        hasInteractedOnce = true
        idleTimer?.invalidate()
        idleTimer = nil
        stopIdleHintVisuals()
        coordinator?.touchesBegan(touches, with: event, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        stopIdleHintVisuals()
        coordinator?.touchesMoved(touches, with: event, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouching = false
        stopIdleHintVisuals()
        coordinator?.touchesEnded(touches, with: event, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouching = false
        stopIdleHintVisuals()
        coordinator?.touchesCancelled(touches, with: event, in: self)
    }
}

extension CalligraphyCanvasView {
    @MainActor
    static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        Task { @MainActor in
            coordinator.stopIdleHint()
        }
    }
}
