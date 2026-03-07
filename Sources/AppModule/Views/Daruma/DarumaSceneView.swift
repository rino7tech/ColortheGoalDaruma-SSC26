import SwiftUI
import SceneKit
import UIKit

/// SceneKitを使ってだるまを3D表示するビュー
struct DarumaSceneView: View {
    @Bindable var viewModel: DarumaSceneViewModel
    var showsBottomStaticView: Bool = false

    var body: some View {
        SceneKitViewWrapper(viewModel: viewModel, showsBottomStaticView: showsBottomStaticView)
            .frame(minWidth: 500, minHeight: 300)
    }
}

@MainActor
private final class LightingEnvironmentTexture {
    static let shared = LightingEnvironmentTexture()
    let image: UIImage

    private init() {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        image = renderer.image { context in
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(white: 1.0, alpha: 1.0).cgColor,
                    UIColor(white: 0.8, alpha: 1.0).cgColor,
                    UIColor(white: 0.6, alpha: 1.0).cgColor
                ] as CFArray,
                locations: [0.0, 0.45, 1.0]
            ) else { return }

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: size.width / 2,
                options: [.drawsAfterEndLocation]
            )
        }
    }
}

/// SceneKitのビューをSwiftUIで使用するためのラッパー
struct SceneKitViewWrapper: UIViewRepresentable {
    @Bindable var viewModel: DarumaSceneViewModel
    var showsBottomStaticView: Bool

