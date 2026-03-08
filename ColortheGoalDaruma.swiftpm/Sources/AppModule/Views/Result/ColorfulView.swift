import SwiftUI

/// Local replacement for the removed `Colorful` dependency.
/// Provides a softly animated angular gradient that cycles
/// through the supplied colors.
struct ColorfulView: View {
    var colors: [Color]
    var colorCount: Int = 8

    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1

    private var gradientColors: [Color] {
        let minimumCount = max(3, colorCount)
        let source = colors.isEmpty ? Self.defaultPalette : colors

        if source.count >= minimumCount {
            return Array(source.prefix(minimumCount))
        }

        var repeated = source
        while repeated.count < minimumCount {
            repeated.append(contentsOf: source)
        }
        return Array(repeated.prefix(minimumCount))
    }

    var body: some View {
        AngularGradient(
            gradient: Gradient(colors: gradientColors + [gradientColors.first ?? .white]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
        .rotationEffect(.degrees(rotation))
        .scaleEffect(scale)
        .blur(radius: 80)
        .saturation(1.15)
        .ignoresSafeArea()
        .drawingGroup()
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                scale = 1.1
            }
        }
    }

    private static let defaultPalette: [Color] = [
        .pink, .orange, .yellow, .green, .mint, .blue, .purple, .red
    ]
}
