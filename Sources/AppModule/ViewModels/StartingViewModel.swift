import Foundation
import Observation

/// StartingViewのアニメーション状態を管理するViewModel
@Observable
final class StartingViewModel {
    /// 不透明度の進行度（0.0〜1.0）
    var fillProgress: Double = 0.0

    /// アニメーション経過時間
    var animationTime: Double = 0.0

    /// アニメーション完了フラグ
    var isAnimationComplete: Bool = false

    /// アニメーション開始済みフラグ
    var hasStarted: Bool = false

    /// アニメーション設定
    private let animationDuration: Double = 2.5  // 2.5秒でフェードイン完了
    private let maxDelta: Double = 1.0 / 30.0   // 大きなジャンプで境目を跨がないように抑制

    init() {}

    /// アニメーションを開始
    func startAnimation() {
        print("🎬 StartingViewModel: startAnimation called, hasStarted=\(hasStarted)")
        guard !hasStarted else {
            print("⚠️ Already started, returning")
            return
        }
        hasStarted = true
        fillProgress = 0.0
        animationTime = 0.0
        isAnimationComplete = false
        print("✅ Animation started: fillProgress=\(fillProgress), hasStarted=\(hasStarted)")
    }

    /// フレームごとの更新
    /// - Parameter deltaTime: 前回のフレームからの経過時間（秒）
    func updateAnimation(deltaTime: Double) {
        guard hasStarted && !isAnimationComplete else {
            print("⚠️ Update skipped: hasStarted=\(hasStarted), isComplete=\(isAnimationComplete)")
            return
        }

        let clampedDelta = min(max(deltaTime, 0.0), maxDelta)
        animationTime += clampedDelta

        if animationTime >= animationDuration {
            animationTime -= animationDuration
        }

        let rawProgress = animationTime / animationDuration
        fillProgress = min(max(rawProgress, 0.0), 0.999)
    }
}
