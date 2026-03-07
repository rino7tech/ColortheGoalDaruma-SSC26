import SwiftUI
import UIKit

struct DarumaGuideBubble<Content: View>: View {
    var minHeight: CGFloat = 190
    var maxWidth: CGFloat = 980
    var horizontalPadding: CGFloat = 32
    var verticalPadding: CGFloat = 44
    var bubbleOpacity: Double = 0.88
    var showsTail: Bool = true
    var tailHeight: CGFloat = 92
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: showsTail ? 10 : 0) {
            content()
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: maxWidth)
                .frame(minHeight: minHeight)
                .background(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(.white.opacity(bubbleOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(Color.black.opacity(0.16), lineWidth: 2)
                )

            if showsTail, let bubbleImage = darumaGuideBubbleDecorationImage {
                bubbleImage
                    .resizable()
                    .scaledToFit()
                    .frame(height: tailHeight)
                    .offset(x: -70, y: 14)
            }
        }
    }
}

private let darumaGuideBubbleDecorationImage: Image? = {
    let bundle = Bundle.main
    guard let url = bundle.url(forResource: "bubble", withExtension: "png", subdirectory: "Image"),
          let uiImage = UIImage(contentsOfFile: url.path) else {
        return nil
    }
    return Image(uiImage: uiImage)
}()

