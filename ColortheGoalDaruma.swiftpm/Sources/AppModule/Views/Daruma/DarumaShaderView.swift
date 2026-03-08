import SwiftUI
import SceneKit

/// ダルマが下から上へ染まるアニメーションを表示するView
struct DarumaShaderView: View {
    var onAnimationComplete: (() -> Void)?

    private let duration: Double = 2.5

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image.tatamiBackground
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 8)

                DarumaShaderSceneView(
                    duration: duration,
                    onAnimationComplete: onAnimationComplete
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// SceneKitを使用してダルマの染色アニメーションを表示するUIViewRepresentable
struct DarumaShaderSceneView: UIViewRepresentable {
    let duration: Double
    var onAnimationComplete: (() -> Void)?

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = context.coordinator.scene
        sceneView.autoenablesDefaultLighting = false
        sceneView.allowsCameraControl = false
        sceneView.backgroundColor = .clear
        sceneView.isOpaque = false
        sceneView.antialiasingMode = .multisampling2X
        sceneView.preferredFramesPerSecond = 60
        sceneView.isPlaying = true
        sceneView.pointOfView = context.coordinator.cameraNode

        // アニメーションを開始
        context.coordinator.startAnimation(duration: duration) { [onAnimationComplete] in
            onAnimationComplete?()
        }

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // SCNActionでアニメーションを管理するため、ここでは何もしない
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator {
        let scene: SCNScene
        let cameraNode: SCNNode
        private var darumaNode: SCNNode?
        private var darumaMaterials: [SCNMaterial] = []
        private var darumaMinY: Float = 0
        private var darumaHeight: Float = 1
        private var completionHandler: (() -> Void)?

        /// ベーステクスチャ
        private var baseTexture: UIImage?

        /// 中央ダルマの開始色（白）
        private let startColor = UIColor.white

        /// 中央ダルマの終了色（赤）
        private let endColor = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0)

        /// アニメーション開始済みフラグ
        private var hasStartedAnimation = false

        init() {
            self.scene = SCNScene()
            self.cameraNode = SCNNode()
            self.baseTexture = loadTexture()

            setupCamera()
            setupLighting()
            setupDaruma()
        }

        /// アニメーションを開始
        func startAnimation(duration: Double, completion: @escaping () -> Void) {
            guard !hasStartedAnimation else { return }
            hasStartedAnimation = true
            completionHandler = completion

            guard let node = darumaNode else {
                DispatchQueue.main.async {
                    completion()
                }
                return
            }

            // SCNAction.customActionでプログレスを更新
            let animationAction = SCNAction.customAction(duration: duration) { [weak self] _, elapsedTime in
                guard let self else { return }
                Task { @MainActor in
                    let progress = min(max(Double(elapsedTime) / duration, 0.0), 1.0)
                    self.updateProgress(progress)
                }
            }

            // SCNAction.runはメインスレッドで実行される保証がないため、明示的にMainActorで実行
            let completionAction = SCNAction.run { [weak self] _ in
                Task { @MainActor in
                    self?.completionHandler?()
                }
            }

            let sequence = SCNAction.sequence([animationAction, completionAction])
            node.runAction(sequence, forKey: "dyeAnimation")
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

        /// カメラ設定
        private func setupCamera() {
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 45
            cameraNode.position = SCNVector3(0, 0, 10)
            cameraNode.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(cameraNode)
        }

        /// ライティング設定
        private func setupLighting() {
            // アンビエントライト
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light?.type = .ambient
            ambientLight.light?.intensity = 580
            ambientLight.light?.color = UIColor(white: 0.64, alpha: 1.0)
            scene.rootNode.addChildNode(ambientLight)

            let directionalLight = SCNNode()
            directionalLight.light = SCNLight()
            directionalLight.light?.type = .directional
            directionalLight.light?.intensity = 300
            directionalLight.light?.castsShadow = false
            directionalLight.light?.color = UIColor(white: 1.0, alpha: 0.48)
            directionalLight.position = SCNVector3(2.4, 3.6, 4.0)
            directionalLight.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(directionalLight)

            // 軽めの補助アンビエント
            let fillAmbient = SCNNode()
            fillAmbient.light = SCNLight()
            fillAmbient.light?.type = .ambient
            fillAmbient.light?.intensity = 300
            fillAmbient.light?.color = UIColor(white: 1.0, alpha: 0.1)
            scene.rootNode.addChildNode(fillAmbient)
        }

        /// ダルマモデルをセットアップ
        private func setupDaruma() {
            let container = SCNNode()
            let orientedModelNode = SCNNode()

            guard let url = locateModelURL(),
                  let modelScene = try? SCNScene(url: url, options: nil) else {
                // フォールバック: 球体
                let sphere = SCNSphere(radius: 1.5)
                let material = createDyeMaterial()
                sphere.materials = [material]
                darumaMaterials = [material]
                let sphereNode = SCNNode(geometry: sphere)
                container.addChildNode(sphereNode)
                scene.rootNode.addChildNode(container)
                darumaNode = container
                return
            }

            for childNode in modelScene.rootNode.childNodes {
                orientedModelNode.addChildNode(childNode)
            }
            orientedModelNode.eulerAngles.x = -.pi / 2
            container.addChildNode(orientedModelNode)

            // スケーリング
            let (minBounds, maxBounds) = container.boundingBox
            let size = SCNVector3(
                x: maxBounds.x - minBounds.x,
                y: maxBounds.y - minBounds.y,
                z: maxBounds.z - minBounds.z
            )
            let maxDimension = max(size.x, size.y, size.z)
            let scale: Float = 4.0 / max(maxDimension, 0.001)
            container.scale = SCNVector3(scale, scale, scale)

            // 中央に配置
            alignModelCenter(container)
            container.position = SCNVector3(0, 0, 0)

            // マテリアル適用
            updateDarumaModelBounds(for: container)
            applyDyeMaterial(to: container)

            scene.rootNode.addChildNode(container)
            darumaNode = container
        }

        /// 染色用マテリアルを作成
        private func createDyeMaterial() -> SCNMaterial {
            let textureSize = baseTexture?.size ?? CGSize(width: 256, height: 256)
            let startTexture = createSolidTexture(color: startColor, size: textureSize)
            let endTexture = createTintedTexture(with: endColor) ?? createSolidTexture(color: endColor, size: textureSize)

            let material = SCNMaterial()
            material.lightingModel = .lambert
            material.isDoubleSided = true
            material.shaderModifiers = [
                .surface: """
                uniform float dyeProgress;
                uniform float centerMinY;
                uniform float centerHeight;
                uniform float gradientSoftness;
                uniform sampler2D startTexture;
                uniform sampler2D endTexture;

                #pragma body
                // ワールド座標に変換してY座標を取得
                float4 worldPos = scn_node.modelTransform * float4(_surface.position, 1.0);
                float normalizedY = clamp((worldPos.y - centerMinY) / max(centerHeight, 0.0001), 0.0, 1.0);
                float edge = clamp(dyeProgress, 0.0, 1.0);
                float mixFactor = 1.0 - smoothstep(edge - gradientSoftness, edge + gradientSoftness, normalizedY);
                if (edge <= 0.0) {
                    mixFactor = 0.0;
                } else if (edge >= 1.0) {
                    mixFactor = 1.0;
                }
                vec2 uv = _surface.diffuseTexcoord;
                vec4 startColor = texture2D(startTexture, uv);
                vec4 endColor = texture2D(endTexture, uv);
                vec4 finalColor = mix(startColor, endColor, mixFactor);
                _surface.diffuse = finalColor;
                _surface.ambient = finalColor;
                """
            ]

            material.setValue(0.0, forKey: "dyeProgress")
            material.setValue(darumaMinY, forKey: "centerMinY")
            material.setValue(darumaHeight, forKey: "centerHeight")
            material.setValue(0.05, forKey: "gradientSoftness")
            material.setValue(SCNMaterialProperty(contents: startTexture), forKey: "startTexture")
            material.setValue(SCNMaterialProperty(contents: endTexture), forKey: "endTexture")

            return material
        }

        /// 単色テクスチャを作成
        private func createSolidTexture(color: UIColor, size: CGSize) -> UIImage {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2.0
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            return renderer.image { ctx in
                color.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
            }
        }

        /// テクスチャに色を合成した画像を作成
        private func createTintedTexture(with color: UIColor) -> UIImage? {
            guard let texture = baseTexture else { return nil }

            let format = UIGraphicsImageRendererFormat()
            format.scale = 2.0
            let renderer = UIGraphicsImageRenderer(size: texture.size, format: format)

            return renderer.image { ctx in
                let rect = CGRect(origin: .zero, size: texture.size)
                color.setFill()
                ctx.fill(rect)
                texture.draw(in: rect)
            }
        }

        /// マテリアルをノードに適用
        private func applyDyeMaterial(to node: SCNNode) {
            darumaMaterials.removeAll()
            applyDyeMaterialRecursive(to: node)
        }

        private func applyDyeMaterialRecursive(to node: SCNNode) {
            if let geometry = node.geometry {
                let material = createDyeMaterial()
                // ワールド座標系の値をそのまま使用（シェーダー内でワールド座標に変換するため）
                material.setValue(darumaMinY, forKey: "centerMinY")
                material.setValue(darumaHeight, forKey: "centerHeight")

                geometry.materials = geometry.materials.isEmpty ? [material] : Array(repeating: material, count: geometry.materials.count)
                darumaMaterials.append(material)
            }
            for child in node.childNodes {
                applyDyeMaterialRecursive(to: child)
            }
        }

        /// 進行度を更新
        func updateProgress(_ progress: Double) {
            let clampedProgress = min(max(progress, 0.0), 1.0)
            for material in darumaMaterials {
                material.setValue(clampedProgress, forKey: "dyeProgress")
            }
        }

        /// モデルURLを取得
        private func locateModelURL() -> URL? {
            if let url = Bundle.main.url(forResource: "Daruma", withExtension: "usdz", subdirectory: "3D") {
                return url
            }
            if let url = Bundle.main.url(forResource: "3D/Daruma", withExtension: "usdz") {
                return url
            }
            return Bundle.main.url(forResource: "Daruma", withExtension: "usdz")
        }

        /// モデルの中心を原点に揃える
        private func alignModelCenter(_ node: SCNNode) {
            let (minBounds, maxBounds) = node.boundingBox
            let centerY = (minBounds.y + maxBounds.y) / 2
            for child in node.childNodes {
                child.position.y -= centerY
            }
        }

        /// モデルのワールド座標での上下端を計算
        private func updateDarumaModelBounds(for node: SCNNode) {
            var minY: Float = .greatestFiniteMagnitude
            var maxY: Float = -.greatestFiniteMagnitude

            func visit(_ current: SCNNode) {
                if let geometry = current.geometry {
                    let (minB, maxB) = geometry.boundingBox
                    let corners = [
                        SCNVector3(minB.x, minB.y, minB.z),
                        SCNVector3(minB.x, minB.y, maxB.z),
                        SCNVector3(minB.x, maxB.y, minB.z),
                        SCNVector3(minB.x, maxB.y, maxB.z),
                        SCNVector3(maxB.x, minB.y, minB.z),
                        SCNVector3(maxB.x, minB.y, maxB.z),
                        SCNVector3(maxB.x, maxB.y, minB.z),
                        SCNVector3(maxB.x, maxB.y, maxB.z)
                    ]
                    // ワールド座標に変換（nilでワールド座標）
                    for corner in corners {
                        let worldPos = current.convertPosition(corner, to: nil)
                        minY = min(minY, worldPos.y)
                        maxY = max(maxY, worldPos.y)
                    }
                }
                for child in current.childNodes {
                    visit(child)
                }
            }

            visit(node)

            if minY == .greatestFiniteMagnitude || maxY == -.greatestFiniteMagnitude {
                darumaMinY = 0
                darumaHeight = 1
                return
            }

            darumaMinY = minY
            darumaHeight = max(maxY - minY, 0.001)
        }
    }
}
