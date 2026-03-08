import Foundation
import SceneKit
import UIKit

/// ChatView用のレーンベースだるまシーン管理クラス
@MainActor
final class ChatLaneDarumaScene {
    // MARK: - プロパティ

    /// SceneKitシーン
    let scene: SCNScene

    /// 現在表示中のだるまノード
    private var currentDarumaNode: SCNNode?

    /// レーンノード
    private var laneNode: SCNNode?

    /// カメラノード
    private let cameraNode: SCNNode

    /// モデルテンプレート（クローン用）
    private var modelTemplate: SCNNode?

    /// テンプレートのバウンディング（高さ算出用）
    private var modelBounds: (min: SCNVector3, max: SCNVector3)?

    /// ベーステクスチャ
    private var baseTexture: UIImage?

    /// モデルのベース回転（USDZが下向きのため）
    private let baseModelXRotation: Float = -.pi / 2

    /// レーンのY座標
    private let laneY: Float = -2.0

    /// レーンの高さ
    private let laneHeight: Float = 0.1

    /// レーンの幅
    private let laneWidth: Float = 200.0

    /// だるまをレーン上に少し持ち上げるオフセット
    private let darumaBaseYOffset: Float = -1.8

    /// ロード中の上下ふわふわ量
    private let loadingFloatAmplitude: Float = 0.25

    /// ロード中の上下ふわふわ周期
    private let loadingFloatDuration: TimeInterval = 0.8

    /// レーンテクスチャの繰り返し数（X方向）
    private let laneTextureRepeatX: Float = 50.0

    /// だるまの中央X座標
    private let darumaCenterX: Float = -6.8

    /// トランジション中フラグ
    private var isTransitioning: Bool = false

    /// レーンアニメーション中フラグ
    private var isLaneAnimating: Bool = false

    /// トランジション時間
    private let transitionDuration: TimeInterval = 0.8

    /// レーンのスクロール速度（UV空間）
    private var laneScrollSpeed: Float {
        let travelDistance = laneWidth / 2 + 20
        let darumaWorldSpeed = travelDistance / Float(transitionDuration)
        return darumaWorldSpeed * (laneTextureRepeatX / laneWidth)
    }

    /// トランジション時間（ChatView側の同期用）
    var transitionDurationValue: TimeInterval {
        transitionDuration
    }

    /// 同期されたレーンテクスチャスクロール速度（UV空間）
    /// トランジション時にだるまの移動速度に合わせて計算される
    private var syncedLaneTextureScrollSpeed: Float = 0.0

    /// 背景レーン用の現在速度
    var currentLaneScrollSpeed: Float {
        isLaneAnimating ? syncedLaneTextureScrollSpeed : 0.0
    }

    /// 色ごとのマテリアルキャッシュ
    private var materialCache: [String: SCNMaterial] = [:]

    /// 色ごとのティントテクスチャキャッシュ
    private var tintedTextureCache: [String: UIImage] = [:]

    // MARK: - 初期化

    /// シーンで使用する視点
    var pointOfView: SCNNode {
        cameraNode
    }

    init() {
        self.scene = SCNScene()
        self.cameraNode = SCNNode()

        // テクスチャをロード
        baseTexture = loadTexture()

        // 環境設定
        setupCamera()
        setupLighting()
        // 背景レーンはChatView側で描画するため、ここでは生成しない

        // モデルテンプレートを準備
        modelTemplate = loadModelTemplate()
    }

    // MARK: - テクスチャ

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

    // MARK: - 環境設定

