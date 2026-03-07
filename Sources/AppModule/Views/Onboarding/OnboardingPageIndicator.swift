import SwiftUI

/// オンボーディング画面用のページインジケーター
struct OnboardingPageIndicator: View {
    let totalPages: Int
    let currentPage: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                if index == currentPage {
                    // アクティブ: 白いカプセル
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 24, height: 8)
                } else {
                    // 非アクティブ: 白40%の丸
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .animation(.spring(response: 0.3), value: currentPage)
    }
}
