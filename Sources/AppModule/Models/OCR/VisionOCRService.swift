import Foundation
import Vision
import UIKit
import CoreImage

/// Vision OCRを使ってテキストを認識するサービス
@MainActor
final class VisionOCRService {
    static let shared = VisionOCRService()

    private init() {}

    /// 画像からテキストを認識する
    /// - Parameters:
    ///   - image: 認識対象の画像
    ///   - preferJapanese: 日本語を優先する場合はtrue
    /// - Returns: 認識されたテキスト
    func recognizeText(from image: UIImage, preferJapanese: Bool = true) async throws -> String {
        print("🖼️ [VisionOCR] Input image size: \(image.size)")
        print("🖼️ [VisionOCR] Prefer Japanese: \(preferJapanese)")

        let processedImage = preprocessImage(image)

        guard let cgImage = processedImage.cgImage else {
            print("❌ [VisionOCR] Failed to get CGImage")
            throw OCRError.invalidImage
        }

        print("🖼️ [VisionOCR] CGImage size: \(cgImage.width)x\(cgImage.height)")

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("❌ [VisionOCR] Recognition error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    print("❌ [VisionOCR] No observations found")
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                print("📊 [VisionOCR] Found \(observations.count) observations")

                // 認識されたテキストを結合（複数候補を考慮）
                let recognizedStrings = observations.compactMap { observation -> String? in
                    let candidates = observation.topCandidates(5)  // 上位5候補を取得
                    print("   Candidates: \(candidates.map { "\($0.string) (\($0.confidence))" }.joined(separator: ", "))")
                    // 改行を削除してテキストを取得
                    return candidates.first?.string.replacingOccurrences(of: "\n", with: "")
                }

                // 改行せずに連続したテキストとして結合
                let fullText = recognizedStrings.joined(separator: "")

                print("📝 [VisionOCR] Recognized text: '\(fullText)'")

                if fullText.isEmpty {
                    print("❌ [VisionOCR] Recognized text is empty")
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: fullText)
                }
            }

            // 言語設定（日本語優先か英語優先かを設定）
            if preferJapanese {
                request.recognitionLanguages = ["ja-JP", "en-US"]  // 日本語を優先
            } else {
                request.recognitionLanguages = ["en-US", "ja-JP"]  // 英語を優先
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.0  // 小さい文字も認識

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// 画像をOCR用に前処理する
    /// - Parameter image: 元画像
    /// - Returns: 前処理された画像
    private func preprocessImage(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            return image
        }

        let context = CIContext()

        // コントラストを上げる
        guard let contrastFilter = CIFilter(name: "CIColorControls") else {
            return image
        }
        contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.5, forKey: kCIInputContrastKey)  // コントラストを上げる
        contrastFilter.setValue(0.0, forKey: kCIInputBrightnessKey)

        guard let contrastOutput = contrastFilter.outputImage else {
            return image
        }

        // シャープネスを上げる
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else {
            return convertToUIImage(contrastOutput, context: context) ?? image
        }
        sharpenFilter.setValue(contrastOutput, forKey: kCIInputImageKey)
        sharpenFilter.setValue(1.0, forKey: kCIInputSharpnessKey)

        guard let finalOutput = sharpenFilter.outputImage else {
            return convertToUIImage(contrastOutput, context: context) ?? image
        }

        return convertToUIImage(finalOutput, context: context) ?? image
    }

    /// CIImageをUIImageに変換
    private func convertToUIImage(_ ciImage: CIImage, context: CIContext) -> UIImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The image is invalid."
        case .noTextFound:
            return "No text was detected."
        case .notAvailable:
            return "OCR is not available."
        }
    }
}
