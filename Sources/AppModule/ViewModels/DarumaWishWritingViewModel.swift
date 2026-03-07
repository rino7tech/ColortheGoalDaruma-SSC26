import Foundation
import SwiftUI
import Observation

/// だるまの裏面に願い事を書く画面のViewModel
@Observable
@MainActor
final class DarumaWishWritingViewModel {
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

    /// 描画内容をクリア
    func clearDrawing() {
        strokes.removeAll()
        canvasCoordinator?.clearCanvas()
    }

    /// 描画内容を画像として保存（OCR用に最適化）
    func saveDrawingAsImage() -> UIImage? {
        guard !strokes.isEmpty else { return nil }
        guard let coordinator = canvasCoordinator else { return nil }
        // CalligraphyCanvasViewから画像をキャプチャ
        guard let capturedImage = CalligraphyCanvasView.captureImage(coordinator: coordinator) else { return nil }

        // OCR用に白背景で再描画
        let size = capturedImage.size
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 2.0
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            capturedImage.draw(at: .zero)
        }
        return image
    }

    enum CompletionResult {
        case recognizedText(String)
        case capturedImage(UIImage?)
    }

    enum CompletionError: LocalizedError {
        case emptyDrawing
        case recognitionFailed(String)
        case missingHandlers

        var errorDescription: String? {
            switch self {
            case .emptyDrawing:
                return "No text detected. Please write your wish."
            case .recognitionFailed(let message):
                return "Failed to recognize your handwriting: \(message)\nTry writing larger and more clearly."
            case .missingHandlers:
                return "Completion handler is not configured."
            }
        }
    }

    func performCompletion(shouldPerformOCR: Bool) async throws -> CompletionResult {
        if shouldPerformOCR {
            guard !strokes.isEmpty else {
                throw CompletionError.emptyDrawing
            }
            // 画像をキャプチャしてUIImage版OCRに渡す
            guard let image = saveDrawingAsImage() else {
                throw CompletionError.emptyDrawing
            }
            do {
                let text = try await HandwritingRecognitionService.shared.recognizeText(from: image)
                return .recognizedText(text)
            } catch {
                throw CompletionError.recognitionFailed(error.localizedDescription)
            }
        } else {
            let image = saveDrawingAsImage()
            return .capturedImage(image)
        }
    }
}
