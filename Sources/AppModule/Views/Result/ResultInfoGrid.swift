import SwiftUI

struct ResultInfoGrid: View {
    let items: [(title: String, text: String)]
    let isRegular: Bool

    var body: some View {
        if isRegular {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(items, id: \.title) { item in
                    ResultInfoRow(title: item.title, text: item.text)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(items, id: \.title) { item in
                    ResultInfoRow(title: item.title, text: item.text)
                }
            }
        }
    }
}
