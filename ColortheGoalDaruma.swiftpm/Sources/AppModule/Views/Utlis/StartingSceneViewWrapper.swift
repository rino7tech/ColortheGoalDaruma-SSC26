import SwiftUI
import SceneKit

/// SceneKitビューのラッパー（StartingView用）
struct StartingSceneViewWrapper: UIViewRepresentable {
    @Bindable var viewModel: StartingViewModel

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = context.coordinator.scene
        sceneView.autoenablesDefaultLighting = false
        sceneView.allowsCameraControl = false
        sceneView.backgroundColor = .clear
        sceneView.isOpaque = false
        sceneView.antialiasingMode = .multisampling4X

        context.coordinator.startAnimation()

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    @MainActor
    final class Coordinator: NSObject {
        let scene: SCNScene
        var darumaNode: SCNNode
        let viewModel: StartingViewModel
        private var displayLink: CADisplayLink?
        private var lastUpdateTime: TimeInterval = 0
        private let cameraNode: SCNNode

        init(viewModel: StartingViewModel) {
            self.viewModel = viewModel
            self.scene = SCNScene()
            self.darumaNode = SCNNode()
            self.cameraNode = SCNNode()

            // super.initを呼ぶ
            super.init()

            setupCamera()
            setupLighting()

            let daruma = createDaruma()
            self.darumaNode = daruma
            self.darumaNode.opacity = 0.0
            scene.rootNode.addChildNode(daruma)
        }

        /// カメラの設定
        private func setupCamera() {
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 60
            cameraNode.position = SCNVector3(0, 0.5, 6.5)
            scene.rootNode.addChildNode(cameraNode)
        }

        /// ライティングの設定
        private func setupLighting() {
            // アンビエントライト
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light?.type = .ambient
            ambientLight.light?.intensity = 520
            ambientLight.light?.color = UIColor(white: 0.60, alpha: 1.0)
            scene.rootNode.addChildNode(ambientLight)

            let directionalLight = SCNNode()
            directionalLight.light = SCNLight()
            directionalLight.light?.type = .directional
            directionalLight.light?.intensity = 300
            directionalLight.light?.castsShadow = false
            directionalLight.light?.color = UIColor(white: 1.0, alpha: 0.46)
            directionalLight.position = SCNVector3(2.4, 3.8, 4.0)
            directionalLight.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(directionalLight)

            // 補助アンビエント
            let fillAmbient = SCNNode()
            fillAmbient.light = SCNLight()
            fillAmbient.light?.type = .ambient
            fillAmbient.light?.intensity = 270
            fillAmbient.light?.color = UIColor(white: 1.0, alpha: 0.1)
            scene.rootNode.addChildNode(fillAmbient)
        }

        /// だるまの3Dモデルを作成
        private func createDaruma() -> SCNNode {
            let darumaNode = SCNNode()
            let orientedModelNode = SCNNode()

            // DarumaSceneViewと同じロジックでモデルを読み込み
            var url: URL?
            if let bundleURL = Bundle.main.url(forResource: "Daruma", withExtension: "usdz", subdirectory: "3D") {
                url = bundleURL
                print("✅ Found Daruma.usdz in 3D subdirectory")
            } else if let bundleURL = Bundle.main.url(forResource: "3D/Daruma", withExtension: "usdz") {
                url = bundleURL
                print("✅ Found Daruma.usdz at 3D/Daruma")
            } else if let bundleURL = Bundle.main.url(forResource: "Daruma", withExtension: "usdz") {
                url = bundleURL
                print("✅ Found Daruma.usdz at root")
            } else {
                print("❌ Daruma.usdz not found!")
            }

            if let url = url,
               let scene = try? SCNScene(url: url, options: nil) {
                print("✅ USDZ model loaded successfully")
                for childNode in scene.rootNode.childNodes {
                    orientedModelNode.addChildNode(childNode)
                }
                orientedModelNode.eulerAngles.x = -.pi / 2  // 下向きを正面に補正
                darumaNode.addChildNode(orientedModelNode)

                // スケーリング
                let (minBounds, maxBounds) = darumaNode.boundingBox
                let size = SCNVector3(
                    x: maxBounds.x - minBounds.x,
                    y: maxBounds.y - minBounds.y,
                    z: maxBounds.z - minBounds.z
                )
                let maxDimension = max(size.x, size.y, size.z)
                let scale = 4.0 / max(maxDimension, 0.001)
                darumaNode.scale = SCNVector3(scale, scale, scale)
                print("✅ Model scaled to \(scale)")
            } else {
                // フォールバック: 球体
                print("⚠️ Using fallback sphere")
                let sphere = SCNSphere(radius: 1.5)
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.red
                sphere.materials = [material]
                let sphereNode = SCNNode(geometry: sphere)
                sphereNode.eulerAngles.x = -.pi / 2
                darumaNode.addChildNode(sphereNode)
            }

            darumaNode.position = SCNVector3(0, -1.8, 0)
            print("✅ Daruma node created at position (0, -1.8, 0)")

            return darumaNode
        }

        /// アニメーション開始
        func startAnimation() {
            print("🎬 StartingSceneViewWrapper: startAnimation called")
            lastUpdateTime = CACurrentMediaTime()
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.add(to: .main, forMode: .common)
            print("🎬 DisplayLink added to main RunLoop")
        }

        /// フレーム更新
        @objc private func update() {
            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - lastUpdateTime
            lastUpdateTime = currentTime

            // ViewModelの更新
            viewModel.updateAnimation(deltaTime: deltaTime)

            print("⏱️ Update: fillProgress = \(viewModel.fillProgress)")
            darumaNode.opacity = CGFloat(viewModel.fillProgress)
        }

    }
}
