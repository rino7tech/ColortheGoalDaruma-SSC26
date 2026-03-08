import CoreText
import SwiftUI
import UIKit

enum FontRegistration {
    static func registerShiranuiIfNeeded() {
        guard let url = Bundle.main.url(forResource: "YujiSyuku-Regular", withExtension: "ttf", subdirectory: "Fonts") else {
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Font {
    static func shiranui(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        let base = UIFont(name: "YujiSyuku-Regular", size: size) ?? UIFont.systemFont(ofSize: size)
        let boldDescriptor = base.fontDescriptor.withSymbolicTraits(.traitBold) ?? base.fontDescriptor
        let boldFont = UIFont(descriptor: boldDescriptor, size: size)
        return Font(boldFont)
    }

    static func shiranui(_ textStyle: Font.TextStyle) -> Font {
        let size = UIFont.preferredFont(forTextStyle: textStyle.uiFontTextStyle).pointSize
        return shiranui(size: size, relativeTo: textStyle)
    }
}

private extension Font.TextStyle {
    var uiFontTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle:
            return .largeTitle
        case .title:
            return .title1
        case .title2:
            return .title2
        case .title3:
            return .title3
        case .headline:
            return .headline
        case .subheadline:
            return .subheadline
        case .callout:
            return .callout
        case .caption:
            return .caption1
        case .caption2:
            return .caption2
        case .footnote:
            return .footnote
        case .body:
            return .body
        @unknown default:
            return .body
        }
    }
}
