import Foundation
import CoreGraphics

/// 毛筆ストロークの1つのタッチポイント
struct CalligraphyPoint: Sendable {
    /// 座標
    var position: CGPoint
    /// 筆圧 (0〜1、指入力時は0.5固定)
    var pressure: CGFloat
    /// タイムスタンプ
    var timestamp: TimeInterval
}

/// 1つの毛筆ストローク（ポイントの配列）
final class CalligraphyStroke: @unchecked Sendable {
    /// ストロークを構成するポイント
    var points: [CalligraphyPoint]
    /// 消しゴムストロークかどうか
    var isEraser: Bool

    init(points: [CalligraphyPoint] = [], isEraser: Bool = false) {
        self.points = points
        self.isEraser = isEraser
    }

    /// ストロークのバウンディングボックスを計算
    var bounds: CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.position.x
        var minY = first.position.y
        var maxX = minX
        var maxY = minY
        for point in points.dropFirst() {
            minX = min(minX, point.position.x)
            minY = min(minY, point.position.y)
            maxX = max(maxX, point.position.x)
            maxY = max(maxY, point.position.y)
        }
        // 最大線幅分のマージンを加える
        let margin: CGFloat = 30
        return CGRect(
            x: minX - margin,
            y: minY - margin,
            width: maxX - minX + margin * 2,
            height: maxY - minY + margin * 2
        )
    }
}
