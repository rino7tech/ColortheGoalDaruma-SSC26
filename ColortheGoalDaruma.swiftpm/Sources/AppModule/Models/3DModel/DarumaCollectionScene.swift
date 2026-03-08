import Foundation
import SceneKit
import UIKit

/// だるまコレクションを3Dグリッドで表示するシーン管理クラス
@MainActor
final class DarumaCollectionScene {

    // MARK: - プロパティ

    /// SceneKitシーン
    let scene: SCNScene

    /// カメラノード
    private let cameraNode: SCNNode

    /// だるまノードとIDの対応リスト
    private var darumaEntries: [(node: SCNNode, id: UUID)] = []

    /// レーンノード配列（縞々アニメーション用）
    private var laneNodes: [SCNNode] = []
    /// 紙吹雪エミッターノード
    private var confettiNode: SCNNode?

    /// モデルテンプレート（クローン用）
    private var templateNode: SCNNode?

    // MARK: - グリッド定数

    private let columnCount = 5
    private let colSpacing: Float = 7.6
    private let rowSpacing: Float = 8.2
    private let darumaDesiredSize: Float = 5.8
    private let baseModelXRotation: Float = -.pi / 2
    private let laneGlobalYOffset: Float = -8.25

    // MARK: - カメラ設定

    /// 概観カメラのZ座標（だるま数によって変わる）
    private var overviewCameraZ: Float = 18.0

    /// 概観カメラのY座標（グリッド中心）
    private let overviewCameraY: Float = 0.9

    /// ズームイン時のカメラZ座標（小さいほど大きく見える）
    private let zoomInCameraZ: Float = 5.9

    /// ズームイン時のカメラYオフセット（0で対象を中央に寄せる）
    private let zoomInCameraYOffset: Float = 3.3

    /// だるまグリッド全体のYオフセット（正の値で上げる）
    private let darumaGridYOffset: Float = -2.4

    /// カメラノードへの参照（SCNViewに渡す用）
    var pointOfView: SCNNode { cameraNode }

    // MARK: - 初期化

    init() {
        self.scene = SCNScene()
        self.cameraNode = SCNNode()
        setupCamera()
        setupLighting()
        setupLanes()
        templateNode = loadModelTemplate()
    }

    // MARK: - 公開メソッド

    /// だるまリストをシーンにロードする（既存ノードは全て削除して再作成）
    func loadDarumas(_ darumas: [SavedDaruma]) {
        // 既存のだるまノードを削除
        for entry in darumaEntries {
            entry.node.removeFromParentNode()
        }
        darumaEntries.removeAll()

        guard !darumas.isEmpty else { return }

        let rowCount = Int(ceil(Double(darumas.count) / Double(columnCount)))

        // グリッド全体をY=0中心に配置するためのオフセット計算
        let totalHeight = Float(rowCount - 1) * rowSpacing
        let startY = totalHeight / 2.0

        // だるま行の位置に合わせてレーンを再配置
        setupLanes(rowCount: rowCount, startY: startY)

        for (index, daruma) in darumas.enumerated() {
            let logicalCol = index % columnCount
            let row = index / columnCount
            // 5列は中央→左→右へ広げる順で埋める（見た目の配置列）
            let displayColOrder = [2, 1, 3, 0, 4]
            let col = displayColOrder[logicalCol]

            let xCenterOffset = (Float(columnCount) - 1.0) / 2.0
            let x = (Float(col) - xCenterOffset) * colSpacing
            let y = startY - Float(row) * rowSpacing + darumaGridYOffset

            guard let node = makeDarumaNode(for: daruma) else { continue }
            node.position = SCNVector3(x, y, 0)
            scene.rootNode.addChildNode(node)
            darumaEntries.append((node: node, id: daruma.id))
        }

        // グリッドの横幅/縦幅に応じてカメラ距離を調整（5列でも破綻しないようにする）
        let totalWidth = Float(columnCount - 1) * colSpacing
        let totalHeightForCamera = Float(max(rowCount - 1, 0)) * rowSpacing
        let dominantSpan = max(totalWidth, totalHeightForCamera)
        overviewCameraZ = max(12.0, 9.0 + dominantSpan * 0.55)
    }

