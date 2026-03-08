import SwiftUI
import UIKit

private struct TitleBackgroundModifier: ViewModifier {
    let scale: CGFloat

    func body(content: Content) -> some View {
        ZStack {
            TitleBackgroundImage()
                .scaleEffect(scale)
            content
        }
    }
}

extension View {
    func titleBackground(scale: CGFloat = 1.0) -> some View {
        modifier(TitleBackgroundModifier(scale: scale))
    }
}

extension Image {
    static let titleBackground = Image.loadResource(
        named: "title_haikei",
        fileExtension: "png",
        subdirectory: "Image"
    )

    static let tatamiBackground = Image.loadResource(
        named: "tatami",
        fileExtension: "jpg",
        subdirectory: "Image"
    )

    static let onlyTatamiBackground = Image.loadResource(
        named: "onlytatami",
        fileExtension: "png",
        subdirectory: "Image"
    )

    static let woodBackground = Image.loadResource(
        named: "wood",
        fileExtension: "jpg",
        subdirectory: "Image"
    )

    static let hutiOverlay = Image.loadResource(
        named: "huti",
        fileExtension: "png",
        subdirectory: "Image"
    )

    static let darumaRed = Image.loadResource(
        named: "daruma_red",
        fileExtension: "png",
        subdirectory: "Image"
    )

    static let darumas = Image.loadResource(
        named: "darumas",
        fileExtension: "png",
        subdirectory: "Image"
    )

    private static func loadResource(
        named name: String,
        fileExtension: String,
        subdirectory: String? = nil
    ) -> Image {
        let bundles: [Bundle] = [.module, .main]

        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: fileExtension, subdirectory: subdirectory),
           let uiImage = UIImage(contentsOfFile: url.path) {
                return Image(uiImage: uiImage)
            }
        }

        return Image(systemName: "photo")
    }
}
