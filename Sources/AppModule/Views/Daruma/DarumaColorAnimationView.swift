import SwiftUI
import SceneKit

/// だるまの色染めアニメーションを表示するView
struct DarumaColorAnimationView: View {
    @Bindable var viewModel: DarumaColorAnimationViewModel

    var body: some View {
        ColorAnimationSceneViewWrapper(viewModel: viewModel)
            .frame(minWidth: 300, minHeight: 300)
            .onAppear {
                viewModel.startAnimation()
            }
    }
}

/// SceneKitビューのUIViewRepresentableラッパー
struct ColorAnimationSceneViewWrapper: UIViewRepresentable {
    @Bindable var viewModel: DarumaColorAnimationViewModel

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = context.coordinator.scene
        sceneView.autoenablesDefaultLighting = false
        sceneView.allowsCameraControl = true
        sceneView.backgroundColor = .clear
        sceneView.isOpaque = false
        sceneView.antialiasingMode = .multisampling4X

        context.coordinator.startAnimation()

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateColor()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator {
        let scene: SCNScene
        var darumaNode: SCNNode
        let viewModel: DarumaColorAnimationViewModel
        private var displayLink: CADisplayLink?
        private var lastUpdateTime: TimeInterval = 0
        private let cameraNode: SCNNode
        private var baseTexture: UIImage?

        /// 開始色（白）
        private let startColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        /// 終了色（赤）
        private let endColor = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0)

        init(viewModel: DarumaColorAnimationViewModel) {
            self.viewModel = viewModel
            self.scene = SCNScene()
            self.darumaNode = SCNNode()
            self.cameraNode = SCNNode()

            // テクスチャをロード
            baseTexture = loadTexture()

            setupCamera()
            setupLighting()

            let daruma = createDaruma()
            self.darumaNode = daruma
            scene.rootNode.addChildNode(daruma)
        }

        /// テクスチャ画像をロード
        private func loadTexture() -> UIImage? {
            if let url = Bundle.main.url(forResource: "Daruma_texture", withExtension: "png", subdirectory: "3D"),
               let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
            if let url = Bundle.main.url(forResource: "Daruma_texture", withExtension: "png"),
               let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
            return nil
        }

        // MARK: - セットアップ

        private func setupCamera() {
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 60
            cameraNode.position = SCNVector3(0, 0.5, 6.5)
            scene.rootNode.addChildNode(cameraNode)
        }

        private func setupLighting() {
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light?.type = .ambient
            ambientLight.light?.intensity = 560
            ambientLight.light?.color = UIColor(white: 0.62, alpha: 1.0)
            scene.rootNode.addChildNode(ambientLight)

            let directionalLight = SCNNode()
            directionalLight.light = SCNLight()
            directionalLight.light?.type = .directional
            directionalLight.light?.intensity = 310
            directionalLight.light?.castsShadow = false
            directionalLight.light?.color = UIColor(white: 1.0, alpha: 0.5)
            directionalLight.position = SCNVector3(2.5, 3.8, 4.0)
            directionalLight.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(directionalLight)

            let fillAmbient = SCNNode()
            fillAmbient.light = SCNLight()
            fillAmbient.light?.type = .ambient
            fillAmbient.light?.intensity = 280
            fillAmbient.light?.color = UIColor(white: 1.0, alpha: 0.1)
            scene.rootNode.addChildNode(fillAmbient)
        }

        // MARK: - だるま作成

