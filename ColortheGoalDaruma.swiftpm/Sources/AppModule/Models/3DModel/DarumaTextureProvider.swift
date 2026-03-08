import Foundation
import SwiftUI
import UIKit

@MainActor
final class DarumaTextureProvider {
    static let shared = DarumaTextureProvider()

    private var tintedImageCache: [DarumaColor: UIImage] = [:]

    private init() {}

    func tintedImage(for color: DarumaColor) -> UIImage? {
        if let cached = tintedImageCache[color] {
            return cached
        }
        guard let baseTexture = loadBaseTexture(named: color.textureName) else {
            return nil
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0  // 2x resolution to reduce aliasing when mapped to 3D
        let renderer = UIGraphicsImageRenderer(size: baseTexture.size, format: format)
        let composed = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: baseTexture.size)
            drawGradient(for: color, in: ctx.cgContext, rect: rect)
            baseTexture.draw(in: rect)
        }
        tintedImageCache[color] = composed
        return composed
    }

    /// 左右両目の描画を合成したテクスチャを生成
    func tintedImageWithBothEyes(
        for color: DarumaColor,
        leftEyeImage: UIImage?,
        rightEyeImage: UIImage?
    ) -> UIImage? {
        guard let baseImage = tintedImage(for: color) else { return nil }
        guard leftEyeImage != nil || rightEyeImage != nil else { return baseImage }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        let renderer = UIGraphicsImageRenderer(size: baseImage.size, format: format)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: baseImage.size)
            baseImage.draw(in: rect)

            let eyeWidth = rect.width * 0.22
            let eyeHeight = rect.height * 0.22
            let eyeY = rect.midY - rect.height * 0.187

            // 左目（ユーザーから見て右側に配置）
            if let leftEye = leftEyeImage {
                let eyeX = rect.midX + rect.width * 0.12
                let eyeRect = CGRect(
                    x: eyeX - eyeWidth / 2,
                    y: eyeY - eyeHeight / 2,
                    width: eyeWidth,
                    height: eyeHeight
                )
                leftEye.draw(in: eyeRect, blendMode: .multiply, alpha: 1.0)
            }

            // 右目（ユーザーから見て左側に配置）
            if let rightEye = rightEyeImage {
                let eyeX = rect.midX - rect.width * 0.12
                let eyeRect = CGRect(
                    x: eyeX - eyeWidth / 2,
                    y: eyeY - eyeHeight / 2,
                    width: eyeWidth,
                    height: eyeHeight
                )
                rightEye.draw(in: eyeRect, blendMode: .multiply, alpha: 1.0)
            }
        }
    }

    /// 目の描画を合成したテクスチャを生成
    func tintedImageWithEye(for color: DarumaColor, eyeImage: UIImage?) -> UIImage? {
        guard let baseImage = tintedImage(for: color) else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        let renderer = UIGraphicsImageRenderer(size: baseImage.size, format: format)
        let composed = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: baseImage.size)

            // ベース画像を描画
            baseImage.draw(in: rect)

            // ARテクスチャ上の目合成位置を計算（左右反転版）
            if let eye = eyeImage {
                let eyeWidth = rect.width * 0.22
                let eyeHeight = rect.height * 0.22
                let eyeX = rect.midX + rect.width * 0.12
                let eyeY = rect.midY - rect.height * 0.187
                let eyeRect = CGRect(
                    x: eyeX - eyeWidth / 2,
                    y: eyeY - eyeHeight / 2,
                    width: eyeWidth,
                    height: eyeHeight
                )
                eye.draw(in: eyeRect, blendMode: .multiply, alpha: 1.0)
            }

        }

        return composed
    }

    private func drawGradient(for color: DarumaColor, in context: CGContext, rect: CGRect) {
        let colors = softenedGradientColors(for: color)
        if colors.count >= 2,
           let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil) {
            let start = CGPoint(x: rect.midX, y: rect.minY)
            let end = CGPoint(x: rect.midX, y: rect.maxY)
            context.drawLinearGradient(gradient, start: start, end: end, options: [])
        } else {
            UIColor(color.gradient.first ?? .white).withAlphaComponent(1.0).setFill()
            context.fill(rect)
        }
        applySoftGlow(in: context, rect: rect)
    }

    private func loadBaseTexture(named name: String) -> UIImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "3D"),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return UIImage(named: name)
    }
}

private extension DarumaTextureProvider {
    func softenedGradientColors(for color: DarumaColor) -> [CGColor] {
        let uiColors = color.gradient.map { UIColor($0).withAlphaComponent(1.0) }
        guard !uiColors.isEmpty else {
            return [UIColor(color.gradient.first ?? .white).withAlphaComponent(1.0).cgColor]
        }
        let average = uiColors.reduce((r: CGFloat(0), g: CGFloat(0), b: CGFloat(0), a: CGFloat(0))) { partial, color in
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (partial.r + r, partial.g + g, partial.b + b, partial.a + a)
        }
        let count = CGFloat(uiColors.count)
        let avgColor = UIColor(red: average.r / count, green: average.g / count, blue: average.b / count, alpha: average.a / count)
        return uiColors.map { $0.blended(with: avgColor, amount: 0.45).cgColor }
    }

    func applySoftGlow(in context: CGContext, rect: CGRect) {
        guard let glow = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [UIColor.white.withAlphaComponent(0.14).cgColor, UIColor.clear.cgColor] as CFArray,
            locations: [0.0, 1.0]
        ) else { return }
        context.saveGState()
        context.setBlendMode(.softLight)
        let center = CGPoint(x: rect.midX, y: rect.midY * 0.85)
        context.drawRadialGradient(
            glow,
            startCenter: center,
            startRadius: rect.width * 0.1,
            endCenter: center,
            endRadius: rect.width * 0.8,
            options: [.drawsAfterEndLocation]
        )
        context.restoreGState()
    }
}

private extension UIColor {
    func blended(with color: UIColor, amount: CGFloat) -> UIColor {
        let amount = max(0, min(1, amount))
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 * (1 - amount) + r2 * amount,
            green: g1 * (1 - amount) + g2 * amount,
            blue: b1 * (1 - amount) + b2 * amount,
            alpha: a1 * (1 - amount) + a2 * amount
        )
    }
}
