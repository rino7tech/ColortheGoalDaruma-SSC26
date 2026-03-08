import SwiftUI
import SceneKit
import Metal

/// アプリ起動時のスプラッシュ画面（液体滴り落ちアニメーション）
struct StartingView: View {
    @Bindable var viewModel: StartingViewModel
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // 背景色
            LinearGradient(
                colors: [Color.white, Color.red.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 3Dだるまシーン
            StartingSceneViewWrapper(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // デバッグ用テキスト
            VStack {
                Spacer()
                Text("Loading... \(Int(viewModel.fillProgress * 100))%")
                    .font(.shiranui(.caption))
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .onAppear {
            print("👀 StartingView appeared")
            viewModel.startAnimation()
        }
        .onChange(of: viewModel.isAnimationComplete) { _, isComplete in
            print("🔄 Animation complete changed: \(isComplete)")
            if isComplete {
                // 0.5秒待ってから次の画面へ遷移
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}
