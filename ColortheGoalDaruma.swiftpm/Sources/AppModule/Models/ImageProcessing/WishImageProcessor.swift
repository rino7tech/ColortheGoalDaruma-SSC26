import UIKit

enum WishImageProcessor {
    /// Converts a white-background drawing into a transparent image by removing bright pixels.
    static func transparentWishImage(from image: UIImage?) -> UIImage? {
        guard let image = image else { return nil }
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let dataCount = bytesPerRow * height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let dataPointer = context.data else { return image }
        let pixels = dataPointer.bindMemory(to: UInt8.self, capacity: dataCount)

        for index in stride(from: 0, to: dataCount, by: bytesPerPixel) {
            let r = pixels[index]
            let g = pixels[index + 1]
            let b = pixels[index + 2]

            // Calculate perceived brightness (0...1)
            let brightness = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255.0

            let alpha: Double
            if brightness >= 0.97 {
                alpha = 0.0
            } else if brightness >= 0.85 {
                // Smoothly fade near-white pixels
                alpha = max(0.0, min(1.0, (0.97 - brightness) / 0.12))
            } else {
                alpha = 1.0
            }

            let clampedAlpha = max(0.0, min(1.0, alpha))
            let alphaByte = UInt8((clampedAlpha * 255.0).rounded())
            pixels[index + 3] = alphaByte

            if alphaByte == 0 {
                pixels[index] = 0
                pixels[index + 1] = 0
                pixels[index + 2] = 0
            } else {
                pixels[index] = WishImageProcessor.premultipliedComponent(r, alpha: clampedAlpha)
                pixels[index + 1] = WishImageProcessor.premultipliedComponent(g, alpha: clampedAlpha)
                pixels[index + 2] = WishImageProcessor.premultipliedComponent(b, alpha: clampedAlpha)
            }
        }

        guard let outputCGImage = context.makeImage() else { return image }
        let transparent = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
        let squared = centeredSquareImage(from: transparent) ?? transparent
        return horizontallyMirroredImage(from: squared) ?? squared
    }

    private static func premultipliedComponent(_ value: UInt8, alpha: Double) -> UInt8 {
        let scaled = Double(value) * alpha
        return UInt8(max(0, min(255, Int(scaled.rounded()))))
    }

    private static func centeredSquareImage(from image: UIImage) -> UIImage? {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > 0 else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: maxSide, height: maxSide), format: format)
        return renderer.image { context in
            context.cgContext.clear(CGRect(origin: .zero, size: CGSize(width: maxSide, height: maxSide)))
            let origin = CGPoint(
                x: (maxSide - image.size.width) / 2,
                y: (maxSide - image.size.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: image.size))
        }
    }

    private static func horizontallyMirroredImage(from image: UIImage) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            context.cgContext.translateBy(x: image.size.width, y: image.size.height)
            context.cgContext.scaleBy(x: -1, y: -1)
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
