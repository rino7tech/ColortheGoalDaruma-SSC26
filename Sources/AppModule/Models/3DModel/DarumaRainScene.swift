import Foundation
import SceneKit
import UIKit

/// ダルマ降下エフェクトのSceneKit Scene管理クラス
final class DarumaRainScene {
    // MARK: - プロパティ

    /// SceneKitシーン
    let scene: SCNScene

    /// 中央の固定ダルマ
    var centerDarumaNode: SCNNode

    /// 降下中のダルマノード配列
    private var activeRainNodes: [SCNNode] = []

    /// 静止状態のダルマノード配列（染まり完了まで静止）
    private var staticDarumaNodes: [PrefilledDaruma] = []

    private struct PrefilledDaruma {
        let node: SCNNode
        let laneIndex: Int
    }

    /// レーンノード配列（縞々アニメーション用）
    private var laneNodes: [SCNNode] = []

    /// モデルテンプレート（クローン用）
    private var modelTemplate: SCNNode?

    /// ベーステクスチャ
    private var baseTexture: UIImage?

    /// カメラノード
    private let cameraNode: SCNNode

    /// モデルのベース回転（USDZが下向きのため）
    private let baseModelXRotation: Float = -.pi / 2

    /// 床のY座標（中央ダルマの足元）
    private let groundY: Float = -10.0

    /// レーンのY座標（3本）
    private let laneYPositions: [Float]

    /// レーンごとの生成間隔（秒）- 広めの間隔で生成
    private let spawnInterval: TimeInterval = 1.2

    /// 最初の生成までの遅延（0でカメラズームと同時に開始）
    private let initialSpawnDelay: TimeInterval = 0.0

    /// レーンごとの生成タイミングのずれ（スタート時間を少しずつずらす）
    private let laneSpawnStagger: TimeInterval = 0.15

    /// 最大同時存在数
    let maxDarumaCount: Int = 220

