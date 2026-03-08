import SwiftUI
import ARKit
import SceneKit

@MainActor
struct ARViewRepresentable: UIViewRepresentable {
    let color: DarumaColor
    let eyeImage: UIImage?
    let wishImage: UIImage?
    var onPlacementChange: (Bool) -> Void
    var onInvalidPlacementTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            color: color,
            eyeImage: eyeImage,
            wishImage: wishImage,
            onPlacementChange: onPlacementChange,
            onInvalidPlacementTap: onInvalidPlacementTap
        )
    }

    func makeUIView(context: Context) -> ARSCNView {
        context.coordinator.makeView()
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.update(color: color, eyeImage: eyeImage, wishImage: wishImage)
    }

    @MainActor
    final class Coordinator: NSObject, ARSCNViewDelegate {
        private var arView: ARSCNView?
        private var coachingOverlay: ARCoachingOverlayView?
        private var baseNode: SCNNode?
        private var color: DarumaColor
        private var eyeImage: UIImage?
        private var wishImage: UIImage?
        private var currentPlacedNode: SCNNode?
        private var hasLockedPlacement = false
        private let textureProvider = DarumaTextureProvider.shared
        private let onPlacementChange: (Bool) -> Void
        private let onInvalidPlacementTap: () -> Void
        private var wishPlateNode: SCNNode?
        private let wishPlateNodeName = "DarumaWishPlate"

        init(
            color: DarumaColor,
            eyeImage: UIImage?,
            wishImage: UIImage?,
            onPlacementChange: @escaping (Bool) -> Void,
            onInvalidPlacementTap: @escaping () -> Void
        ) {
            self.color = color
            self.eyeImage = eyeImage
            self.wishImage = wishImage
            self.onPlacementChange = onPlacementChange
            self.onInvalidPlacementTap = onInvalidPlacementTap
            super.init()
        }

        func makeView() -> ARSCNView {
            let view = ARSCNView(frame: .zero)
            view.delegate = self
            view.automaticallyUpdatesLighting = true
            view.scene = SCNScene()

            let coachingOverlay = ARCoachingOverlayView()
            coachingOverlay.session = view.session
            coachingOverlay.goal = .horizontalPlane
            coachingOverlay.activatesAutomatically = true
            coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(coachingOverlay)
            NSLayoutConstraint.activate([
                coachingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                coachingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                coachingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
                coachingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            self.coachingOverlay = coachingOverlay

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            view.session.run(configuration)

            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            view.addGestureRecognizer(tapRecognizer)

            arView = view
            loadModelIfNeeded()
            onPlacementChange(false)
            return view
        }

        func update(color: DarumaColor, eyeImage: UIImage?, wishImage: UIImage?) {
            self.color = color
            self.eyeImage = eyeImage
            self.wishImage = wishImage
            applyAppearance()
            updateWishPlateNode()
        }

        private func loadModelIfNeeded() {
            guard baseNode == nil else { return }

            if let url = locateModelURL(),
               let scene = try? SCNScene(url: url, options: nil) {
                let root = SCNNode()
                for child in scene.rootNode.childNodes {
                    root.addChildNode(child)
                }
                root.eulerAngles.x = -.pi / 2
                baseNode = root
                scaleNode(root)
                applyAppearance()
                updateWishPlateNode()
            } else {
                let sphere = SCNSphere(radius: 0.09)
                sphere.firstMaterial = makeMaterial()
                let node = SCNNode(geometry: sphere)
                baseNode = node
            }
        }

        private func scaleNode(_ node: SCNNode) {
            let (minVec, maxVec) = node.boundingBox
            let size = SCNVector3(
                maxVec.x - minVec.x,
                maxVec.y - minVec.y,
                maxVec.z - minVec.z
            )
            let maxDimension = max(size.x, max(size.y, size.z))
            guard maxDimension > 0 else { return }
            let targetSize: Float = 0.18
            let scale = targetSize / maxDimension
            node.scale = SCNVector3(x: scale, y: scale, z: scale)
        }

        private func applyAppearance() {
            guard let baseNode else { return }
            let material = makeMaterial()
            applyMaterialRecursive(node: baseNode, material: material)
        }

        private func applyMaterialRecursive(node: SCNNode, material: SCNMaterial) {
            if node.name == wishPlateNodeName { return }
            if let geometry = node.geometry {
                geometry.materials = geometry.materials.isEmpty ? [material] : Array(repeating: material, count: geometry.materials.count)
            }
            for child in node.childNodes {
                applyMaterialRecursive(node: child, material: material)
            }
        }

        private func makeMaterial() -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.isDoubleSided = true
            material.diffuse.contents = textureProvider.tintedImageWithEye(for: color, eyeImage: eyeImage) ??
                textureProvider.tintedImage(for: color)
            material.roughness.contents = NSNumber(value: 0.82)
            material.metalness.contents = NSNumber(value: 0.04)
            material.emission.contents = UIColor.black
            return material
        }

        private func updateWishPlateNode() {
            wishPlateNode?.removeFromParentNode()
            wishPlateNode = nil
            guard let baseNode, let wishImage else { return }
            guard let plate = DarumaWishPlateFactory.makePlateNode(attachedTo: baseNode, wishImage: wishImage) else { return }
            baseNode.addChildNode(plate)
            wishPlateNode = plate
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            guard !hasLockedPlacement else { return }
            let location = recognizer.location(in: arView)

            // Prefer precise geometry hit, then relax to infinite plane for better usability.
            if let query = arView.raycastQuery(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal),
               let hit = arView.session.raycast(query).first {
                placeDaruma(at: hit.worldTransform)
                return
            }

            if let query = arView.raycastQuery(from: location, allowing: .existingPlaneInfinite, alignment: .horizontal),
               let hit = arView.session.raycast(query).first {
                placeDaruma(at: hit.worldTransform)
                return
            }

            onInvalidPlacementTap()
        }

        private func placeDaruma(at worldTransform: simd_float4x4) {
            guard let arView = arView,
                  let baseNode = baseNode?.clone() else { return }

            currentPlacedNode?.removeFromParentNode()

            let transform = SCNMatrix4(worldTransform)
            baseNode.position = SCNVector3(x: transform.m41, y: transform.m42, z: transform.m43)
            arView.scene.rootNode.addChildNode(baseNode)
            currentPlacedNode = baseNode
            hasLockedPlacement = true
            coachingOverlay?.setActive(false, animated: true)
            coachingOverlay?.isHidden = true
            onPlacementChange(true)
        }

        private func locateModelURL() -> URL? {
            if let url = Bundle.main.url(forResource: "Daruma", withExtension: "usdz", subdirectory: "3D") {
                return url
            }
            if let url = Bundle.main.url(forResource: "3D/Daruma", withExtension: "usdz") {
                return url
            }
            return Bundle.main.url(forResource: "Daruma", withExtension: "usdz")
        }
    }
}