    /// カメラ設定
    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        cameraNode.position = SCNVector3(0, 0.5, 20)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }

    /// ライティング設定
    private func setupLighting() {
        // アンビエントライト
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 620
        ambientLight.light?.color = UIColor(white: 0.66, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 320
        directionalLight.light?.castsShadow = false
        directionalLight.light?.color = UIColor(white: 1.0, alpha: 0.5)
        directionalLight.position = SCNVector3(2.4, 3.6, 3.8)
        directionalLight.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(directionalLight)

        // やわらかい補助光
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .ambient
        fillLight.light?.intensity = 350
        fillLight.light?.color = UIColor(white: 1.0, alpha: 0.12)
        fillLight.position = SCNVector3(-2, 3, 2)
        scene.rootNode.addChildNode(fillLight)
    }

    /// レーンを設定
    private func setupLane() {
        let laneGeometry = SCNBox(width: CGFloat(laneWidth), height: CGFloat(laneHeight), length: 2, chamferRadius: 0)
        let laneMaterial = SCNMaterial()

        // 縞々テクスチャを生成
        laneMaterial.diffuse.contents = createStripedTexture()
        laneMaterial.diffuse.wrapS = .repeat
        laneMaterial.diffuse.wrapT = .repeat
        laneMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(laneTextureRepeatX, 1, 1)

        laneGeometry.materials = [laneMaterial]

        let lane = SCNNode(geometry: laneGeometry)
        lane.name = "Lane"
        lane.position = SCNVector3(0, laneY, 0)
        scene.rootNode.addChildNode(lane)
        laneNode = lane
    }

    /// 縞々テクスチャを生成
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

    // MARK: - だるま管理

    /// 初期だるまを設定
    func setupInitialDaruma(color: DarumaColor) {
        guard currentDarumaNode == nil else { return }
        currentDarumaNode = createDarumaNode(color: color)
        if let daruma = currentDarumaNode {
            daruma.position = SCNVector3(darumaCenterX, darumaY, 0)
            scene.rootNode.addChildNode(daruma)
        }
    }

    /// だるまの色を更新（即座に変更）
    func updateDarumaColor(_ color: DarumaColor) {
        guard let daruma = currentDarumaNode else { return }
        applyMaterial(to: daruma, color: color)
    }

    /// トランジションを実行（新しいだるまが流れてくる）
    func performTransition(to newColor: DarumaColor, completion: (@Sendable () -> Void)? = nil) {
        guard !isTransitioning else { return }
        isTransitioning = true
        isLaneAnimating = true

        let oldDaruma = currentDarumaNode

        // 新しいだるまを作成（画面右外から開始）
        let newDaruma = createDarumaNode(color: newColor)
        let startX: Float = darumaCenterX + laneWidth / 2 + 20
        newDaruma.position = SCNVector3(startX, darumaY, 0)
        scene.rootNode.addChildNode(newDaruma)
        currentDarumaNode = newDaruma

        // レーンテクスチャのスクロール速度をだるまの移動速度に同期
        // UV速度 = ワールド速度 × (テクスチャ繰り返し数 / レーン幅)
        syncedLaneTextureScrollSpeed = laneScrollSpeed

        // 古いだるまを左へ流す
        let endXOld: Float = darumaCenterX - laneWidth / 2 - 20
        let moveOutAction = SCNAction.move(to: SCNVector3(endXOld, darumaY, 0), duration: transitionDuration)
        moveOutAction.timingMode = .linear

        let removeAction = SCNAction.removeFromParentNode()
        oldDaruma?.runAction(SCNAction.sequence([moveOutAction, removeAction]))

        // 新しいだるまを中央へ流す
        let moveInAction = SCNAction.move(to: SCNVector3(darumaCenterX, darumaY, 0), duration: transitionDuration)
        moveInAction.timingMode = .linear

        newDaruma.runAction(moveInAction)
        DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration) { [weak self] in
            self?.isTransitioning = false
            self?.isLaneAnimating = false
            self?.syncedLaneTextureScrollSpeed = 0.0
            completion?()
        }
    }

    /// だるまノードを作成
    private func createDarumaNode(color: DarumaColor) -> SCNNode {
        guard let template = modelTemplate else {
            return makeFallbackDaruma(color: color)
        }

        let darumaNode = template.clone()
        darumaNode.name = "ChatDaruma"
        makeGeometryUnique(for: darumaNode)
        applyMaterial(to: darumaNode, color: color)
        alignRotationPivot(for: darumaNode)

        return darumaNode
    }

    /// フォールバック用の球体だるま
    private func makeFallbackDaruma(color: DarumaColor) -> SCNNode {
        let sphere = SCNSphere(radius: 0.8)
        let material = makeSceneKitMaterial(color: color)
        sphere.materials = [material]
        let node = SCNNode(geometry: sphere)
        return node
    }

    /// モデルテンプレートをロード
    private func loadModelTemplate() -> SCNNode? {
        guard let url = locateModelURL(),
              let modelScene = try? SCNScene(url: url, options: nil) else {
            return nil
        }

        let container = SCNNode()
        for child in modelScene.rootNode.childNodes {
            container.addChildNode(child)
        }
        container.eulerAngles.x = baseModelXRotation
        configureGeometrySmoothing(for: container)

        // スケーリング
        let (minBounds, maxBounds) = container.boundingBox
        let size = SCNVector3(
            maxBounds.x - minBounds.x,
            maxBounds.y - minBounds.y,
            maxBounds.z - minBounds.z
        )
        let maxDimension = max(size.x, max(size.y, size.z))
        if maxDimension > 0 {
            let baseScale: Float = 8.0 / maxDimension
            container.scale = SCNVector3(baseScale, baseScale, baseScale)
        }
        alignModelCenter(container)
        modelBounds = container.boundingBox

        return container
    }

    // MARK: - レーンアニメーション

    /// レーンのテクスチャアニメーションを更新
    func updateLaneAnimation(deltaTime: TimeInterval) {
        guard isLaneAnimating, let lane = laneNode else { return }
        guard let material = lane.geometry?.firstMaterial else { return }

        var transform = material.diffuse.contentsTransform
        // 同期された速度を使用
        transform.m41 += syncedLaneTextureScrollSpeed * Float(deltaTime)
        material.diffuse.contentsTransform = transform
    }

    // MARK: - 手動回転

    /// だるまの手動回転を適用
    func applyManualRotation(rotationY: Float) {
        currentDarumaNode?.eulerAngles.y = rotationY
    }

    // MARK: - ロード中アニメーション

    /// ロード中回転アニメーションのキー
    private static let loadingAnimationKey = "loadingSpinJump"

    /// ロード中フラグ
    private var isLoadingAnimating: Bool = false

    /// ロード中かどうかを取得
    var isInLoadingAnimation: Bool {
        isLoadingAnimating
    }

    /// ロード中アニメーションを開始（イージング付き360度回転）
    func startLoadingAnimation() {
        guard let daruma = currentDarumaNode else { return }

        // 既にアニメーション中ならスキップ
        guard daruma.action(forKey: Self.loadingAnimationKey) == nil else { return }

        isLoadingAnimating = true

        // DarumaRainViewと同じ回転＋ジャンプ
        let spinDuration: TimeInterval = 0.9
        let rotateAction = SCNAction.rotateBy(x: 0, y: .pi * 4, z: 0, duration: spinDuration)
        rotateAction.timingMode = .easeOut

        let jumpUp = SCNAction.moveBy(x: 0, y: 0.6, z: 0, duration: 0.3)
        jumpUp.timingMode = .easeOut
        let jumpDown = SCNAction.moveBy(x: 0, y: -0.6, z: 0, duration: 0.3)
        jumpDown.timingMode = .easeIn
        let jump = SCNAction.sequence([jumpUp, jumpDown])

        let group = SCNAction.group([rotateAction, jump])
        let pause = SCNAction.wait(duration: 0.3)
        let repeatAction = SCNAction.repeatForever(SCNAction.sequence([group, pause]))
        daruma.runAction(repeatAction, forKey: Self.loadingAnimationKey)
    }

    /// ロード中アニメーションを停止
    func stopLoadingAnimation() {
        isLoadingAnimating = false
        guard let daruma = currentDarumaNode else { return }
        daruma.removeAction(forKey: Self.loadingAnimationKey)

        // 回転をリセット（滑らかに戻す）
        let resetAction = SCNAction.rotateTo(
            x: CGFloat(baseModelXRotation),
            y: 0,
            z: 0,
            duration: 0.3
        )
        resetAction.timingMode = .easeOut
        daruma.runAction(resetAction)
    }

    // MARK: - マテリアル

    /// マテリアルを作成
    private func makeSceneKitMaterial(color: DarumaColor) -> SCNMaterial {
        let cacheKey = color.rawValue
        if let cached = materialCache[cacheKey] {
            return cached.copy() as? SCNMaterial ?? cached
        }

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.isDoubleSided = true
        material.transparency = 1.0
        material.transparencyMode = .aOne
        material.blendMode = .replace
        material.writesToDepthBuffer = true
        material.readsFromDepthBuffer = true

        if let tintedImage = createTintedTexture(with: color) {
            material.diffuse.contents = tintedImage
        } else {
            let uiColor = UIColor(color.gradient[0])
            material.diffuse.contents = uiColor
        }

        material.roughness.contents = NSNumber(value: 0.82)
        material.metalness.contents = NSNumber(value: 0.04)
        material.emission.contents = UIColor.black

        materialCache[cacheKey] = material

        return material.copy() as? SCNMaterial ?? material
    }

    /// テクスチャに色を合成した画像を作成
    private func createTintedTexture(with color: DarumaColor) -> UIImage? {
        guard let texture = baseTexture else { return nil }

        let cacheKey = color.rawValue
        if let cached = tintedTextureCache[cacheKey] {
            return cached
        }

        let uiColor = UIColor(color.gradient[0])
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: texture.size, format: format)

        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: texture.size)
            UIColor.white.setFill()
            ctx.fill(rect)
            uiColor.setFill()
            ctx.fill(rect)
            texture.draw(in: rect)
        }

        tintedTextureCache[cacheKey] = image

        return image
    }

    /// ノードにマテリアルを再帰的に適用
    private func applyMaterial(to node: SCNNode, color: DarumaColor) {
        if let geometry = node.geometry {
            let material = makeSceneKitMaterial(color: color)
            geometry.materials = geometry.materials.isEmpty ? [material] : Array(repeating: material, count: geometry.materials.count)
        }
        for child in node.childNodes {
            applyMaterial(to: child, color: color)
        }
    }

    // MARK: - ヘルパー

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

    /// クローンしたノード間でジオメトリを共有しないようコピーを作成
    private func makeGeometryUnique(for node: SCNNode) {
        if let geometry = node.geometry {
            node.geometry = geometry.copy() as? SCNGeometry
        }
        for child in node.childNodes {
            makeGeometryUnique(for: child)
        }
    }

    /// ジオメトリの滑らかさを設定
    /// スムースシェーディングを適用し、適切なサブディビジョンレベルを設定
    private func configureGeometrySmoothing(for node: SCNNode) {
        if let geometry = node.geometry {
            // サブディビジョンでポリゴンを細かくしてシルエットを滑らかに
            geometry.subdivisionLevel = 2
            geometry.wantsAdaptiveSubdivision = true

            // マテリアルにスムースシェーディングを適用
            for material in geometry.materials {
                material.fillMode = .fill
                material.isDoubleSided = true
                material.lightingModel = .physicallyBased
                material.roughness.contents = 0.82
                material.metalness.contents = 0.04
            }
        }
        for child in node.childNodes {
            configureGeometrySmoothing(for: child)
        }
    }

    /// モデルの中心がノードの原点になるよう子ノードをオフセット
    /// X/Z方向は中心を原点に、Y方向は底面を原点に（レーンに乗せるため）
    private func alignModelCenter(_ node: SCNNode) {
        let (minBounds, maxBounds) = node.boundingBox

        // X/Z方向は中心を原点に
        let centerX = (minBounds.x + maxBounds.x) / 2
        let centerZ = (minBounds.z + maxBounds.z) / 2

        // Y方向は底面を原点に（レーンに乗せるため）
        let offsetY = -minBounds.y

        for child in node.childNodes {
            child.position.x -= centerX
            child.position.y += offsetY
            child.position.z -= centerZ
        }
    }

    /// 回転軸がモデルの中心を通るようにX/Zのピボットを調整
    private func alignRotationPivot(for node: SCNNode) {
        let bounds = modelBounds ?? node.boundingBox
        let centerX = (bounds.min.x + bounds.max.x) / 2
        let centerY = (bounds.min.y + bounds.max.y) / 2
        let centerZ = (bounds.min.z + bounds.max.z) / 2
        node.pivot = SCNMatrix4MakeTranslation(centerX, centerY, centerZ)
    }

    /// レーンの上に乗せたY座標
    private var darumaY: Float {
        laneY + laneHeight / 2 + darumaHalfHeight + darumaBaseYOffset
    }

    /// だるまの半分の高さ
    private var darumaHalfHeight: Float {
        let bounds = modelBounds ?? (min: SCNVector3(-0.8, -0.8, -0.8), max: SCNVector3(0.8, 0.8, 0.8))
        let height = bounds.max.y - bounds.min.y
        return max(0.1, height / 2)
    }
}