    /// カメラを概観位置に設定する（初回表示時に呼ぶ）
    func setupOverviewCamera() {
        cameraNode.position = SCNVector3(0, overviewCameraY, overviewCameraZ)
    }

    /// ヒットテストで指定座標にあるだるまのIDを返す
    func hitTest(point: CGPoint, in view: SCNView) -> UUID? {
        let results = view.hitTest(point, options: [
            .searchMode: SCNHitTestSearchMode.closest.rawValue
        ])
        guard let hitNode = results.first?.node else { return nil }

        for entry in darumaEntries {
            if hitNode === entry.node || isDescendant(node: hitNode, of: entry.node) {
                return entry.id
            }
        }
        return nil
    }

    /// 指定IDのだるまにカメラをズームインする
    func zoomIn(toID id: UUID, completion: @escaping () -> Void) {
        guard let entry = darumaEntries.first(where: { $0.id == id }) else {
            completion()
            return
        }

        let target = entry.node.position
        let targetPosition = SCNVector3(
            target.x,
            target.y + zoomInCameraYOffset,
            zoomInCameraZ
        )

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.6
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.position = targetPosition
        SCNTransaction.completionBlock = { completion() }
        SCNTransaction.commit()
    }

    /// 指定IDのだるまを任意のカメラ距離でフォーカスする（達成画面向け）
    func focusOnDaruma(toID id: UUID, cameraZ: Float, cameraYOffset: Float, animated: Bool = true) {
        guard let entry = darumaEntries.first(where: { $0.id == id }) else { return }

        let target = entry.node.position
        let targetPosition = SCNVector3(
            target.x,
            target.y + cameraYOffset,
            cameraZ
        )

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.45 : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.position = targetPosition
        SCNTransaction.commit()
    }

    /// カメラを概観位置にズームアウトする
    func zoomOut(completion: (() -> Void)? = nil) {
        let targetPosition = SCNVector3(0, overviewCameraY, overviewCameraZ)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.6
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.position = targetPosition
        SCNTransaction.completionBlock = { completion?() }
        SCNTransaction.commit()
    }

    /// 紙吹雪を開始（達成画面向け）
    func startConfetti() {
        confettiNode?.removeFromParentNode()

        let emitter = SCNParticleSystem()
        emitter.loops = true
        emitter.birthRate = 64
        emitter.warmupDuration = 1.1
        emitter.birthDirection = .random
        emitter.particleLifeSpan = 20
        emitter.particleVelocity = 10
        emitter.particleVelocityVariation = 4
        emitter.acceleration = SCNVector3(0, -20, 0)
        emitter.particleAngularVelocity = 300
        emitter.emitterShape = SCNBox(width: 42, height: 0, length: 6, chamferRadius: 0)
        emitter.particleColor = .red
        emitter.particleSize = 0.18
        emitter.particleSizeVariation = 0.06
        emitter.particleColorVariation = .init(x: 180, y: 0.1, z: 0.1, w: 0)
        emitter.imageSequenceAnimationMode = .repeat
        emitter.orientationMode = .free
        emitter.blendMode = .alpha
        emitter.sortingMode = .distance
        emitter.isAffectedByGravity = true
        emitter.particleBounce = 0.7
        emitter.dampingFactor = 5

        let node = SCNNode()
        // だるまより奥かつ上から降るように配置
        node.position = SCNVector3(0, 22, -14)
        node.addParticleSystem(emitter)

        // 開始直後だけ速く見せるためのバースト（短時間）
        let burst = SCNParticleSystem()
        burst.loops = false
        burst.emissionDuration = 0.45
        burst.birthRate = 180
        burst.birthDirection = .random
        burst.particleLifeSpan = 6
        burst.particleLifeSpanVariation = 1.2
        burst.particleVelocity = 26
        burst.particleVelocityVariation = 10
        burst.acceleration = SCNVector3(0, -46, 0)
        burst.particleAngularVelocity = 340
        burst.emitterShape = SCNBox(width: 46, height: 0, length: 6, chamferRadius: 0)
        burst.particleColor = .red
        burst.particleSize = 0.2
        burst.particleSizeVariation = 0.08
        burst.particleColorVariation = .init(x: 180, y: 0.1, z: 0.1, w: 0)
        burst.imageSequenceAnimationMode = .repeat
        burst.orientationMode = .free
        burst.blendMode = .alpha
        burst.sortingMode = .distance
        burst.isAffectedByGravity = true
        burst.particleBounce = 0.7
        burst.dampingFactor = 5
        node.addParticleSystem(burst)

        scene.rootNode.addChildNode(node)
        confettiNode = node
    }

