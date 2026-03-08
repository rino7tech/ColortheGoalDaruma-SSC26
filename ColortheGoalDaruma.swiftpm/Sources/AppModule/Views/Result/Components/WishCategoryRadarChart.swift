import SwiftUI

/// レーダーチャートで願いのカテゴリバランスを表示
struct WishCategoryRadarChart: View {
    let categoryScores: [WishCategory: Double]

    private var orderedCategories: [WishCategory] {
        WishCategory.allCases
    }

    private var normalizedValues: [Double] {
        let maxScore = categoryScores.values.max() ?? 1
        guard maxScore > 0 else { return Array(repeating: 0, count: orderedCategories.count) }
        return orderedCategories.map { min(1.0, (categoryScores[$0] ?? 0) / maxScore) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wish balance")
                    .font(.shiranui(.title3))
                Text("Each area shows how much focus every category receives.")
                    .font(.shiranui(.caption))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack {
                    ringGrid(in: proxy.size)
                    radarShape(in: proxy.size)
                    spokes(in: proxy.size)
                }
            }
            .frame(height: 260)

            labelsRow
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func ringGrid(in size: CGSize) -> some View {
        let rings = 4
        return ForEach(0...rings, id: \.self) { index in
            let fraction = CGFloat(index) / CGFloat(rings)
            Circle()
                .stroke(Color.primary.opacity(index == rings ? 0.25 : 0.12), lineWidth: index == rings ? 1.4 : 1)
                .frame(width: size.width * fraction, height: size.height * fraction)
                .position(x: size.width / 2, y: size.height / 2)
        }
    }

    private func spokes(in size: CGSize) -> some View {
        let count = orderedCategories.count
        return ForEach(0..<count, id: \.self) { index in
            Path { path in
                path.move(to: CGPoint(x: size.width / 2, y: size.height / 2))
                let angle = angleForIndex(index, total: count)
                let end = point(at: 1.0, angle: angle, in: size)
                path.addLine(to: end)
            }
            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }

    private func radarShape(in size: CGSize) -> some View {
        let points = normalizedValues.enumerated().map { index, value -> CGPoint in
            let angle = angleForIndex(index, total: normalizedValues.count)
            return point(at: value, angle: angle, in: size)
        }

        return ZStack {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.4), Color.accentColor.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                path.closeSubpath()
            }
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private func point(at value: Double, angle: Double, in size: CGSize) -> CGPoint {
        let radius = min(size.width, size.height) / 2
        let adjustedRadius = radius * CGFloat(value) * 0.9
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * adjustedRadius,
            y: center.y + CGFloat(sin(angle)) * adjustedRadius
        )
    }

    private func angleForIndex(_ index: Int, total: Int) -> Double {
        let step = (2 * Double.pi) / Double(total)
        return -Double.pi / 2 + step * Double(index)
    }

    private var labelsRow: some View {
        let snapshots = normalizedValues.enumerated().map { (index, value) -> (WishCategory, Int) in
            (orderedCategories[index], Int((value * 100).rounded()))
        }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(snapshots, id: \.0) { entry in
                HStack {
                    Capsule()
                        .fill(Color.accentColor.opacity(Double(entry.1) / 120.0 + 0.2))
                        .frame(width: 10, height: 10)
                    Text(entry.0.label)
                        .font(.shiranui(.caption))
                    Spacer()
                    Text("\(entry.1)%")
                        .font(.shiranui(.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
