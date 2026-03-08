import Foundation
import SwiftUI
import Observation
import simd

/// だるま色染めアニメーションを管理するViewModel
@Observable
final class DarumaColorAnimationViewModel {
    // MARK: - プロパティ

    /// アニメーション進行度（0.0〜1.0）
    var progress: Double = 0.0

    /// アニメーション経過時間
    var animationTime: Double = 0.0

    /// アニメーション完了フラグ
    var isAnimationComplete: Bool = false

    /// アニメーション開始済みフラグ
    var hasStarted: Bool = false

    // MARK: - アニメーション設定

    /// アニメーション全体の長さ（秒）
    private let animationDuration: Double = 2.0

    /// 開始色（白）
    private let startColor: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)

    /// 終了色（赤）
    private let endColor: SIMD4<Float> = SIMD4<Float>(0.8, 0.1, 0.1, 1.0)

    // MARK: - 初期化

    init() {}

    // MARK: - メソッド

    /// アニメーションを開始
    func startAnimation() {
        guard !hasStarted else { return }
        hasStarted = true
        progress = 0.0
        animationTime = 0.0
        isAnimationComplete = false
    }

    /// フレームごとの更新
    /// - Parameter deltaTime: 前回のフレームからの経過時間（秒）
    func updateAnimation(deltaTime: Double) {
        guard hasStarted && !isAnimationComplete else { return }

        animationTime += deltaTime

        // イージング関数を適用（開始はゆっくり、中盤で加速、終盤は減速）
        let rawProgress = min(animationTime / animationDuration, 1.0)
        progress = easeInOutCubic(rawProgress)

        // アニメーション完了判定
        if progress >= 1.0 {
            isAnimationComplete = true
        }
    }

    /// Metalシェーダーに渡すUniformデータを取得
    func getShaderUniforms() -> (
        fillProgress: Float,
        startColor: SIMD4<Float>,
        endColor: SIMD4<Float>
    ) {
        return (
            fillProgress: Float(progress),
            startColor: startColor,
            endColor: endColor
        )
    }

    /// イージング関数（Cubic Ease In-Out）
    private func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = 2 * t - 2
            return 1 + f * f * f / 2
        }
    }
}