    // MARK: - レーン

    /// 縞々レーンを設定する（だるま配置に追従）
    private func setupLanes(rowCount: Int = 3, startY: Float = 0) {
        for laneNode in laneNodes {
            laneNode.removeFromParentNode()
        }
        laneNodes.removeAll()

        let laneCount = max(7, rowCount + 2)
        let topRowY = startY + darumaGridYOffset
        let bottomRowY = startY - Float(max(rowCount - 1, 0)) * rowSpacing + darumaGridYOffset
        let centerY = (topRowY + bottomRowY) * 0.5
        let laneStep = rowSpacing
        let laneWidth = max(150.0, Float(columnCount - 1) * colSpacing + 20.0)

        for index in 0..<laneCount {
            let offset = Float(index) - Float(laneCount - 1) * 0.5
            let laneY = centerY + offset * laneStep
            let laneGeometry = SCNBox(width: CGFloat(laneWidth), height: 0.1, length: 2, chamferRadius: 0)
            let material = SCNMaterial()
            material.diffuse.contents = createStripedTexture()
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.diffuse.contentsTransform = SCNMatrix4MakeScale(max(18, laneWidth / 4.0), 1, 1)
            laneGeometry.materials = [material]

            let laneNode = SCNNode(geometry: laneGeometry)
            laneNode.name = "Lane\(index)"
            laneNode.position = SCNVector3(0, laneY + laneGlobalYOffset, -1)
            scene.rootNode.addChildNode(laneNode)
            laneNodes.append(laneNode)
        }
    }

    /// 縞々テクスチャを生成（DarumaRainSceneと同じ実装）
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

