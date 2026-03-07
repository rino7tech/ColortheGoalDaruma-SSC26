import Foundation
import UIKit

/// 手書き文字認識の統合サービス
/// FoundationModels（iOS 18.2+）を優先的に使用し、利用できない場合はVision OCRにフォールバック
@MainActor
final class HandwritingRecognitionService {
    static let shared = HandwritingRecognitionService()

    private let foundationModelsService = FoundationModelsOCRService.shared
    private let visionOCRService = VisionOCRService.shared

    private init() {}

    /// UIImageから手書き文字を認識する
    /// - Parameter image: 描画内容の画像
    /// - Returns: 認識されたテキスト
    func recognizeText(from image: UIImage) async throws -> String {
        print("📝 [OCR] Starting text recognition from UIImage...")
        print("📝 [OCR] Image size: \(image.size)")

        // FoundationModelsが利用可能な場合は優先的に使用
        if foundationModelsService.isAvailable {
            print("🔍 [OCR] Trying FoundationModels...")
            do {
                // 最初に日本語（縦書き）で試す
                if let japaneseText = try? await foundationModelsService.recognizeText(from: image, isJapanese: true),
                   !japaneseText.isEmpty {
                    print("✅ [OCR] FoundationModels (Japanese): \(japaneseText)")
                    if containsJapanese(japaneseText) {
                        return japaneseText
                    }
                }

                // 日本語でなければ英語（横書き）で試す
                let englishText = try await foundationModelsService.recognizeText(from: image, isJapanese: false)
                if !englishText.isEmpty {
                    print("✅ [OCR] FoundationModels (English): \(englishText)")
                    return englishText
                }
            } catch {
                print("⚠️ [OCR] FoundationModels failed, falling back to Vision OCR: \(error)")
            }
        } else {
            print("ℹ️ [OCR] FoundationModels not available, using Vision OCR")
        }

        // Vision OCRにフォールバック
        print("🔍 [OCR] Trying Vision OCR...")
        let result = try await recognizeWithVisionOCR(image: image)
        print("✅ [OCR] Vision OCR result: \(result)")
        return result
    }

    /// Vision OCRを使って画像から認識（フォールバック）
    private func recognizeWithVisionOCR(image: UIImage) async throws -> String {
        print("📸 [OCR] Image size for OCR: \(image.size)")

        // まず日本語で試す
        print("🔍 [OCR] Trying Japanese recognition...")
        if let japaneseText = try? await visionOCRService.recognizeText(from: image, preferJapanese: true),
           !japaneseText.isEmpty {
            print("✅ [OCR] Japanese result: '\(japaneseText)'")
            if containsJapanese(japaneseText) {
                return japaneseText
            }
        } else {
            print("⚠️ [OCR] Japanese recognition returned empty")
        }

        // 日本語でなければ英語優先で試す
        print("🔍 [OCR] Trying English recognition...")
        let result = try await visionOCRService.recognizeText(from: image, preferJapanese: false)
        print("✅ [OCR] English result: '\(result)'")
        return result
    }

    /// テキストに日本語の文字が含まれているか確認
    private func containsJapanese(_ text: String) -> Bool {
        let hiraganaRange = text.range(of: "[\\u{3040}-\\u{309F}]", options: .regularExpression)
        let katakanaRange = text.range(of: "[\\u{30A0}-\\u{30FF}]", options: .regularExpression)
        let kanjiRange = text.range(of: "[\\u{4E00}-\\u{9FFF}]", options: .regularExpression)

        return hiraganaRange != nil || katakanaRange != nil || kanjiRange != nil
    }
}
