import Foundation
import SwiftUI
import Observation

/// ChatView用のレーンベースだるまを管理するViewModel
@Observable
final class ChatLaneDarumaViewModel {
    // MARK: - 状態プロパティ

    /// 現在のだるまの色
    var currentColor: DarumaColor = .red

    /// トランジション中フラグ
    var isTransitioning: Bool = false

    /// レーンアニメーション中フラグ
    var isLaneAnimating: Bool = false

    /// 背景レーン用のスクロール速度
    var laneScrollSpeed: Double = 0.0

    /// トランジション時間（ChatView側の同期用）
    var transitionDuration: TimeInterval = 0.8

    /// ロード中フラグ（質問がnil時にtrueでだるまが回転）
    var isLoading: Bool = false

    /// 手動回転角度（Y軸）
    var manualRotationY: Double = 0.0

    /// 手動回転の慣性速度（ラジアン/秒）
    var manualRotationVelocity: Double = 0.0

    /// 最後にユーザーが操作した時刻
    var lastInteractionTime: TimeInterval = 0.0

    // MARK: - 色スコア管理

    /// 現在の色スコア分布
    private var colorScores: [DarumaColor: Double] = [:]

    // MARK: - 初期化

    init() {
        // 初期状態では赤色
        currentColor = .red
    }

    // MARK: - 色更新

    /// 色スコアに基づいて最も高いスコアの色を取得
    func updateFromScores(_ scores: [DarumaColor: Double]) {
        colorScores = scores

        // 最もスコアが高い色を選択
        if let bestColor = scores.max(by: { $0.value < $1.value })?.key {
            currentColor = bestColor
        }
    }

    /// 色を直接設定
    func setColor(_ color: DarumaColor) {
        currentColor = color
    }

    /// 現在の優勢な色を取得
    func dominantColor() -> DarumaColor {
        currentColor
    }

    // MARK: - 手動回転管理

    /// 手動回転を更新（ドラッグ操作）
    func updateManualRotation(delta: Double, velocity: Double) {
        manualRotationY += delta
        manualRotationVelocity = velocity
        lastInteractionTime = CACurrentMediaTime()
    }

    /// 慣性による回転の減衰を処理
    func updateInertia(deltaTime: Double) {
        guard abs(manualRotationVelocity) > 0.001 else {
            manualRotationVelocity = 0
            return
        }

        manualRotationY += manualRotationVelocity * deltaTime

        // 減衰係数（0.9で緩やかに減速）
        let damping = 0.9
        manualRotationVelocity *= pow(damping, deltaTime * 60)

        // 速度が十分小さくなったら停止
        if abs(manualRotationVelocity) < 0.001 {
            manualRotationVelocity = 0
        }
    }

    /// 手動回転をリセット
    func resetManualRotation() {
        manualRotationY = 0
        manualRotationVelocity = 0
    }

    // MARK: - トランジション

    /// トランジションを開始
    func beginTransition() {
        isTransitioning = true
        isLaneAnimating = true
    }

    /// トランジションを完了
    func endTransition() {
        isTransitioning = false
        isLaneAnimating = false
    }
}
