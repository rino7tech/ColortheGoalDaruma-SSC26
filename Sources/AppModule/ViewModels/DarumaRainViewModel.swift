import Foundation
import Observation

/// ダルマ降下エフェクトを管理するViewModel
@Observable
final class DarumaRainViewModel {
    // MARK: - 色変化アニメーション用プロパティ

    /// 色変化の進行度（0.0〜1.0）
    var colorProgress: Double = 0.0

    /// 色変化アニメーション経過時間
    private var colorAnimationTime: Double = 0.0

    /// ログ出力用の最終時刻
    private var lastProgressLogTime: Double = 0.0

    /// 色変化アニメーション完了フラグ
    var isColorAnimationComplete: Bool = false

    /// 色変化アニメーション開始済みフラグ
    private var hasColorAnimationStarted: Bool = false

    /// 色変化アニメーション時間（秒）
    private let colorAnimationDuration: Double = 3.6

    // MARK: - 降下エフェクト用プロパティ

    /// 降下エフェクト実行中フラグ
    var isRaining: Bool = false

    /// 流れ星表示フラグ
    var isNagareboshiVisible: Bool = false

    // MARK: - カメラ状態プロパティ

    /// カメラズームアウト完了フラグ（UIを表示するタイミング）
    var isCameraZoomOutComplete: Bool = false

    // MARK: - 初期化

    init() {}

    // MARK: - 色変化アニメーション

    /// 色変化アニメーションを開始
    func startColorAnimation() {
        guard !hasColorAnimationStarted else { return }
        hasColorAnimationStarted = true
        colorProgress = 0.0
        colorAnimationTime = 0.0
        isColorAnimationComplete = false
    }

    /// 色変化アニメーションを更新
    /// - Parameter deltaTime: 前回のフレームからの経過時間（秒）
    func updateColorAnimation(deltaTime: Double) {
        guard hasColorAnimationStarted && !isColorAnimationComplete else { return }

        let clampedDelta = min(deltaTime, 1.0 / 30.0)
        colorAnimationTime += clampedDelta

        // イージング関数を適用（easeOutExpoで序盤に急激に染まり、終盤でゆっくり仕上がる）
        let rawProgress = min(colorAnimationTime / colorAnimationDuration, 1.0)
        colorProgress = easeOutExpo(rawProgress)

        if colorAnimationTime - lastProgressLogTime >= 0.25 {
            lastProgressLogTime = colorAnimationTime
            print("[DarumaColor] progress=\(String(format: "%.3f", colorProgress)) time=\(String(format: "%.2f", colorAnimationTime))")
        }

        if colorProgress >= 1.0 {
            isColorAnimationComplete = true
        }
    }

    /// イージング関数（Exponential Ease Out）
    /// 序盤で急激に変化し、終盤でゆっくり仕上がる → 「染まっていく」感覚を強調
    private func easeOutExpo(_ t: Double) -> Double {
        return t == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * t)
    }

    // MARK: - 降下エフェクト制御

    /// 降下エフェクトを開始
    func startRain() {
        isRaining = true
    }

    /// 降下エフェクトを停止
    func stopRain() {
        isRaining = false
    }
}
