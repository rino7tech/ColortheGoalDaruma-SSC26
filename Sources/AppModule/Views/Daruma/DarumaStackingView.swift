import SwiftUI
import SceneKit
import UIKit

/// SwiftUI View that renders a playful stack of Daruma models raining down.
/// Represents a decorative effect that can be dropped anywhere in the app.
struct DarumaStackingView: View {
    var availableColors: [DarumaColor] = Array(DarumaColor.allCases)
    var spawnInterval: TimeInterval = 0.65
    var maxDarumaCount: Int = 32

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            DarumaStackingSceneView(
                availableColors: availableColors.isEmpty ? [.red] : availableColors,
                spawnInterval: spawnInterval,
                maxDarumaCount: max(8, maxDarumaCount)
            )
        }
    }
}

/// SceneKit bridge that performs the actual physics-based simulation.
struct DarumaStackingSceneView: UIViewRepresentable {
    var availableColors: [DarumaColor]
    var spawnInterval: TimeInterval
    var maxDarumaCount: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(
            configuration: .init(
                availableColors: availableColors,
                spawnInterval: spawnInterval,
                maxDarumaCount: maxDarumaCount
            )
        )
    }

    func makeUIView(context: Context) -> SCNView {
        context.coordinator.makeView()
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateConfiguration(
            .init(
                availableColors: availableColors,
                spawnInterval: spawnInterval,
                maxDarumaCount: maxDarumaCount
            )
        )
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        Task { @MainActor in
            coordinator.stop()
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {
        struct Configuration: Equatable {
            var availableColors: [DarumaColor]
            var spawnInterval: TimeInterval
            var maxDarumaCount: Int
        }

        private let scene: SCNScene = {
            let scene = SCNScene()
            scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
            scene.physicsWorld.speed = 1.0
            scene.lightingEnvironment.contents = StackingLightingEnvironment.shared.image
            scene.lightingEnvironment.intensity = 0.9
            return scene
        }()

        private var configuration: Configuration
        private weak var scnView: SCNView?
        private var spawnTimer: Timer?
        private var displayLink: CADisplayLink?
        private var activeNodes: [SCNNode] = []
        private var modelTemplate: SCNNode?
        private var physicsShape: SCNPhysicsShape?
        private let dropHeight: Float = 1.6
        private var cameraBobTime: CGFloat = 0

        init(configuration: Configuration) {
            self.configuration = configuration
            super.init()
            setupSceneEnvironment()
        }

        func makeView() -> SCNView {
            let view = SCNView(frame: .zero)
            view.scene = scene
            view.backgroundColor = .clear
            view.allowsCameraControl = false
            view.autoenablesDefaultLighting = false
            view.rendersContinuously = true
            view.antialiasingMode = .multisampling4X

            scnView = view
            startSceneIfNeeded()
            return view
        }

        func updateConfiguration(_ configuration: Configuration) {
            guard self.configuration != configuration else { return }
            self.configuration = configuration
            restartSpawnTimer()
            trimActiveNodesIfNeeded()
        }

        // MARK: - Scene Setup

        private func setupSceneEnvironment() {
            configureCamera()
            configureFloor()
            configureLights()
        }

        func stop() {
            spawnTimer?.invalidate()
            spawnTimer = nil
            displayLink?.invalidate()
            displayLink = nil
        }

        private func configureCamera() {
            let cameraNode = SCNNode()
            cameraNode.name = "MainCamera"
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 58
            cameraNode.camera?.wantsHDR = true
            cameraNode.position = SCNVector3(0, 0.4, 2.4)
            cameraNode.eulerAngles = SCNVector3(-0.05, 0, 0)
            scene.rootNode.addChildNode(cameraNode)
        }

        private func configureFloor() {
            let floor = SCNFloor()
            floor.reflectivity = 0.0
            floor.firstMaterial?.diffuse.contents = UIColor(white: 0.96, alpha: 1.0)
            floor.firstMaterial?.isDoubleSided = true
            floor.firstMaterial?.roughness.contents = UIColor(white: 0.2, alpha: 1.0)

            let floorNode = SCNNode(geometry: floor)
            floorNode.name = "DarumaFloor"
            floorNode.physicsBody = {
                let body = SCNPhysicsBody.static()
                body.restitution = 0.02
                body.friction = 1.0
                return body
            }()
            scene.rootNode.addChildNode(floorNode)
        }

        private func configureLights() {
            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 560
            ambient.light?.color = UIColor(white: 0.60, alpha: 1.0)
            scene.rootNode.addChildNode(ambient)

            let directional = SCNNode()
            directional.light = SCNLight()
            directional.light?.type = .directional
            directional.light?.intensity = 340
            directional.light?.castsShadow = false
            directional.light?.color = UIColor(white: 1.0, alpha: 0.48)
            directional.position = SCNVector3(2.4, 3.8, 3.0)
            directional.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(directional)

            let fillLight = SCNNode()
            fillLight.light = SCNLight()
            fillLight.light?.type = .ambient
            fillLight.light?.intensity = 300
            fillLight.light?.color = UIColor(white: 1.0, alpha: 0.1)
            fillLight.position = SCNVector3(-1.2, 0.7, 1.6)
            scene.rootNode.addChildNode(fillLight)
        }

        // MARK: - Loop

        private func startSceneIfNeeded() {
            guard displayLink == nil else { return }
            restartSpawnTimer()
            displayLink = CADisplayLink(target: self, selector: #selector(stepFrame))
            displayLink?.add(to: .main, forMode: .common)
            // Spawn a few darumas instantly so the stack looks alive immediately.
            for _ in 0..<6 {
                spawnDaruma()
            }
        }

        private func restartSpawnTimer() {
            spawnTimer?.invalidate()
            guard configuration.spawnInterval > 0.05 else { return }
            spawnTimer = Timer.scheduledTimer(withTimeInterval: configuration.spawnInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.spawnDaruma()
                }
            }
        }

        @objc private func stepFrame() {
            animateCamera()
            cleanupInactiveNodes()
        }

        private func animateCamera() {
            guard let cameraNode = scene.rootNode.childNode(withName: "MainCamera", recursively: false) else { return }
            cameraBobTime += 0.005
            let bobOffset = sin(cameraBobTime) * 0.02
            cameraNode.position.y = 0.4 + Float(bobOffset)
        }

        // MARK: - Daruma Management

        private func spawnDaruma() {
            guard activeNodes.count < configuration.maxDarumaCount else { return }
            let color = configuration.availableColors.randomElement() ?? .red
            guard let darumaNode = makeDarumaNode(for: color) else { return }

            let spread: Float = 0.5
            let x = Float.random(in: -spread...spread)
            let z = Float.random(in: -0.15...0.15)
            darumaNode.position = SCNVector3(x, dropHeight, z)
            darumaNode.eulerAngles.y = Float.random(in: -Float.pi...Float.pi)
            addPhysics(to: darumaNode)
            scene.rootNode.addChildNode(darumaNode)
            activeNodes.append(darumaNode)
        }

        private func makeDarumaNode(for color: DarumaColor) -> SCNNode? {
            if modelTemplate == nil {
                modelTemplate = loadModelTemplate()
            }
            guard let template = modelTemplate else { return nil }
            let node = template.clone()
            applyMaterial(color: color, to: node)
            return node
        }

        private func addPhysics(to node: SCNNode) {
            if physicsShape == nil, let template = modelTemplate {
                physicsShape = SCNPhysicsShape(node: template, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.convexHull])
            }
            let body = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
            body.mass = 0.36
            body.restitution = 0.05
            body.friction = 0.9
            body.rollingFriction = 0.8
            body.damping = 0.4
            body.angularDamping = 0.6
            node.physicsBody = body
        }

        private func cleanupInactiveNodes() {
            activeNodes.removeAll { node in
                let shouldRemove = node.presentation.position.y < -2.0 || !scene.rootNode.childNodes.contains(node)
                if shouldRemove {
                    node.removeFromParentNode()
                }
                return shouldRemove
            }
            trimActiveNodesIfNeeded()
        }

        private func trimActiveNodesIfNeeded() {
            guard activeNodes.count > configuration.maxDarumaCount else { return }
            let overflow = activeNodes.count - configuration.maxDarumaCount
            let toRemove = activeNodes.prefix(overflow)
            toRemove.forEach { node in
                node.removeFromParentNode()
            }
            activeNodes.removeFirst(overflow)
        }

        // MARK: - Model + Materials

        private func loadModelTemplate() -> SCNNode? {
            guard let url = locateModelURL(),
                  let modelScene = try? SCNScene(url: url, options: nil) else {
                return makeFallbackSphereTemplate()
            }

            let container = SCNNode()
            for child in modelScene.rootNode.childNodes {
                container.addChildNode(child)
            }
            container.eulerAngles.x = -Float.pi / 2

            let (minBounds, maxBounds) = container.boundingBox
            let size = SCNVector3(
                maxBounds.x - minBounds.x,
                maxBounds.y - minBounds.y,
                maxBounds.z - minBounds.z
            )
            let maxDimension = max(size.x, max(size.y, size.z))
            if maxDimension > 0 {
                let targetHeight: Float = 0.32
                let scale = targetHeight / maxDimension
                container.scale = SCNVector3(x: scale, y: scale, z: scale)
            }
            return container
        }

        private func makeFallbackSphereTemplate() -> SCNNode {
            let sphere = SCNSphere(radius: 0.12)
            sphere.segmentCount = 36
            let node = SCNNode(geometry: sphere)
            return node
        }

        private func applyMaterial(color: DarumaColor, to node: SCNNode) {
            let material = makeMaterial(for: color)
            apply(material: material, to: node)
        }

        private func makeMaterial(for color: DarumaColor) -> SCNMaterial {
            let material = SCNMaterial()
            material.isDoubleSided = true
            material.lightingModel = .physicallyBased
            material.roughness.contents = NSNumber(value: 0.78)
            material.metalness.contents = NSNumber(value: 0.08)
            material.diffuse.contents = solidUIColor(for: color)
            material.emission.contents = UIColor.black
            return material
        }

        private func apply(material: SCNMaterial, to node: SCNNode) {
            if let geometry = node.geometry {
                geometry.materials = geometry.materials.isEmpty ? [material] : Array(repeating: material, count: geometry.materials.count)
            }
            for child in node.childNodes {
                apply(material: material, to: child)
            }
        }

        // MARK: - Helpers

        private func locateModelURL() -> URL? {
            if let url = Bundle.main.url(forResource: "Daruma", withExtension: "usdz", subdirectory: "3D") {
                return url
            }
            if let url = Bundle.main.url(forResource: "3D/Daruma", withExtension: "usdz") {
                return url
            }
            return Bundle.main.url(forResource: "Daruma", withExtension: "usdz")
        }

        private func solidUIColor(for color: DarumaColor) -> UIColor {
            if let first = color.gradient.first {
                return UIColor(first)
            }
            return UIColor.white
        }
    }
}

// MARK: - Lighting Environment

@MainActor
private final class StackingLightingEnvironment {
    static let shared = StackingLightingEnvironment()
    let image: UIImage

    private init() {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        image = renderer.image { context in
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(white: 1.0, alpha: 1.0).cgColor,
                    UIColor(white: 0.85, alpha: 1.0).cgColor,
                    UIColor(white: 0.65, alpha: 1.0).cgColor
                ] as CFArray,
                locations: [0, 0.4, 1.0]
            ) else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 3)
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: max(size.width, size.height) / 1.1,
                options: [.drawsAfterEndLocation]
            )
        }
    }
}