        private func createDaruma() -> SCNNode {
            let darumaNode = SCNNode()
            let orientedModelNode = SCNNode()

            var url: URL?
            if let bundleURL = Bundle.main.url(forResource: "Daruma", withExtension: "usdz", subdirectory: "3D") {
                url = bundleURL
            } else if let bundleURL = Bundle.main.url(forResource: "3D/Daruma", withExtension: "usdz") {
                url = bundleURL
            } else if let bundleURL = Bundle.main.url(forResource: "Daruma", withExtension: "usdz") {
                url = bundleURL
            }

            if let url = url,
               let scene = try? SCNScene(url: url, options: nil) {
                for childNode in scene.rootNode.childNodes {
                    orientedModelNode.addChildNode(childNode)
                }
                orientedModelNode.eulerAngles.x = -.pi / 2
                darumaNode.addChildNode(orientedModelNode)

                // スケーリング（小さめに表示）
                let (minBounds, maxBounds) = darumaNode.boundingBox
                let size = SCNVector3(
                    x: maxBounds.x - minBounds.x,
                    y: maxBounds.y - minBounds.y,
                    z: maxBounds.z - minBounds.z
                )
                let maxDimension = max(size.x, size.y, size.z)
                let scale = 2.5 / max(maxDimension, 0.001)
                darumaNode.scale = SCNVector3(scale, scale, scale)

                // 初期マテリアルを適用
                applyMaterial(to: darumaNode, color: startColor)
            } else {
                let sphere = SCNSphere(radius: 1.5)
                let material = makeSceneKitMaterial(color: startColor)
                sphere.materials = [material]
                let sphereNode = SCNNode(geometry: sphere)
                darumaNode.addChildNode(sphereNode)
            }

            darumaNode.position = SCNVector3(0, -1.0, 0)
            return darumaNode
        }

        // MARK: - マテリアル（DarumaSceneViewと同じパターン）

        /// DarumaSceneViewと同じ方法でマテリアルを作成
        private func makeSceneKitMaterial(color: UIColor) -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.isDoubleSided = true

            // テクスチャに色を合成した画像を作成
            if let tintedImage = createTintedTexture(with: color) {
                material.diffuse.contents = tintedImage
            } else {
                material.diffuse.contents = color
            }

            material.roughness.contents = NSNumber(value: 0.82)
            material.metalness.contents = NSNumber(value: 0.04)
            material.emission.contents = UIColor.black

            return material
        }

        /// テクスチャに色を合成した画像を作成
        private func createTintedTexture(with color: UIColor) -> UIImage? {
            guard let texture = baseTexture else { return nil }

            let format = UIGraphicsImageRendererFormat()
            format.scale = 2.0
            let renderer = UIGraphicsImageRenderer(size: texture.size, format: format)

            return renderer.image { ctx in
                let rect = CGRect(origin: .zero, size: texture.size)

                // 背景色を描画
                color.setFill()
                ctx.fill(rect)

                // テクスチャを上に描画
                texture.draw(in: rect)
            }
        }

        /// ノードにマテリアルを再帰的に適用
        private func applyMaterial(to node: SCNNode, color: UIColor) {
            if let geometry = node.geometry {
                let material = makeSceneKitMaterial(color: color)
                geometry.materials = geometry.materials.isEmpty ? [material] : Array(repeating: material, count: geometry.materials.count)
            }
            for child in node.childNodes {
                applyMaterial(to: child, color: color)
            }
        }

        /// 2つの色を補間
        private func interpolateColor(from: UIColor, to: UIColor, progress: CGFloat) -> UIColor {
            var fromR: CGFloat = 0, fromG: CGFloat = 0, fromB: CGFloat = 0, fromA: CGFloat = 0
            var toR: CGFloat = 0, toG: CGFloat = 0, toB: CGFloat = 0, toA: CGFloat = 0

            from.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
            to.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)

            let r = fromR + (toR - fromR) * progress
            let g = fromG + (toG - fromG) * progress
            let b = fromB + (toB - fromB) * progress
            let a = fromA + (toA - fromA) * progress

            return UIColor(red: r, green: g, blue: b, alpha: a)
        }

        // MARK: - 色更新

        func updateColor() {
            let progress = CGFloat(viewModel.progress)
            let currentColor = interpolateColor(from: startColor, to: endColor, progress: progress)
            applyMaterial(to: darumaNode, color: currentColor)
        }

        // MARK: - アニメーション

        func startAnimation() {
            lastUpdateTime = CACurrentMediaTime()
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.add(to: .main, forMode: .common)
        }

        @objc private func update() {
            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - lastUpdateTime
            lastUpdateTime = currentTime

            viewModel.updateAnimation(deltaTime: deltaTime)
            updateColor()
        }

    }
}