        func makeUIView(context: Context) -> SCNView {
            let sceneView = SCNView()
            sceneView.scene = context.coordinator.scene
            sceneView.autoenablesDefaultLighting = false
            sceneView.allowsCameraControl = false
            sceneView.backgroundColor = .clear
            sceneView.isOpaque = false
            sceneView.antialiasingMode = .multisampling4X

            // ドラッグジェスチャーを追加
            if !showsBottomStaticView {
                let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
                sceneView.addGestureRecognizer(panGesture)
                context.coordinator.startAnimation()
            }

            return sceneView
        }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateAppearance(
            color: viewModel.getCurrentDisplayColor(),
            dominantColor: viewModel.dominantColor()
        )
        context.coordinator.updateTransform()
        context.coordinator.updateWishPlate(with: viewModel.wishImage)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, showsBottomStaticView: showsBottomStaticView)
    }

    @MainActor
    final class Coordinator {
        let scene: SCNScene
        var darumaNode: SCNNode
        let viewModel: DarumaSceneViewModel
        private var displayLink: CADisplayLink?
        private var lastUpdateTime: TimeInterval = 0
        private let textureProvider = DarumaTextureProvider.shared
        private let showsBottomStaticView: Bool
        private let cameraNode: SCNNode
        private let trackingFillLightNode: SCNNode
        private let trackingFillLightMirrorNode: SCNNode
        private let modelBaseXRotation: Float = .pi / 2  // USDZが下向きのため正面補正
        private var modelBoundingMaxDimension: Float = 1.0
        private let emphasizeBottomLighting: Bool
        private var wishPlateNode: SCNNode?
        private var displayedWishImage: UIImage?
        private var lastPanTime: TimeInterval = 0
        private var lastPanTranslation: CGFloat = 0

        init(viewModel: DarumaSceneViewModel, showsBottomStaticView: Bool) {
            self.viewModel = viewModel
            self.showsBottomStaticView = showsBottomStaticView
            self.scene = SCNScene()
            self.darumaNode = SCNNode()
            self.cameraNode = SCNNode()
            self.trackingFillLightNode = SCNNode()
            self.trackingFillLightMirrorNode = SCNNode()
            self.emphasizeBottomLighting = viewModel.emphasizeBottomLighting

            cameraNode.camera = SCNCamera()
            cameraNode.camera?.usesOrthographicProjection = false
            cameraNode.camera?.fieldOfView = 60
            updateCameraPosition()
            scene.rootNode.addChildNode(cameraNode)

            setupLighting()
            scene.rootNode.addChildNode(trackingFillLightNode)
            scene.rootNode.addChildNode(trackingFillLightMirrorNode)

            let daruma = createDaruma()
            self.darumaNode = daruma
            scene.rootNode.addChildNode(daruma)
        }

        /// だるまの3Dモデルを作成
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
            } else {
                if let resourcePath = Bundle.main.resourcePath {
                    let fileManager = FileManager.default
                    if let contents = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                        print("📦 Root contents: \(contents.prefix(20).joined(separator: ", "))")
                    }
                    let threeDPath = (resourcePath as NSString).appendingPathComponent("3D")
                    if fileManager.fileExists(atPath: threeDPath) {
                        if let threeDContents = try? fileManager.contentsOfDirectory(atPath: threeDPath) {
                            print("📦 3D contents: \(threeDContents.joined(separator: ", "))")
                        }
                    }
                }
            }

            if let url = url,
               let scene = try? SCNScene(url: url, options: nil) {
                for childNode in scene.rootNode.childNodes {
                    orientedModelNode.addChildNode(childNode)
                }
                orientedModelNode.eulerAngles.x = -modelBaseXRotation
                darumaNode.addChildNode(orientedModelNode)

                let (minBounds, maxBounds) = darumaNode.boundingBox
                let size = SCNVector3(
                    x: maxBounds.x - minBounds.x,
                    y: maxBounds.y - minBounds.y,
                    z: maxBounds.z - minBounds.z
                )
                let maxDimension = Swift.max(size.x, size.y, size.z)
                modelBoundingMaxDimension = max(maxDimension, 0.001)
                applyModelScale()

                applyAppearance(to: darumaNode,
                                color: viewModel.getCurrentDisplayColor(),
                                dominantColor: viewModel.dominantColor())
            } else {
                let sphere = SCNSphere(radius: 1.5)
                let material = makeSceneKitMaterial(
                    displayColor: viewModel.getCurrentDisplayColor(),
                    dominantColor: viewModel.dominantColor()
                )
                sphere.materials = [material]

                let sphereNode = SCNNode(geometry: sphere)
                sphereNode.eulerAngles.x = -modelBaseXRotation
                darumaNode.addChildNode(sphereNode)
                modelBoundingMaxDimension = 3.0
                applyModelScale()
            }

            if showsBottomStaticView {
                darumaNode.eulerAngles.x = Float.pi
                darumaNode.eulerAngles.y = 0
                darumaNode.eulerAngles.z = 0
                darumaNode.position = SCNVector3(0, -0.3, 0)
            } else {
                darumaNode.eulerAngles.x = Float(viewModel.fixedXRotation)
                darumaNode.eulerAngles.y = Float(viewModel.fixedYRotation)
                darumaNode.eulerAngles.z = 0
                darumaNode.position = SCNVector3(0, -1.8, 0)
            }

            updateWishPlate(with: viewModel.wishImage)
            return darumaNode
        }

        func updateWishPlate(with image: UIImage?) {
            if let current = displayedWishImage, let image, current === image {
                return
            }
            if displayedWishImage == nil && image == nil {
                return
            }
            wishPlateNode?.removeFromParentNode()
            wishPlateNode = nil
            displayedWishImage = image
            guard let image else { return }
            guard let plate = DarumaWishPlateFactory.makePlateNode(attachedTo: darumaNode, wishImage: image) else { return }
            darumaNode.addChildNode(plate)
            wishPlateNode = plate
        }

        private func setupLighting() {
            scene.lightingEnvironment.contents = LightingEnvironmentTexture.shared.image
            scene.lightingEnvironment.intensity = 0.88

            let ambientLightNode = SCNNode()
            ambientLightNode.light = SCNLight()
            ambientLightNode.light?.type = .ambient
            ambientLightNode.light?.intensity = emphasizeBottomLighting ? 600 : 500
            ambientLightNode.light?.color = UIColor(white: emphasizeBottomLighting ? 0.64 : 0.58, alpha: 1.0)
            scene.rootNode.addChildNode(ambientLightNode)

            let directionalLight = SCNNode()
            directionalLight.light = SCNLight()
            directionalLight.light?.type = .directional
            directionalLight.light?.intensity = emphasizeBottomLighting ? 340 : 300
            directionalLight.light?.castsShadow = false
            directionalLight.light?.color = UIColor(white: 1.0, alpha: 0.55)
            directionalLight.position = SCNVector3(2.6, 3.8, 4.0)
            directionalLight.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(directionalLight)

            configureTrackingFillLight()
        }

        private func applyAppearance(to node: SCNNode, color: Color, dominantColor: DarumaColor?) {
            if let geometry = node.geometry {
                let material = makeSceneKitMaterial(displayColor: color, dominantColor: dominantColor)
                geometry.materials = geometry.materials.isEmpty ? [material] : Array(repeating: material, count: geometry.materials.count)
            }
            for childNode in node.childNodes {
                applyAppearance(to: childNode, color: color, dominantColor: dominantColor)
            }
        }

        private func makeSceneKitMaterial(displayColor: Color, dominantColor: DarumaColor?) -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.isDoubleSided = true

            if let dominantColor {
                let textureImage = textureProvider.tintedImageWithBothEyes(
                    for: dominantColor,
                    leftEyeImage: viewModel.leftEyeImage,
                    rightEyeImage: viewModel.rightEyeImage
                ) ?? textureProvider.tintedImage(for: dominantColor)
                material.diffuse.contents = textureImage
            } else {
                let uiColor = UIColor(displayColor)
                material.diffuse.contents = uiColor
            }

            material.roughness.contents = NSNumber(value: 0.82)
            material.metalness.contents = NSNumber(value: 0.04)
            material.emission.contents = UIColor.black
            return material
        }

        func startAnimation() {
            lastUpdateTime = CACurrentMediaTime()
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.add(to: .current, forMode: .common)
        }

        /// ドラッグジェスチャーのハンドラ
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let currentTime = CACurrentMediaTime()

            switch gesture.state {
            case .began:
                // ドラッグ開始時：慣性速度をリセット、操作時刻を更新
                viewModel.manualRotationVelocity = 0
                viewModel.lastInteractionTime = currentTime
                lastPanTime = currentTime
                lastPanTranslation = 0

            case .changed:
                let translation = gesture.translation(in: gesture.view)
                // 横方向のドラッグ量に応じて回転角度を更新
                let rotationSensitivity = 0.01
                let deltaRotation = Double(translation.x) * rotationSensitivity
                viewModel.manualRotationY += deltaRotation

                // 速度計算のために前回の値を記録
                let deltaTime = currentTime - lastPanTime
                if deltaTime > 0 {
                    // 速度を計算（ラジアン/秒）
                    viewModel.manualRotationVelocity = deltaRotation / deltaTime
                }
                lastPanTime = currentTime
                lastPanTranslation = translation.x

                // ジェスチャーの移動量をリセット
                gesture.setTranslation(.zero, in: gesture.view)
                viewModel.lastInteractionTime = currentTime

            case .ended, .cancelled:
                // ドラッグ終了時：速度を計算して慣性を設定
                let velocity = gesture.velocity(in: gesture.view)
                let rotationSensitivity = 0.01
                // 速度を減衰させて自然な慣性にする
                viewModel.manualRotationVelocity = Double(velocity.x) * rotationSensitivity * 0.15
                viewModel.lastInteractionTime = currentTime

            default:
                break
            }
        }

        @objc private func update() {
            guard !showsBottomStaticView else { return }
            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - lastUpdateTime
            lastUpdateTime = currentTime

            // 操作から一定時間（2秒）経過したかチェック
            let autoRotationPauseTime: TimeInterval = 2.0
            let timeSinceInteraction = currentTime - viewModel.lastInteractionTime
            let shouldAutoRotate = viewModel.enableAutoRotation && timeSinceInteraction > autoRotationPauseTime

            // アニメーション更新（慣性減衰は常に処理、自動回転は一定時間後のみ）
            if shouldAutoRotate {
                viewModel.updateAnimation(deltaTime: deltaTime)
            } else {
                // 慣性の減衰のみ処理
                if abs(viewModel.manualRotationVelocity) > 0.001 {
                    viewModel.manualRotationY += viewModel.manualRotationVelocity * deltaTime
                    let damping = 0.9
                    viewModel.manualRotationVelocity *= pow(damping, deltaTime * 60)
                    if abs(viewModel.manualRotationVelocity) < 0.001 {
                        viewModel.manualRotationVelocity = 0
                    }
                }
            }

            // 自動回転と手動回転を組み合わせる
            let autoRotation = shouldAutoRotate ? viewModel.rotationAngle : 0
            darumaNode.eulerAngles.y = Float(viewModel.fixedYRotation + autoRotation + viewModel.manualRotationY)
            darumaNode.eulerAngles.x = Float(viewModel.fixedXRotation)
            applyModelScale()
        }

        func updateAppearance(color: Color, dominantColor: DarumaColor?) {
            applyAppearance(to: darumaNode, color: color, dominantColor: dominantColor)
            updateWishPlate(with: viewModel.wishImage)
        }

        func updateTransform() {
            applyModelScale()
            updateCameraPosition()
        }

        private func applyModelScale() {
            guard modelBoundingMaxDimension > 0 else { return }
            let desiredSize: Float
            if let customScale = viewModel.customScale {
                desiredSize = customScale
            } else {
                desiredSize = showsBottomStaticView ? 4.5 : 4.0
            }
            let newScale = desiredSize / modelBoundingMaxDimension
            let scaleVector = SCNVector3(x: newScale, y: newScale, z: newScale)
            darumaNode.scale = scaleVector
        }

        private func configureTrackingFillLight() {
            trackingFillLightNode.light = SCNLight()
            trackingFillLightNode.light?.type = .ambient
            trackingFillLightNode.light?.intensity = emphasizeBottomLighting ? 240 : 190
            trackingFillLightNode.light?.color = UIColor(white: 1.0, alpha: emphasizeBottomLighting ? 0.14 : 0.11)

            trackingFillLightMirrorNode.light = SCNLight()
            trackingFillLightMirrorNode.light?.type = .ambient
            trackingFillLightMirrorNode.light?.intensity = emphasizeBottomLighting ? 190 : 150
            trackingFillLightMirrorNode.light?.color = UIColor(white: 1.0, alpha: emphasizeBottomLighting ? 0.11 : 0.09)

            updateTrackingFillLight()
        }

        private func updateTrackingFillLight() {
            // Ambient lights are global; no camera tracking is required.
        }

        private func updateCameraPosition() {
            let defaultY: Float = showsBottomStaticView ? 1.0 : 0.5
            let xOffset: Float = showsBottomStaticView ? 0 : viewModel.cameraXOffset
            let yOffset: Float = showsBottomStaticView ? 0 : viewModel.cameraYOffset
            let zOffset: Float = showsBottomStaticView ? 0 : viewModel.cameraZOffset
            let baseZ: Float = showsBottomStaticView ? 6.0 : 6.5
            cameraNode.position = SCNVector3(
                x: xOffset,
                y: defaultY + yOffset,
                z: baseZ + zOffset
            )
            updateTrackingFillLight()
        }

    }
}
