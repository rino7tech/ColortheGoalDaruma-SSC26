import SwiftUI
import SceneKit

/// だるま詳細画面（だるまの情報を左右に配置し、中央にSceneKitだるまを表示）
struct DarumaDetailView: View {
    let result: DarumaResult
    var onRestart: () -> Void
    var onNext: () -> Void
    var nextButtonTitle: String = "NextStep"

    @State private var viewModel: DarumaDetailViewModel?
    @State private var sceneViewModel = DarumaSceneViewModel()
    @State private var hasEntered = false

    var body: some View {
        ZStack {
            // 白背景
            ColorfulView(
                colors: result.color.gradient + [.white, result.color.gradient.first ?? .red],
                colorCount: 8
            )
            .ignoresSafeArea()
            Rectangle()
                .fill(.ultraThinMaterial)
                .cornerRadius(25)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 5)
                .padding(.horizontal, 30)


            if let vm = viewModel {
                ZStack {
                    centerContent(vm: vm)
                        .offset(y:70)
                        .opacity(hasEntered ? 1 : 0)
                        .scaleEffect(hasEntered ? 1 : 0.985)
                        .blur(radius: hasEntered ? 0 : 7)
                        .animation(.spring(response: 0.65, dampingFraction: 0.88).delay(0.08), value: hasEntered)
                    VStack {

                        // 上部ヘッダー
                        headerSection(vm: vm)
                            .padding(.top, 80)
                            .opacity(hasEntered ? 1 : 0)
                            .offset(y: hasEntered ? 0 : -24)
                            .animation(.easeOut(duration: 0.45).delay(0.02), value: hasEntered)
                           Spacer()
                        bottomBar
                            .padding(.horizontal, 48)
                            .padding(.bottom, 35)
                            .opacity(hasEntered ? 1 : 0)
                            .offset(y: hasEntered ? 0 : 18)
                            .animation(.easeOut(duration: 0.45).delay(0.16), value: hasEntered)

                    }
                }
            }
        }
        .overlay(alignment: .center) {
            Image.hutiOverlay
                .renderingMode(.template)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(1.16)
                .foregroundStyle(accentColor)
                .allowsHitTesting(false)
        }
        .onAppear {
            let vm = DarumaDetailViewModel(result: result)
            viewModel = vm
            let scores: [DarumaColor: Double] = [result.color: 1.0]
            sceneViewModel.updateScores(scores)
            sceneViewModel.enableAutoRotation = true
            sceneViewModel.wishImage = nil
            hasEntered = false
            DispatchQueue.main.async {
                hasEntered = true
            }
        }
        .onDisappear {
            hasEntered = false
        }
    }

    // MARK: - ヘッダーセクション

    /// 上部のタイトル表示
    private func headerSection(vm: DarumaDetailViewModel) -> some View {
        VStack(spacing: 8) {
            // だるまのタイトル（赤文字）
            Text(vm.darumaTitle)
                .font(.shiranui(size: 40))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .shadow(color: accentColor.opacity(1), radius: 0, x: 1, y: 0)
                .shadow(color: accentColor.opacity(1), radius: 0, x: -1, y: 0)
                .shadow(color: accentColor.opacity(1), radius: 0, x: 0, y: 1)
                .shadow(color: accentColor.opacity(1), radius: 0, x: 0, y: -1)
                .shadow(color: accentColor.opacity(1), radius: 2, x: 0, y: 0)
                .shadow(color: accentColor.opacity(1), radius: 1, x: 0, y: 0)
                .shadow(color: accentColor.opacity(1), radius: 18, x: 0, y: 0)
                .shadow(color: accentColor.opacity(1), radius: 6, x: 0, y: 0)

            // だるまの言葉（黒太字）
            Text(vm.subtitle)
                .font(.shiranui(size: 45))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .frame(width: 1000)
                .padding(.horizontal, 80)
        }
    }

    // MARK: - 中央3カラムレイアウト

    /// 左テキスト + 中央だるま + 右テキスト
    private func centerContent(vm: DarumaDetailViewModel) -> some View {
        ZStack {
            DarumaSceneView(viewModel: sceneViewModel)
                .frame(width: 800, height: 850)
            HStack {
                leftColumn(vm: vm)
                    .padding(.leading, 80)
                Spacer()
                rightColumn(vm: vm)
            }
            .offset(y:-50)
        }
    }

    /// 左カラム（Current Stage + KeyWord）
    private func leftColumn(vm: DarumaDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 102) {
            // Current Stage セクション
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Stage")
                    .font(.shiranui(size: 40))
                    .foregroundStyle(.black)

                Text(vm.currentStageText)
                    .font(.shiranui(size: 30))
                    .lineSpacing(4)
                    .frame(maxWidth: 350, alignment: .leading)
            }
            .offset(x:30)

            // KeyWord セクション
            VStack(alignment: .leading, spacing: 8) {
                Text("KeyWord")
                    .font(.shiranui(size: 40))
                    .foregroundStyle(.black)

                Text(vm.keyword)
                    .font(.shiranui(size: 30))
                    .padding(.leading, 20)
            }
            .padding(.leading, 120)
        }
    }

    /// 右カラム（NextStep）
    private func rightColumn(vm: DarumaDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 92) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Next Action")
                    .font(.shiranui(size: 40))
                    .foregroundStyle(.black)

                Text(vm.nextStepText)
                    .font(.shiranui(size: 30))
                    .lineSpacing(4)
                    .frame(maxWidth: 350, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("StopDoing")
                    .font(.shiranui(size: 40))
                    .foregroundStyle(.black)

                Text(vm.dontdoingText)
                    .font(.shiranui(size: 30))
                    .lineSpacing(4)
                    .frame(maxWidth: 350, alignment: .leading)
            }
            .offset(x: 20, y: -30)
        }
        .offset(x: -120, y: -20)
    }

    // MARK: - 下部バー

    /// 左にリスタートボタン、右にNextStepボタン
    private var bottomBar: some View {
        HStack {
            Spacer()

            // NextStepボタン
            Button(action: {
                SoundPlayer.shared.playSelect()
                onNext()
            }) {
                HStack(spacing: 12) {
                    Text(nextButtonTitle)
                        .font(.shiranui(size: 25))

                    Image(systemName: "arrow.right")
                        .font(.shiranui(size: 25))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(accentColor)
                )
            }
        }
    }
    private var accentColor: Color {
        let base = result.color.gradient.first ?? .red
        // 白や明るすぎる色の場合はグレーにフォールバック
        if result.color == .white {
            return Color.gray
        }
        return base
    }
}
