import SwiftUI
import SceneKit
import UIKit

/// SCNViewをSwiftUIでラップするUIViewRepresentable
struct DarumaCollectionSceneView: UIViewRepresentable {

    let scene: DarumaCollectionScene
    var onTap: (UUID?) -> Void

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene.scene
        scnView.pointOfView = scene.pointOfView
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = false
        scnView.isPlaying = true
        scnView.autoenablesDefaultLighting = false

        // タップジェスチャーを追加
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        scnView.addGestureRecognizer(tap)
        context.coordinator.sceneView = scnView

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scene: scene, onTap: onTap)
    }

    // MARK: - Coordinator

    /// タップジェスチャーを処理するコーディネーター
    @MainActor
    final class Coordinator: NSObject {
        let scene: DarumaCollectionScene
        var onTap: (UUID?) -> Void
        weak var sceneView: SCNView?

        init(scene: DarumaCollectionScene, onTap: @escaping (UUID?) -> Void) {
            self.scene = scene
            self.onTap = onTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = sceneView else { return }
            let point = gesture.location(in: scnView)
            if let id = scene.hitTest(point: point, in: scnView) {
                onTap(id)
                return
            }
            onTap(nil)
        }
    }
}
