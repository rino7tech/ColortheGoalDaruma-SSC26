import Foundation
import SwiftUI
import Observation
import UIKit

/// だるまのRealityKitシーンを管理するViewModel
@Observable
final class DarumaSceneViewModel {
    /// 現在の色のスコア分布
    var currentScores: [DarumaColor: Double] = [:]

    /// ターゲットとなる色のスコア分布
    var targetScores: [DarumaColor: Double] = [:]

    /// スコア変化の進行度（0.0〜1.0）
    var scoreTransitionProgress: Double = 1.0

    /// 回転アニメーション用の角度
    var rotationAngle: Double = 0.0

    /// Y軸の固定回転角度（裏面表示など）
    var fixedYRotation: Double = 0.0

    /// X軸の固定回転角度（上下の角度調整）
    var fixedXRotation: Double = 0.0

    /// 自動回転を有効にするかどうか
    var enableAutoRotation: Bool = true

    /// カスタムスケール（nilの場合はデフォルト）
    var customScale: Float? = nil

    /// カメラのX軸オフセット（右目を中心に表示する場合など）
    var cameraXOffset: Float = 0.0

    /// カメラのY軸オフセット（上下位置の微調整）
    var cameraYOffset: Float = 0.0

    /// カメラのZ軸オフセット（必要に応じて前後を調整）
    var cameraZOffset: Float = 0.0

    /// 底面からのライティングを強調するかどうか
    var emphasizeBottomLighting: Bool = false

    /// 3Dモデルに貼り付ける願い画像
    var wishImage: UIImage?

    /// 3Dモデルに貼り付ける左目画像
    var leftEyeImage: UIImage?

    /// 3Dモデルに貼り付ける右目画像
    var rightEyeImage: UIImage?

    /// ユーザーのドラッグ操作による手動回転角度（Y軸）
    var manualRotationY: Double = 0.0

    /// 手動回転の慣性速度（ラジアン/秒）
    var manualRotationVelocity: Double = 0.0

    /// 最後にユーザーが操作した時刻
    var lastInteractionTime: TimeInterval = 0.0

    init() {
        // 初期状態では全色を均等に
        let initialScore = 1.0 / Double(DarumaColor.allCases.count)
        for color in DarumaColor.allCases {
            currentScores[color] = initialScore
            targetScores[color] = initialScore
        }
    }

    /// だるまの色スコア分布を更新する
    /// - Parameter scores: 新しいスコア分布
    func updateScores(_ scores: [DarumaColor: Double]) {
        guard !scores.isEmpty else { return }

        // スコアが大きく変わった場合のみ更新
        let hasSignificantChange = scores.contains { color, newScore in
            let oldScore = targetScores[color] ?? 0
            return abs(newScore - oldScore) > 0.05
        }

        guard hasSignificantChange else { return }

        targetScores = scores
        scoreTransitionProgress = 0.0
    }

    /// アニメーションフレームを更新する
    /// - Parameter deltaTime: 前回のフレームからの経過時間（秒）
    func updateAnimation(deltaTime: Double) {
        // スコア変化アニメーション（ゆっくり変化させる）
        if scoreTransitionProgress < 1.0 {
            scoreTransitionProgress = min(scoreTransitionProgress + deltaTime * 0.3, 1.0)

            // 現在のスコアを補間
            for color in DarumaColor.allCases {
                let fromScore = currentScores[color] ?? 0
                let toScore = targetScores[color] ?? 0
                currentScores[color] = fromScore + (toScore - fromScore) * scoreTransitionProgress
            }
        }

        // 回転アニメーション
        rotationAngle += deltaTime * 0.3
        if rotationAngle > .pi * 2 {
            rotationAngle -= .pi * 2
        }

        // 慣性による手動回転の減衰
        if abs(manualRotationVelocity) > 0.001 {
            manualRotationY += manualRotationVelocity * deltaTime
            // 減衰係数（0.9で緩やかに減速）
            let damping = 0.9
            manualRotationVelocity *= pow(damping, deltaTime * 60)

            // 速度が十分小さくなったら停止
            if abs(manualRotationVelocity) < 0.001 {
                manualRotationVelocity = 0
            }
        }
    }

    /// 現在のフレームで使用すべき色を計算する（上位色をブレンド）
    /// - Returns: ブレンドされた色
    func getCurrentDisplayColor() -> Color {
        // スコアが高い順にソート
        let sortedScores = currentScores.sorted { $0.value > $1.value }

        // 上位3色を取得（スコアが0.1以上のものだけ）
        let topColors = sortedScores.prefix(3).filter { $0.value >= 0.1 }

        guard !topColors.isEmpty else {
            return Color.red
        }

        // トップの色のスコアが圧倒的（0.7以上）なら単色で表示
        if let topScore = topColors.first, topScore.value >= 0.7 {
            return Color(topScore.key.gradient[0])
        }

        // 複数色をブレンド
        var blendedRed: CGFloat = 0
        var blendedGreen: CGFloat = 0
        var blendedBlue: CGFloat = 0
        var totalWeight: CGFloat = 0

        for (color, score) in topColors {
            let uiColor = UIColor(color.gradient[0])
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            let weight = CGFloat(score)
            blendedRed += r * weight
            blendedGreen += g * weight
            blendedBlue += b * weight
            totalWeight += weight
        }

        if totalWeight > 0 {
            blendedRed /= totalWeight
            blendedGreen /= totalWeight
            blendedBlue /= totalWeight
        }

        return Color(red: blendedRed, green: blendedGreen, blue: blendedBlue)
    }

    func dominantColor() -> DarumaColor? {
        currentScores.max(by: { $0.value < $1.value })?.key
    }
}
