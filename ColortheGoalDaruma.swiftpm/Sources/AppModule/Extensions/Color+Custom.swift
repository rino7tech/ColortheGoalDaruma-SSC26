import SwiftUI
import UIKit

extension UIColor {
    static let customRed = UIColor(
        red: CGFloat(0xFE) / 255,
        green: CGFloat(0x6E) / 255,
        blue: CGFloat(0x6E) / 255,
        alpha: 1.0
    )

    static let progressRed = UIColor(
        red: CGFloat(0xB7) / 255,
        green: CGFloat(0x30) / 255,
        blue: CGFloat(0x25) / 255,
        alpha: 1.0
    )
}

extension Color {
    static let customRed = Color(UIColor.customRed)
    static let progressRed = Color(UIColor.progressRed)
}
