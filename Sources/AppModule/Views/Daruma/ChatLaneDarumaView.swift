import SwiftUI
import SceneKit
import UIKit

/// ChatView用のレーンベースだるま表示ビュー
struct ChatLaneDarumaView: View {
    @Bindable var viewModel: ChatLaneDarumaViewModel

    var body: some View {
        ChatLaneDarumaViewWrapper(viewModel: viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// SceneKitのビューをSwiftUIで使用するためのラッパー
struct ChatLaneDarumaViewWrapper: UIViewRepresentable {
    @Bindable var viewModel: ChatLaneDarumaViewModel

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = context.coordinator.darumaScene.scene
        sceneView.pointOfView = context.coordinator.darumaScene.pointOfView
        sceneView.autoenablesDefaultLighting = false
        sceneView.allowsCameraControl = false
        sceneView.backgroundColor = .clear
        sceneView.isOpaque = false
        sceneView.antialiasingMode = .multisampling4X

        // ドラッグジェスチャーを追加
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        sceneView.addGestureRecognizer(panGesture)

        // アニメーションループを開始
        context.coordinator.startAnimation()

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // トランジションフラグをチェック
        context.coordinator.checkAndPerformTransitionIfNeeded()
        // 色の変更を検知してだるまの色を更新
        context.coordinator.updateDarumaColorIfNeeded()
        // ロード中アニメーションを制御
        context.coordinator.updateLoadingAnimationIfNeeded()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    @MainActor
    final class Coordinator {
        let viewModel: ChatLaneDarumaViewModel
        let darumaScene: ChatLaneDarumaScene
        private var displayLink: CADisplayLink?
        private var lastUpdateTime: TimeInterval = 0
        private var lastPanTime: TimeInterval = 0
        private var lastAppliedColor: DarumaColor?
        private var isInitialized: Bool = false
        private var hasTriggeredTransition: Bool = false
        private var lastLoadingState: Bool = false

        init(viewModel: ChatLaneDarumaViewModel) {
            self.viewModel = viewModel
            self.darumaScene = ChatLaneDarumaScene()
        }

        /// アニメーションループを開始
        func startAnimation() {
            guard !isInitialized else { return }
            isInitialized = true

            // 初期だるまを設定
            darumaScene.setupInitialDaruma(color: viewModel.currentColor)
            lastAppliedColor = viewModel.currentColor
            viewModel.transitionDuration = darumaScene.transitionDurationValue

            lastUpdateTime = CACurrentMediaTime()
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.add(to: .current, forMode: .common)
        }

        /// ドラッグジェスチャーのハンドラ
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let currentTime = CACurrentMediaTime()

            switch gesture.state {
            case .began:
                // ドラッグ開始時：慣性速度をリセット
                viewModel.manualRotationVelocity = 0
                viewModel.lastInteractionTime = currentTime
                lastPanTime = currentTime

            case .changed:
                let translation = gesture.translation(in: gesture.view)
                // 横方向のドラッグ量に応じて回転角度を更新
                let rotationSensitivity = 0.01
                let deltaRotation = Double(translation.x) * rotationSensitivity
                viewModel.manualRotationY += deltaRotation

                // 速度計算
                let deltaTime = currentTime - lastPanTime
                if deltaTime > 0 {
                    viewModel.manualRotationVelocity = deltaRotation / deltaTime
                }
                lastPanTime = currentTime

                // ジェスチャーの移動量をリセット
                gesture.setTranslation(.zero, in: gesture.view)
                viewModel.lastInteractionTime = currentTime

            case .ended, .cancelled:
                // ドラッグ終了時：速度を計算して慣性を設定
                let velocity = gesture.velocity(in: gesture.view)
                let rotationSensitivity = 0.01
                viewModel.manualRotationVelocity = Double(velocity.x) * rotationSensitivity * 0.15
                viewModel.lastInteractionTime = currentTime

            default:
                break
            }
        }

        /// フレーム更新
        @objc private func update() {
            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - lastUpdateTime
            lastUpdateTime = currentTime

            // 慣性による回転の減衰処理
            viewModel.updateInertia(deltaTime: deltaTime)

            // ロード中でなければ手動回転を適用
            if !darumaScene.isInLoadingAnimation {
                darumaScene.applyManualRotation(rotationY: Float(viewModel.manualRotationY))
            }

            // レーンアニメーションを更新
            darumaScene.updateLaneAnimation(deltaTime: deltaTime)

            // 背景レーン用の速度を反映
            viewModel.laneScrollSpeed = Double(darumaScene.currentLaneScrollSpeed)
        }

        /// 色が変わったかチェックして更新
        /// 注意: 色の変更はトランジション時のみ行う
        /// この関数では即座の色更新は行わない（トランジション時に新しい色が適用される）
        func updateDarumaColorIfNeeded() {
            // 色の変更はトランジション時のみ行うため、ここでは何もしない
        }

        /// トランジションフラグをチェックしてトランジションを実行
        func checkAndPerformTransitionIfNeeded() {
            // ViewModelのトランジションフラグが立っていて、まだトリガーしていない場合
            if viewModel.isTransitioning && !hasTriggeredTransition {
                hasTriggeredTransition = true
                let newColor = viewModel.currentColor
                darumaScene.performTransition(to: newColor) { [weak self] in
                    Task { @MainActor in
                        self?.hasTriggeredTransition = false
                        self?.lastAppliedColor = newColor
                    }
                }
                viewModel.transitionDuration = darumaScene.transitionDurationValue
            }
            // トランジションフラグがリセットされたらフラグもリセット
            if !viewModel.isTransitioning {
                hasTriggeredTransition = false
            }
        }

        /// トランジションを実行
        func performTransition(to newColor: DarumaColor) {
            guard !viewModel.isTransitioning else { return }

            viewModel.beginTransition()
            darumaScene.performTransition(to: newColor) { [weak self] in
                Task { @MainActor in
                    self?.viewModel.endTransition()
                    self?.lastAppliedColor = newColor
                }
            }
        }

        /// ロード中アニメーションを更新
        func updateLoadingAnimationIfNeeded() {
            let isLoading = viewModel.isLoading
            guard lastLoadingState != isLoading else { return }
            lastLoadingState = isLoading

            if isLoading {
                darumaScene.startLoadingAnimation()
            } else {
                darumaScene.stopLoadingAnimation()
            }
        }

    }
}