    // MARK: - プライベートメソッド

    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        cameraNode.position = SCNVector3(0, 0, 18)
        cameraNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupLighting() {
        // アンビエントライト
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 580
        ambientLight.light?.color = UIColor(white: 0.64, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        // ディレクショナルライト
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 300
        directionalLight.light?.castsShadow = false
        directionalLight.light?.color = UIColor(white: 1.0, alpha: 0.48)
        directionalLight.position = SCNVector3(2.8, 3.8, 4.2)
        directionalLight.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(directionalLight)

        // 補助ライト
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .ambient
        fillLight.light?.intensity = 320
        fillLight.light?.color = UIColor(white: 1.0, alpha: 0.1)
        fillLight.position = SCNVector3(-2, 3, 2)
        scene.rootNode.addChildNode(fillLight)
    }

    /// USDZモデルをロードしてテンプレートノードを作成する
    private func loadModelTemplate() -> SCNNode? {
        guard let url = locateModelURL(),
              let modelScene = try? SCNScene(url: url, options: nil) else {
            return makeFallbackTemplate()
        }

        let container = SCNNode()
        for child in modelScene.rootNode.childNodes {
            container.addChildNode(child)
        }
        container.eulerAngles.x = baseModelXRotation
        configureGeometrySmoothing(for: container)

        // 目標サイズに合わせてスケーリング
        let (minBounds, maxBounds) = container.boundingBox
        let size = SCNVector3(
            maxBounds.x - minBounds.x,
            maxBounds.y - minBounds.y,
            maxBounds.z - minBounds.z
        )
        let maxDimension = max(size.x, max(size.y, size.z))
        if maxDimension > 0 {
            let scale: Float = darumaDesiredSize / maxDimension
            container.scale = SCNVector3(scale, scale, scale)
        }
        alignModelBottom(container)

        return container
    }

    /// モデルロード失敗時のフォールバック（球体）
    private func makeFallbackTemplate() -> SCNNode {
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 24
        let node = SCNNode(geometry: sphere)
        alignModelBottom(node)
        return node
    }

    /// SavedDarumaからSCNNodeを生成する
    private func makeDarumaNode(for daruma: SavedDaruma) -> SCNNode? {
        guard let template = templateNode else { return nil }

        let node = template.clone()
        makeGeometryUnique(for: node)

        // 両目テクスチャを生成（なければカラーテクスチャのみ）
        let texture = DarumaTextureProvider.shared.tintedImageWithBothEyes(
            for: daruma.darumaColor,
            leftEyeImage: daruma.leftEyeImage,
            rightEyeImage: daruma.rightEyeImage
        ) ?? DarumaTextureProvider.shared.tintedImage(for: daruma.darumaColor)

        applyTexture(texture, to: node)
        node.name = daruma.id.uuidString
        return node
    }

    /// ノードにテクスチャを再帰的に適用する
    private func applyTexture(_ texture: UIImage?, to node: SCNNode) {
        guard let texture else { return }
        if let geometry = node.geometry {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.isDoubleSided = true
            material.diffuse.contents = texture
            material.diffuse.minificationFilter = .linear
            material.diffuse.magnificationFilter = .linear
            material.diffuse.mipFilter = .linear
            material.roughness.contents = NSNumber(value: 0.82)
            material.metalness.contents = NSNumber(value: 0.04)
            let count = max(geometry.materials.count, 1)
            geometry.materials = Array(repeating: material, count: count)
        }
        for child in node.childNodes {
            applyTexture(texture, to: child)
        }
    }

    /// 指定ノードが ancestor の子孫かどうかを判定する
    private func isDescendant(node: SCNNode, of ancestor: SCNNode) -> Bool {
        var current: SCNNode? = node.parent
        while let parent = current {
            if parent === ancestor { return true }
            current = parent.parent
        }
        return false
    }

    /// モデルのURLを探索する
    private func locateModelURL() -> URL? {
        if let url = Bundle.main.url(forResource: "Daruma", withExtension: "usdz", subdirectory: "3D") {
            return url
        }
        if let url = Bundle.main.url(forResource: "3D/Daruma", withExtension: "usdz") {
            return url
        }
        return Bundle.main.url(forResource: "Daruma", withExtension: "usdz")
    }

    /// クローンしたノードのジオメトリを個別コピーにする（マテリアル共有を防ぐ）
    private func makeGeometryUnique(for node: SCNNode) {
        if let geometry = node.geometry {
            node.geometry = geometry.copy() as? SCNGeometry
        }
        for child in node.childNodes {
            makeGeometryUnique(for: child)
        }
    }

    /// ジオメトリの滑らかさを設定（コレクション表示のギザつき軽減）
    private func configureGeometrySmoothing(for node: SCNNode) {
        if let geometry = node.geometry {
            geometry.subdivisionLevel = 1
            geometry.wantsAdaptiveSubdivision = true
        }
        for child in node.childNodes {
            configureGeometrySmoothing(for: child)
        }
    }

    /// モデルの底面がY=0になるよう子ノードをオフセットする
    private func alignModelBottom(_ node: SCNNode) {
        let (minBounds, _) = node.boundingBox
        guard minBounds.y != 0 else { return }
        let offset = -minBounds.y
        for child in node.childNodes {
            child.position.y += offset
        }
    }
}
