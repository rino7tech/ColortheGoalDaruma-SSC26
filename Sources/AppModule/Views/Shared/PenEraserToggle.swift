import SwiftUI

/// ペン・消しゴムを切り替えるセグメントコントロール風UI
struct PenEraserToggle: View {
    @Binding var isErasing: Bool

    var body: some View {
        HStack(spacing: 0) {
            // ペンボタン
            Button {
                SoundPlayer.shared.playSelect()
                isErasing = false
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.tip")
                        .font(.shiranui(size: 18))
                    Text("Pen")
                        .font(.shiranui(size: 15))
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(!isErasing ? Color.white.opacity(0.9) : Color.clear)
                .foregroundStyle(!isErasing ? Color.black : Color.white.opacity(0.7))
            }
            .buttonStyle(.plain)

            // 消しゴムボタン
            Button {
                SoundPlayer.shared.playSelect()
                isErasing = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eraser")
                        .font(.shiranui(size: 18))
                    Text("Eraser")
                        .font(.shiranui(size: 15))
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(isErasing ? Color.white.opacity(0.9) : Color.clear)
                .foregroundStyle(isErasing ? Color.black : Color.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
        .animation(.easeInOut(duration: 0.2), value: isErasing)
    }
}
