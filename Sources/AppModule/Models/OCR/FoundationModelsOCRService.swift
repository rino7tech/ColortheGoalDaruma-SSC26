import Foundation
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

/// FoundationModelsを使った手書き文字認識サービス（iOS 18.2以降）
@MainActor
final class FoundationModelsOCRService {
    static let shared = FoundationModelsOCRService()

    private init() {}

    /// FoundationModelsが利用可能かどうか
    var isAvailable: Bool {
        if #available(iOS 18.2, *) {
            return true
        }
        return false
    }

    /// UIImageから手書き文字を認識する
    /// - Parameters:
    ///   - image: 描画内容の画像
    ///   - isJapanese: 日本語の場合はtrue（縦書き）、英語の場合はfalse（横書き）
    /// - Returns: 認識されたテキスト
    func recognizeText(from image: UIImage, isJapanese: Bool = true) async throws -> String {
        if #available(iOS 18.2, *) {
            #if canImport(FoundationModels)
            return try await recognizeWithFoundationModels(image: image, isJapanese: isJapanese)
            #else
            throw OCRError.notAvailable
            #endif
        } else {
            throw OCRError.notAvailable
        }
    }

    @available(iOS 18.2, *)
    private func recognizeWithFoundationModels(image: UIImage, isJapanese: Bool) async throws -> String {
        // TODO: FoundationModelsのAPIが正式にリリースされたら実装
        // 現在はVision OCRにフォールバック
        throw OCRError.notAvailable
    }
}

enum HandwritingOCRError: LocalizedError {
    case notAvailable
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "FoundationModels is unavailable (requires iOS 18.2 or later)."
        case .recognitionFailed:
            return "Handwriting recognition failed."
        }
    }
}
