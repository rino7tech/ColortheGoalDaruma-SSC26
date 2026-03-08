import Foundation
import SceneKit
import UIKit

/// ChatView背景用のレーンのみシーン
@MainActor
final class ChatLaneBackgroundScene {
    let scene: SCNScene
    private let cameraNode: SCNNode
    private var laneNode: SCNNode?

    private let laneY: Float = -7.5
    
    private let laneHeight: Float = 0.1
    private let laneWidth: Float = 200.0
    private let laneTextureRepeatX: Float = 50.0
    private let laneTextureScrollSpeed: Float = 0.9

    var pointOfView: SCNNode { cameraNode }

    init() {
        self.scene = SCNScene()
        self.cameraNode = SCNNode()
        setupCamera()
        setupLighting()
        setupLane()
    }

    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        cameraNode.position = SCNVector3(0, 0.5, 20)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupLighting() {
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500
        ambientLight.light?.color = UIColor(white: 0.7, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
    }

    private func setupLane() {
        let laneGeometry = SCNBox(width: CGFloat(laneWidth), height: CGFloat(laneHeight), length: 2, chamferRadius: 0)
        let laneMaterial = SCNMaterial()
        laneMaterial.diffuse.contents = createStripedTexture()
        laneMaterial.diffuse.wrapS = .repeat
        laneMaterial.diffuse.wrapT = .repeat
        laneMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(laneTextureRepeatX, 1, 1)
        laneGeometry.materials = [laneMaterial]

        let lane = SCNNode(geometry: laneGeometry)
        lane.name = "BackgroundLane"
        lane.position = SCNVector3(0, laneY, 0)
        scene.rootNode.addChildNode(lane)
        laneNode = lane
    }

    private func createStripedTexture() -> UIImage {
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let stripeWidth: CGFloat = 32
            UIColor.customRed.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: stripeWidth, height: size.height))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: stripeWidth, y: 0, width: stripeWidth, height: size.height))
        }
    }

    func updateLaneAnimation(deltaTime: TimeInterval, scrollSpeed: Float) {
        guard let lane = laneNode, let material = lane.geometry?.firstMaterial else { return }
        var transform = material.diffuse.contentsTransform
        let speed = scrollSpeed == 0 ? 0 : scrollSpeed
        transform.m41 += speed * Float(deltaTime)
        material.diffuse.contentsTransform = transform
    }
}
