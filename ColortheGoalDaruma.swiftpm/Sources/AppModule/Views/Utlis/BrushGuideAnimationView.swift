import SwiftUI

/// 筆で書くアニメーションをガイドとして表示するオーバーレイ
struct BrushGuideAnimationView: View {
    var onDismiss: () -> Void

    @State private var opacity: Double = 1.0
    @State private var hasScheduledAutoDismiss = false

    var body: some View {
        ZStack {
            // 半透明の背景
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                animationContent
            }
        }
        .opacity(opacity)
        .contentShape(Rectangle())
        .onTapGesture {
            dismissWithAnimation()
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.6)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onDismiss()
        }
    }

    @ViewBuilder
    private var animationContent: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let progress = (t.truncatingRemainder(dividingBy: 2.0)) / 2.0

                let centerX = size.width / 2
                let centerY = size.height / 2
                let radius: CGFloat = 80

                // 円弧状にペンアイコンを移動させて「書く動作」を表現
                let angle = progress * 2 * .pi - .pi / 2
                let iconX = centerX + cos(angle) * radius * 0.5
                let iconY = centerY + sin(angle) * radius * 0.5

                // 軌跡を描画
                var path = Path()
                for i in 0..<60 {
                    let p = Double(i) / 60.0
                    if p > progress { break }
                    let a = p * 2 * .pi - .pi / 2
                    let x = centerX + cos(a) * radius * 0.5
                    let y = centerY + sin(a) * radius * 0.5
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(path, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                // ペンアイコンを現在位置に描画
                let image = context.resolveSymbol(id: "pencil")
                if let image {
                    context.draw(image, at: CGPoint(x: iconX, y: iconY))
                }
            } symbols: {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(.white)
                    .tag("pencil")
            }
        }
        .frame(width: 320, height: 320)
    }
}
