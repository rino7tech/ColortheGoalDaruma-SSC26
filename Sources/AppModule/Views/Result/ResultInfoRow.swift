import SwiftUI

struct ResultInfoRow: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // タイトル
            Text(title)
                .font(.shiranui(.subheadline))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            // コンテンツ
            MarkdownText(text: text)
                .font(.shiranui(.body))
                .foregroundColor(.primary)
                .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