    /// 降下ダルマの色バリエーション
    let rainColors: [UIColor] = [
        UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0),  // 赤
        UIColor(red: 0.1, green: 0.5, blue: 0.8, alpha: 1.0),  // 青
        UIColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1.0),  // 金
        UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),  // 白
        UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0),  // 緑
        UIColor(red: 0.9, green: 0.3, blue: 0.7, alpha: 1.0),  // ピンク
    ]

    /// 色ごとのマテリアルキャッシュ（降下ダルマ用）
    private var materialCache: [String: SCNMaterial] = [:]

    /// 色ごとのティントテクスチャキャッシュ
    private var tintedTextureCache: [String: UIImage] = [:]

    /// 色ごとのテンプレートキャッシュ（ジオメトリ共有で負荷軽減）
    private var coloredTemplateCache: [String: SCNNode] = [:]

    /// レーンごとの生成タイマー（継続生成用）
    private var laneSpawnTimers: [TimeInterval] = []

    /// 中央ダルマの開始色（白）
    private let centerStartColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)

    /// 中央ダルマの終了色（赤）
    private let centerEndColor = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0)

    /// 中央だるまの流れ出し開始済みフラグ
    private var hasCenterDarumaStartedMoving: Bool = false
    /// 中央だるまの回転＆色変化開始済みフラグ
    private var hasCenterDarumaSpinStarted: Bool = false
    /// 中央だるま回転中フラグ（演出用）
    private(set) var isCenterDarumaSpinning: Bool = false
    /// 中央だるま用の段階的ティントテクスチャ
    private var centerDarumaTintedSequence: [UIImage] = []

    /// 中央だるまが画面外に消えたかどうか
    var hasCenterDarumaDisappeared: Bool = false

    /// カメラが引き終わったかどうか
    var hasCameraZoomOutCompleted: Bool = false

    /// 中央ダルマ用のカスタムマテリアル
    private var centerDarumaMaterials: [SCNMaterial] = []

    /// 中央ダルマの高さ
    private var centerDarumaHeight: Float = 1.0

    /// 中央ダルマの最小Y（ルート座標系）
    private var centerDarumaMinY: Float = 0.0

    /// 中央ダルマの最大Y（ルート座標系）
    private var centerDarumaMaxY: Float = 1.0


    /// カメラの最終位置（引いた後）- さらに引き気味に
    private let cameraFinalZ: Float = 26.0

    /// カメラの初期位置（近い位置）
    private let cameraInitialZ: Float = 8.0

    /// 中央からどれだけ右側（画面外）に離してスポーンさせるか
    private let spawnStartOffsetFromCenter: Float = 10.0

    /// 画面外に飛び出すための追加マージン
    private let spawnOffscreenMargin: Float = 5.0

    /// スポーン位置の基準となる中央ダルマの初期X座標
    private var spawnAnchorX: Float = 0.0

    /// 初期ウェーブの最大数（1レーンあたり）
    private let initialSpawnCapPerLane: Int = 28

    /// 静止配置で許可する最大進行度（ほぼ全域をカバー）
    private let staticPrefillMaxProgress: Float = 0.95

    /// 初期ウェーブであらかじめ進めておく割合
    private lazy var initialSpawnProgresses: [Float] = {
        let travelDuration = Double(laneWidth / beltWorldSpeed)
        return DarumaRainScene.makeInitialProgresses(
            travelDuration: travelDuration,
            spawnInterval: spawnInterval,
            cap: initialSpawnCapPerLane
        )
    }()

    /// ズームアウト後もレーン正面を維持するため横移動なし
    private let cameraZoomOutHorizontalOffset: Float = 0.0

    /// 回転を避けるため縦方向にも移動しない
    private let cameraZoomOutVerticalOffset: Float = 0.0

    /// ズームアウト演出の所要時間
    private let cameraZoomOutDuration: TimeInterval = 1.2

    /// カメラが注視する高さ
    private var cameraFocusY: Float {
        groundY + 12
    }

    /// カメラの注視点
    private var cameraTargetPoint: SCNVector3 {
        SCNVector3(centerDarumaStartX, cameraFocusY, centerDarumaStartZ)
    }

    /// 生成レーンの斜めオフセット量
    private let laneDiagonalOffsetStep: Float = 1.2

    /// 生成レーンの向き（+1: 上へ行くほど右、-1: 上へ行くほど左）
    private let laneWaveDirection: Float = 1.0

    /// レーン帯の幅
    private let laneWidth: Float = 150.0

    /// レーンテクスチャの繰り返し数（X方向）
    private let laneTextureRepeatX: Float = 37.0

    /// テクスチャスクロール速度（UV空間での速度）
    private let laneTextureScrollSpeed: Float = 1.667

    /// レーンの帯速度（ワールド座標換算）
    private var beltWorldSpeed: Float {
        laneTextureScrollSpeed * laneWidth / laneTextureRepeatX
    }

    /// レーンごとの開始Xオフセット（必要に応じて配置をずらす）
    private let laneStartOffsets: [Float] = Array(repeating: 0, count: 7)

    /// 中央レーンのインデックス（中央ダルマの位置）
    private let centerLaneIndex: Int = 3

    /// 染まる中央ダルマの開始位置（中央より少し右、奥行き指定可）
    private let centerDarumaStartX: Float = 4.0
    private let centerDarumaStartZ: Float = 0.0

    /// 中央ダルマ周辺で静止ダルマを避ける範囲（左右）
    private let centerLaneSafeZoneHalfWidth: Float = 4.0

    // MARK: - 初期化

    /// シーンで使用する視点
    var pointOfView: SCNNode {
        cameraNode
    }

    init() {
        self.scene = SCNScene()
        self.centerDarumaNode = SCNNode()
        self.cameraNode = SCNNode()

        // レーンのY座標を初期化（7本のレーン）- 適度な間隔で配置
        self.laneYPositions = [
            groundY - 9.0,
            groundY - 3.0,
            groundY + 3.0,
            groundY + 9.0,
            groundY + 15.0,
            groundY + 21.0,
            groundY + 27.0
        ]

        // テクスチャをロード
        baseTexture = loadTexture()

        // 環境設定
        setupCamera()
        setupLighting()
        setupLanes()

        // 中央ダルマを作成
        centerDarumaNode = createCenterDaruma()
        scene.rootNode.addChildNode(centerDarumaNode)
        spawnAnchorX = 0.0

        // モデルテンプレートを準備
        modelTemplate = loadModelTemplate()

        // 静止ダルマを配置（染まり完了まで待機）
        setupStaticDarumas()

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
    func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        // 初期位置は染まるダルマを真正面から映す
        cameraNode.position = SCNVector3(centerDarumaStartX, cameraFocusY, cameraInitialZ)
        cameraNode.look(at: cameraTargetPoint)
        scene.rootNode.addChildNode(cameraNode)
    }

    /// カメラをズームアウトするアニメーションを開始（右斜めに引く）
    func startCameraZoomOut() {
        guard !hasCameraZoomOutCompleted else { return }
        cameraNode.removeAction(forKey: "CameraZoom")

        let startPosition = cameraNode.position
        let targetPosition = SCNVector3(
            centerDarumaStartX + cameraZoomOutHorizontalOffset,
            cameraFocusY + cameraZoomOutVerticalOffset,
            cameraFinalZ
        )

        let duration = cameraZoomOutDuration
        let zoomAction = SCNAction.customAction(duration: duration) { [weak self] node, elapsed in
            guard let self else { return }
            let rawProgress = min(max(Float(elapsed / CGFloat(duration)), 0), 1)
            let easedProgress = self.easeInOutQuad(rawProgress)

            let interpolatedPosition = SCNVector3(
                startPosition.x + (targetPosition.x - startPosition.x) * easedProgress,
                startPosition.y + (targetPosition.y - startPosition.y) * easedProgress,
                startPosition.z + (targetPosition.z - startPosition.z) * easedProgress
            )

            node.position = interpolatedPosition
            node.look(at: self.cameraTargetPoint)
        }

        let completion = SCNAction.run { [weak self] _ in
            self?.hasCameraZoomOutCompleted = true
        }

        cameraNode.runAction(SCNAction.sequence([zoomAction, completion]), forKey: "CameraZoom")
    }

    /// イージング関数（ease-in-out quadratic）
    private func easeInOutQuad(_ t: Float) -> Float {
        if t < 0.5 {
            return 2 * t * t
        } else {
            return 1 - pow(-2 * t + 2, 2) / 2
        }
    }

    /// ライティング設定
    func setupLighting() {
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
        directionalLight.position = SCNVector3(2.8, 3.8, 4.2)
        directionalLight.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(directionalLight)

        // やわらかい補助光
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .ambient
        fillLight.light?.intensity = 320
        fillLight.light?.color = UIColor(white: 1.0, alpha: 0.1)
        fillLight.position = SCNVector3(-2, 3, 2)
        scene.rootNode.addChildNode(fillLight)
    }

    /// レーンを設定（ベルトコンベア風の帯 + 縞々アニメーション）
    func setupLanes() {
        for (index, laneY) in laneYPositions.enumerated() {
            // レーンの帯（SCNBox）を作成 - 画面端から端まで拡張
            let laneGeometry = SCNBox(width: CGFloat(laneWidth), height: 0.1, length: 2, chamferRadius: 0)
            let laneMaterial = SCNMaterial()

            // 縞々テクスチャを生成
            laneMaterial.diffuse.contents = createStripedTexture()
            laneMaterial.diffuse.wrapS = .repeat
            laneMaterial.diffuse.wrapT = .repeat
            // X方向にテクスチャを繰り返す（レーン幅に合わせて増加）
            laneMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(laneTextureRepeatX, 1, 1)

            laneGeometry.materials = [laneMaterial]

            let laneNode = SCNNode(geometry: laneGeometry)
            laneNode.name = "Lane\(index)"
            laneNode.position = SCNVector3(0, laneY, 0)
            scene.rootNode.addChildNode(laneNode)
            laneNodes.append(laneNode)
        }
    }

    /// 縞々テクスチャを生成
    private func createStripedTexture() -> UIImage {
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // 縞を2色で描画（customRedと白）
            let stripeWidth: CGFloat = 32
            UIColor.customRed.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: stripeWidth, height: size.height))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: stripeWidth, y: 0, width: stripeWidth, height: size.height))
        }
    }

    /// レーンのテクスチャアニメーションを更新
    func updateLaneAnimation(deltaTime: TimeInterval) {
        for laneNode in laneNodes {
            guard let material = laneNode.geometry?.firstMaterial else { continue }
            // テクスチャを右から左にスクロール（ダルマの移動方向に合わせる）
            var transform = material.diffuse.contentsTransform
            transform.m41 += laneTextureScrollSpeed * Float(deltaTime)
            material.diffuse.contentsTransform = transform
        }
    }

    // MARK: - 中央ダルマ

    /// 中央のダルマを作成
    private func createCenterDaruma() -> SCNNode {
        let darumaNode = SCNNode()
        let orientedModelNode = SCNNode()

        guard let url = locateModelURL(),
              let modelScene = try? SCNScene(url: url, options: nil) else {
            // フォールバック: 球体
            let sphere = SCNSphere(radius: 0.8)
            let material = makeSceneKitMaterial(color: centerStartColor, cacheable: false)
            sphere.materials = [material]
            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.eulerAngles.x = baseModelXRotation
            darumaNode.addChildNode(sphereNode)
            alignModelBottom(darumaNode)

            let middleLaneY = laneYPositions[centerLaneIndex]
            darumaNode.position = SCNVector3(centerDarumaStartX, middleLaneY, centerDarumaStartZ)
            updateCenterDarumaModelBounds(for: darumaNode)
            if let shaderMaterial = makeCenterDarumaMaterial() {
                applyCenterDarumaMaterial(to: darumaNode, baseMaterial: shaderMaterial)
            }
            return darumaNode
        }

        for childNode in modelScene.rootNode.childNodes {
            orientedModelNode.addChildNode(childNode)
        }
        orientedModelNode.eulerAngles.x = baseModelXRotation
        enableSubdivision(for: orientedModelNode)
        darumaNode.addChildNode(orientedModelNode)

        // スケーリング
        let (minBounds, maxBounds) = darumaNode.boundingBox
        let size = SCNVector3(
            x: maxBounds.x - minBounds.x,
            y: maxBounds.y - minBounds.y,
            z: maxBounds.z - minBounds.z
        )
        let maxDimension = max(size.x, size.y, size.z)
        let scale: Float = 3.5 / max(maxDimension, 0.001)
        darumaNode.scale = SCNVector3(scale, scale, scale)
        alignModelBottom(darumaNode)

        // 真ん中のレーンに配置（7本レーンの中央はインデックス3）
        let middleLaneY = laneYPositions[centerLaneIndex]
        darumaNode.position = SCNVector3(centerDarumaStartX, middleLaneY, centerDarumaStartZ)
        darumaNode.name = "CenterDaruma"

        // 中央ダルマのマテリアルを設定（最終的なスケール・配置後の境界を使用）
        updateCenterDarumaModelBounds(for: darumaNode)
        if let material = makeCenterDarumaMaterial() {
            applyCenterDarumaMaterial(to: darumaNode, baseMaterial: material)
        } else {
            applyMaterial(to: darumaNode, color: centerStartColor, cacheable: false)
        }

        return darumaNode
    }

    /// 中央だるまを左へ流し始める（消失時にフラグを立て、ノードを削除）
    func startCenterDarumaFlow() {
        guard !hasCenterDarumaStartedMoving else { return }
        hasCenterDarumaStartedMoving = true

        let middleLaneY = laneYPositions[centerLaneIndex]
        let endX: Float = centerDarumaStartX - laneWidth / 2
        let travelDistance = abs(centerDarumaNode.position.x - endX)
        let beltSpeed = max(beltWorldSpeed, 0.1)
        let duration = Double(travelDistance / beltSpeed)

        let moveAction = SCNAction.move(to: SCNVector3(endX, middleLaneY, centerDarumaStartZ), duration: duration)

        // 消失時にフラグを立てるアクション
        let disappearAction = SCNAction.run { [weak self] _ in
            self?.hasCenterDarumaDisappeared = true
        }

        // ノードを削除するアクション
        let removeAction = SCNAction.removeFromParentNode()

        let sequence = SCNAction.sequence([moveAction, disappearAction, removeAction])
        centerDarumaNode.runAction(sequence)
    }

    /// 中央だるまを回転させながら赤く染める
    func startCenterDarumaSpinAndColor(duration: TimeInterval = 2.5) {
        guard !hasCenterDarumaSpinStarted else { return }
        hasCenterDarumaSpinStarted = true
        isCenterDarumaSpinning = true
        ensureCenterDarumaTintedSequence(steps: 24)

        let spinDuration: TimeInterval = 0.9
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 4, z: 0, duration: spinDuration)
        rotate.timingMode = .easeOut

        let jumpUp = SCNAction.moveBy(x: 0, y: 0.6, z: 0, duration: 0.3)
        jumpUp.timingMode = .easeOut
        let jumpDown = SCNAction.moveBy(x: 0, y: -0.6, z: 0, duration: 0.3)
        jumpDown.timingMode = .easeIn
        let jump = SCNAction.sequence([jumpUp, jumpDown])

        let colorFlip = SCNAction.sequence([
            SCNAction.wait(duration: 0.3),
            SCNAction.run { [weak self] _ in
                guard let self else { return }
                let tintedTexture = self.centerDarumaTintedSequence.last ?? self.centerEndColor
                for material in self.centerDarumaMaterials {
                    material.diffuse.contents = tintedTexture
                    material.ambient.contents = tintedTexture
                }
            }
        ])

        let endSpin = SCNAction.run { [weak self] _ in
            self?.isCenterDarumaSpinning = false
        }
        let group = SCNAction.group([rotate, jump, colorFlip])
        centerDarumaNode.runAction(SCNAction.sequence([group, endSpin]), forKey: "CenterDarumaSpin")
    }

    /// 中央ダルマの色を更新（現在は固定色のため処理なし）
    func updateCenterDarumaColor(progress: Double) {
        // 染めアニメーション削除済み
    }

    // MARK: - 静止ダルマ（初期配置）

    /// 静止ダルマを配置（染まり完了まで静止状態で待機）
    private func setupStaticDarumas() {
        guard modelTemplate != nil else { return }

        // 継続生成と同じ本数・間隔で初期配置し、密度に差が出ないようにする
        let progressValues = initialSpawnProgresses.isEmpty ? [0.0] : initialSpawnProgresses

        for laneIndex in 0..<laneYPositions.count {
            guard let (startX, endX) = spawnBounds(for: laneIndex) else { continue }
            let progressShift = laneProgressShift(for: laneIndex)

            for baseProgress in progressValues {
                let adjustedProgress = baseProgress - progressShift
                if adjustedProgress < 0 || adjustedProgress > staticPrefillMaxProgress {
                    continue
                }

                let currentX = positionAlongLane(progress: adjustedProgress, startX: startX, endX: endX)
                if laneIndex == centerLaneIndex && abs(currentX - centerDarumaStartX) < centerLaneSafeZoneHalfWidth {
                    continue
                }

                guard let darumaNode = spawnDarumaNode(
                    laneIndex: laneIndex,
                    initialProgress: adjustedProgress,
                    shouldStartMoving: false
                ) else {
                    continue
                }

                staticDarumaNodes.append(PrefilledDaruma(node: darumaNode, laneIndex: laneIndex))
            }
        }
    }

    /// 全ての静止ダルマを動かし始め、継続生成を開始
    func startAllDarumasMoving() {
        // 静止ダルマに移動アクションを適用
        for entry in staticDarumaNodes {
            guard let (startX, endX) = spawnBounds(for: entry.laneIndex) else { continue }
            let currentX = Float(entry.node.position.x)
            runMoveAction(on: entry.node, laneIndex: entry.laneIndex, startX: startX, endX: endX, currentX: currentX)
            activeRainNodes.append(entry.node)
        }

        // 静止ダルマ配列をクリア
        staticDarumaNodes.removeAll()

        // 継続生成タイマーを初期化
        resetLaneSpawnTimers()
    }

    /// レーンごとのスポーンタイマーを初期化
    private func resetLaneSpawnTimers() {
        laneSpawnTimers = laneYPositions.enumerated().map { index, _ in
            // 初期遅延 + レーンごとのずれを設定
            initialSpawnDelay + TimeInterval(index) * laneSpawnStagger
        }
    }

    // MARK: - 降下ダルマ

    /// モデルテンプレートをロード
    private func loadModelTemplate() -> SCNNode? {
        guard let url = locateModelURL(),
              let modelScene = try? SCNScene(url: url, options: nil) else {
            return makeFallbackSphereTemplate()
        }

        let container = SCNNode()
        for child in modelScene.rootNode.childNodes {
            container.addChildNode(child)
        }
        container.eulerAngles.x = baseModelXRotation
        disableSubdivision(for: container)

        // ベーススケール
        let (minBounds, maxBounds) = container.boundingBox
        let size = SCNVector3(
            maxBounds.x - minBounds.x,
            maxBounds.y - minBounds.y,
            maxBounds.z - minBounds.z
        )
        let maxDimension = max(size.x, max(size.y, size.z))
        if maxDimension > 0 {
            let baseScale: Float = 3.5 / maxDimension
            container.scale = SCNVector3(baseScale, baseScale, baseScale)
        }
        alignModelBottom(container)

        return container
    }

    /// フォールバック用の球体テンプレート
    private func makeFallbackSphereTemplate() -> SCNNode {
        let sphere = SCNSphere(radius: 0.3)
        sphere.segmentCount = 24
        let node = SCNNode(geometry: sphere)
        alignModelBottom(node)
        return node
    }

    /// 時間経過を更新（継続生成）
    func update(deltaTime: TimeInterval) {
        guard !laneSpawnTimers.isEmpty, spawnInterval > 0 else { return }

        for index in laneSpawnTimers.indices {
            laneSpawnTimers[index] -= deltaTime
            while laneSpawnTimers[index] <= 0 {
                addDarumaToLane(laneIndex: index)
                laneSpawnTimers[index] += spawnInterval
            }
        }
    }

    /// 指定したレーンにだるまを追加（SCNActionで移動）
    func addDarumaToLane(laneIndex: Int, initialProgress: Float = 0) {
        guard activeRainNodes.count < maxDarumaCount else { return }
        _ = spawnDarumaNode(
            laneIndex: laneIndex,
            initialProgress: initialProgress,
            shouldStartMoving: true
        )
    }

    /// 降下ダルマを追加（後方互換性のため維持、ランダムなレーンに追加）
    func addFallingDaruma() {
        let laneIndex = Int.random(in: 0..<laneYPositions.count)
        addDarumaToLane(laneIndex: laneIndex)
    }

    private func laneProgressShift(for laneIndex: Int) -> Float {
        let travelDuration = Double(laneWidth / beltWorldSpeed)
        guard travelDuration > 0 else { return 0 }
        let delay = initialSpawnDelay + TimeInterval(laneIndex) * laneSpawnStagger
        return Float(delay / travelDuration)
    }

    /// レーンごとのスポーン開始/終了座標を計算
    private func spawnBounds(for laneIndex: Int) -> (startX: Float, endX: Float)? {
        guard laneIndex >= 0 && laneIndex < laneYPositions.count else { return nil }
        let spawnOriginX = spawnAnchorX + spawnStartOffsetFromCenter + laneWidth / 2 + spawnOffscreenMargin
        let laneOffset = laneIndex < laneStartOffsets.count ? laneStartOffsets[laneIndex] : 0
        let diagonalOffset = laneDiagonalOffset(for: laneIndex)
        let startX = spawnOriginX + diagonalOffset + laneOffset
        let endX: Float = spawnOriginX - laneWidth + diagonalOffset
        return (startX, endX)
    }

    /// レーンの上下位置に応じた斜めオフセットを計算
    private func laneDiagonalOffset(for laneIndex: Int) -> Float {
        let midIndex = Float(laneYPositions.count - 1) / 2.0
        let offsetFromCenter = Float(laneIndex) - midIndex
        return offsetFromCenter * laneDiagonalOffsetStep * laneWaveDirection
    }

    /// プログレス値をX座標に変換
    private func positionAlongLane(progress: Float, startX: Float, endX: Float) -> Float {
        let clampedProgress = min(max(progress, 0.0), 0.95)
        return startX - (startX - endX) * clampedProgress
    }

    /// ダルマノードを生成し、必要なら移動を開始
    @discardableResult
    private func spawnDarumaNode(
        laneIndex: Int,
        initialProgress: Float,
        shouldStartMoving: Bool
    ) -> SCNNode? {
        guard laneIndex >= 0 && laneIndex < laneYPositions.count else { return nil }
        guard let template = modelTemplate else { return nil }
        guard let (startX, endX) = spawnBounds(for: laneIndex) else { return nil }

        let laneY = laneYPositions[laneIndex]
        let randomColor = rainColors.randomElement() ?? rainColors[0]
        let baseTemplate = colorizedTemplate(for: randomColor) ?? template
        let darumaNode = baseTemplate.clone()
        darumaNode.name = shouldStartMoving ? "fallingDaruma" : "staticDaruma"
        darumaNode.scale = baseTemplate.scale

        if baseTemplate === template {
            applyMaterial(to: darumaNode, color: randomColor, cacheable: true)
        }

        let currentX = positionAlongLane(progress: initialProgress, startX: startX, endX: endX)
        darumaNode.position = SCNVector3(currentX, laneY, 1)
        darumaNode.eulerAngles = SCNVector3(baseModelXRotation, 0, 0)

        scene.rootNode.addChildNode(darumaNode)

        if shouldStartMoving {
            runMoveAction(on: darumaNode, laneIndex: laneIndex, startX: startX, endX: endX, currentX: currentX)
            activeRainNodes.append(darumaNode)
        }

        return darumaNode
    }

    /// ダルマノードに右→左への移動アクションを適用
    private func runMoveAction(on node: SCNNode, laneIndex: Int, startX: Float, endX: Float, currentX: Float) {
        let laneY = laneYPositions[laneIndex]
        let travelDistance = abs(currentX - endX)
        let beltSpeed = max(beltWorldSpeed, 0.1)

        guard travelDistance > 0 else {
            node.position = SCNVector3(startX, laneY, node.position.z)
            runMoveAction(on: node, laneIndex: laneIndex, startX: startX, endX: endX, currentX: startX)
            return
        }

        let travelDuration = Double(travelDistance / beltSpeed)
        let moveAction = SCNAction.move(to: SCNVector3(endX, laneY, node.position.z), duration: travelDuration)
        let loopAction = SCNAction.run { [weak self] _ in
            self?.resetDarumaForLoop(node, laneIndex: laneIndex, startX: startX, endX: endX)
        }

        let sequence = SCNAction.sequence([moveAction, loopAction])
        node.runAction(sequence)
    }

    /// ループ用にダルマの位置をリセットして再度移動を開始
    private func resetDarumaForLoop(_ node: SCNNode, laneIndex: Int, startX: Float, endX: Float) {
        let laneY = laneYPositions[laneIndex]
        node.position = SCNVector3(startX, laneY, node.position.z)
        runMoveAction(on: node, laneIndex: laneIndex, startX: startX, endX: endX, currentX: startX)
    }

    /// 初期配置のプログレス値を計算
    /// 各ダルマはspawnInterval間隔で生成されたものとして均等に配置
    /// これにより初期ウェーブ完了後も途切れなく継続する
    private static func makeInitialProgresses(travelDuration: Double, spawnInterval: TimeInterval, cap: Int) -> [Float] {
        guard spawnInterval > 0 else { return [0.0] }
        // レーン全体をカバーするのに必要な最小限のダルマ数を計算
        let requiredCount = max(1, Int(ceil(travelDuration / spawnInterval)))
        let desiredCount = min(cap, requiredCount)
        guard desiredCount > 1 else { return [0.0] }

        // spawnInterval間隔で均等に配置（時間ベースで計算）
        // 各ダルマは (index * spawnInterval / travelDuration) だけ進んだ位置に配置
        return (0..<desiredCount).map { index in
            let timeElapsed = Double(index) * spawnInterval
            return Float(min(timeElapsed / travelDuration, 0.95))
        }
    }

    /// 古いダルマを削除（SCNActionで自動削除されるため簡略化）
    func cleanupOldDarumas() {
        activeRainNodes.removeAll { node in
            node.parent == nil
        }
    }

    /// アクティブなダルマ数を取得
    var activeRainCount: Int {
        return activeRainNodes.count
    }

    // MARK: - マテリアル

    /// 中央ダルマ用のカスタムマテリアルを作成（固定色）
    private func makeCenterDarumaMaterial() -> SCNMaterial? {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.isDoubleSided = true
        let whiteBakedTexture = createTintedTexture(with: centerStartColor, cacheable: false)
            ?? baseTexture
        material.diffuse.contents = whiteBakedTexture ?? centerStartColor
        material.roughness.contents = NSNumber(value: 0.82)
        material.metalness.contents = NSNumber(value: 0.04)
        return material
    }

    /// マテリアルを作成
    private func makeSceneKitMaterial(color: UIColor, cacheable: Bool) -> SCNMaterial {
        let cacheKey = colorKey(for: color)
        if cacheable, let cached = materialCache[cacheKey] {
            return cached
        }

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.isDoubleSided = true

        if let tintedImage = createTintedTexture(with: color, cacheable: cacheable) {
            material.diffuse.contents = tintedImage
        } else {
            material.diffuse.contents = color
        }

        material.roughness.contents = NSNumber(value: 0.82)
        material.metalness.contents = NSNumber(value: 0.04)
        material.emission.contents = UIColor.black

        if cacheable {
            materialCache[cacheKey] = material
        }

        return material
    }

    /// テクスチャに色を合成した画像を作成
    private func createTintedTexture(with color: UIColor, cacheable: Bool) -> UIImage? {
        guard let texture = baseTexture else { return nil }

        let cacheKey = colorKey(for: color)
        if cacheable, let cached = tintedTextureCache[cacheKey] {
            return cached
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        let renderer = UIGraphicsImageRenderer(size: texture.size, format: format)

        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: texture.size)
            color.setFill()
            ctx.fill(rect)
            texture.draw(in: rect)
        }

        if cacheable {
            tintedTextureCache[cacheKey] = image
        }

        return image
    }

    private func ensureCenterDarumaTintedSequence(steps: Int) {
        guard centerDarumaTintedSequence.isEmpty else { return }
        let clampedSteps = max(2, steps)
        var sequence: [UIImage] = []
        sequence.reserveCapacity(clampedSteps)
        for i in 0..<clampedSteps {
            let progress = CGFloat(i) / CGFloat(clampedSteps - 1)
            let color = interpolateColor(from: centerStartColor, to: centerEndColor, progress: progress)
            if let tinted = createTintedTexture(with: color, cacheable: false) {
                sequence.append(tinted)
            }
        }
        centerDarumaTintedSequence = sequence
    }

    private func createSolidTexture(color: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// ノードにマテリアルを再帰的に適用（カラー指定）
    private func applyMaterial(to node: SCNNode, color: UIColor, cacheable: Bool = true) {
        if let geometry = node.geometry {
            let material = makeSceneKitMaterial(color: color, cacheable: cacheable)
            geometry.materials = geometry.materials.isEmpty ? [material] : Array(repeating: material, count: geometry.materials.count)
        }
        for child in node.childNodes {
            applyMaterial(to: child, color: color, cacheable: cacheable)
        }
    }

    /// ノードに既存のマテリアルを再帰的に適用
    private func applyMaterial(to node: SCNNode, material: SCNMaterial) {
        if let geometry = node.geometry {
            geometry.materials = geometry.materials.isEmpty ? [material] : Array(repeating: material, count: geometry.materials.count)
        }
        for child in node.childNodes {
            applyMaterial(to: child, material: material)
        }
    }

    /// 中央ダルマ用マテリアルをノードに適用（ワールド座標系の値を使用）
    private func applyCenterDarumaMaterial(to node: SCNNode, baseMaterial: SCNMaterial) {
        centerDarumaMaterials.removeAll()
        applyCenterDarumaMaterialRecursive(to: node, baseMaterial: baseMaterial)
    }

    private func applyCenterDarumaMaterialRecursive(to node: SCNNode, baseMaterial: SCNMaterial) {
        if let geometry = node.geometry {
            let material = baseMaterial.copy() as? SCNMaterial ?? baseMaterial
            // ワールド座標系の値をそのまま使用（シェーダー内でワールド座標に変換するため）
            material.setValue(centerDarumaMinY, forKey: "centerMinY")
            material.setValue(centerDarumaHeight, forKey: "centerHeight")

            geometry.materials = geometry.materials.isEmpty ? [material] : Array(repeating: material, count: geometry.materials.count)
            centerDarumaMaterials.append(material)
        }
        for child in node.childNodes {
            applyCenterDarumaMaterialRecursive(to: child, baseMaterial: baseMaterial)
        }
    }

    /// 中央ダルマのワールド座標での上下端を計算
    private func updateCenterDarumaModelBounds(for node: SCNNode) {
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
            centerDarumaMinY = 0
            centerDarumaMaxY = 1
            centerDarumaHeight = 1
            return
        }

        centerDarumaMinY = minY
        centerDarumaMaxY = maxY
        centerDarumaHeight = max(maxY - minY, 0.001)
    }



    /// キャッシュキーを生成
    private func colorKey(for color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%.3f-%.3f-%.3f-%.3f", r, g, b, a)
    }

    /// 色の補間
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

    /// サブディビジョンを無効化（OSD_MAX_VALENCE回避）
    private func disableSubdivision(for node: SCNNode) {
        if let geometry = node.geometry {
            geometry.subdivisionLevel = 0
            geometry.wantsAdaptiveSubdivision = false
        }
        for child in node.childNodes {
            disableSubdivision(for: child)
        }
    }

    /// サブディビジョンを有効化（中央ダルマのみ高精細）
    private func enableSubdivision(for node: SCNNode) {
        if let geometry = node.geometry {
            geometry.subdivisionLevel = 1
            geometry.wantsAdaptiveSubdivision = true
        }
        for child in node.childNodes {
            enableSubdivision(for: child)
        }
    }

    /// 色付きテンプレートを取得（色ごとに1回だけジオメトリを複製）
    private func colorizedTemplate(for color: UIColor) -> SCNNode? {
        let key = colorKey(for: color)
        if let cached = coloredTemplateCache[key] {
            return cached
        }
        guard let baseTemplate = modelTemplate else { return nil }
        let template = baseTemplate.clone()
        makeGeometryUnique(for: template)
        applyMaterial(to: template, color: color, cacheable: true)
        coloredTemplateCache[key] = template
        return template
    }

    /// モデルの底面がY=0になるよう子ノードをオフセット
    private func alignModelBottom(_ node: SCNNode) {
        let (minBounds, _) = node.boundingBox
        guard minBounds.y != 0 else { return }
        let offset = -minBounds.y
        for child in node.childNodes {
            child.position.y += offset
        }
    }
}
