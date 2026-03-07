import Foundation
import SceneKit
import UIKit

/// Utility that creates a shallow circular plate matching the Daruma's bottom so we can
/// project the handwritten wish onto the exact surface shown in the writing scene.
enum DarumaWishPlateFactory {
    /// - Parameters:
    ///   - baseNode: The Daruma mesh node (already scaled/oriented).
    ///   - wishImage: The captured wish drawing.
    /// - Returns: A node containing a thin cylinder whose bottom face displays the wish.
    static func makePlateNode(attachedTo baseNode: SCNNode, wishImage: UIImage) -> SCNNode? {
        let (minBounds, maxBounds) = baseNode.boundingBox
        let widthExtent = CGFloat(maxBounds.x - minBounds.x)
        let depthExtent = CGFloat(maxBounds.z - minBounds.z)
        let diameter = max(min(widthExtent, depthExtent), 0) * 0.72
        guard diameter > 0 else { return nil }

        let plane = SCNPlane(width: diameter, height: diameter)
        plane.cornerRadius = diameter / 2

        let material = SCNMaterial()
        material.diffuse.contents = wishImage
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = false
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        // Flip vertically so UIKit coordinates (origin at top-left) match the 3D plane orientation.
        var transform = SCNMatrix4MakeScale(1, -1, 1)
        transform.m42 = 1
        material.diffuse.contentsTransform = transform
        plane.firstMaterial = material

        let node = SCNNode(geometry: plane)
        node.name = "DarumaWishPlate"
        node.eulerAngles = SCNVector3(-Float.pi, Float.pi, 0)

        let centerX = (maxBounds.x + minBounds.x) / 2
        let centerZ = (maxBounds.z + minBounds.z) / 2
        let yOffset = minBounds.y - 0.04
        node.position = SCNVector3(centerX, yOffset, centerZ)
        return node
    }
}
