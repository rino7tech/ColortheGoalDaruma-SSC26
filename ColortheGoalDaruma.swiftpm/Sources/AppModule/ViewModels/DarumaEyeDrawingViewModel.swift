import SwiftUI

/// だるまの右目を描くためのViewModel
@MainActor
@Observable
final class DarumaEyeDrawingViewModel {
    /// 毛筆ストロークの配列
    var strokes: [CalligraphyStroke] = []
    /// 消しゴムモードかどうか
    var isErasing = false
    /// キャンバスのCoordinator参照（画像キャプチャ用）
    var canvasCoordinator: CalligraphyCanvasView.Coordinator?

    /// ペンに切り替え
    func switchToPen() {
        isErasing = false
    }

    /// 消しゴムに切り替え
    func switchToEraser() {
        isErasing = true
    }

    /// 描画をクリアする
    func clearDrawing() {
        strokes.removeAll()
    }

    /// 描画内容から画像を生成する
    func captureEyeImage() -> UIImage? {
        guard !strokes.isEmpty else { return nil }
        guard let coordinator = canvasCoordinator else { return nil }
        return CalligraphyCanvasView.captureImage(coordinator: coordinator)
    }
}
