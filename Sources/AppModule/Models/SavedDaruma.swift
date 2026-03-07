import Foundation
import UIKit

/// 保存されただるまのモデル
struct SavedDaruma: Identifiable, Codable {
    var id: UUID = UUID()
    /// だるまの色
    var darumaColor: DarumaColor
    /// 願い事の要約テキスト
    var wishSentence: String?
    /// 願い書き画像（JPEGデータ）
    var wishImageData: Data?
    /// 左目の描画画像（JPEGデータ）
    var leftEyeImageData: Data?
    /// 右目の描画画像（叶った時に追加、JPEGデータ）
    var rightEyeImageData: Data?
    /// 願いが叶ったかどうか
    var isWishFulfilled: Bool = false
    /// 作成日時
    var createdAt: Date = Date()

    /// 左目画像をUIImageとして返す
    var leftEyeImage: UIImage? { leftEyeImageData.flatMap { UIImage(data: $0) } }
    /// 右目画像をUIImageとして返す
    var rightEyeImage: UIImage? { rightEyeImageData.flatMap { UIImage(data: $0) } }
}
