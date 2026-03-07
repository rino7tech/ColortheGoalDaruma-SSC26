import SwiftUI

/// 願い事書き+目入れの統合説明画面（4ページスワイプ形式、動画あり）
struct RitualOnboardingView: View {
    let darumaColor: DarumaColor
    let onStart: () -> Void
    @State private var currentPage = 0
    @State private var sceneViewModel1 = DarumaSceneViewModel()
    @State private var sceneViewModel2 = DarumaSceneViewModel()

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [.black, Color(red: 0.15, green: 0.08, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ページコンテンツ
                TabView(selection: $currentPage) {
                    page1.tag(0)
                    page2.tag(1)
                    page3.tag(2)
                    page4.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // カスタムページインジケーター
                OnboardingPageIndicator(totalPages: 4, currentPage: currentPage)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            setupSceneViewModels()
        }
    }

    // MARK: - ページ1: だるまの儀式
    private var page1: some View {
        VStack(spacing: 20) {
            // だるま3D表示
            DarumaSceneView(viewModel: sceneViewModel1, showsBottomStaticView: false)
                .frame(height: 280)
                .allowsHitTesting(false)

            Text("The Daruma Ritual")
                .font(.shiranui(size: 32))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Daruma have a traditional ritual for making a wish.\nNext, you'll experience it in two steps.")
                .font(.shiranui(size: 16))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 40)
    }

    // MARK: - ページ2: 願いを書く
    private var page2: some View {
        VStack(spacing: 20) {
            // だるまの底面表示
            DarumaSceneView(viewModel: sceneViewModel2, showsBottomStaticView: true)
                .frame(height: 280)
                .allowsHitTesting(false)

            Text("Write Your Wish")
                .font(.shiranui(size: 32))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("First, write your wish on the back of the Daruma.\nPut your intention into words with care.")
                .font(.shiranui(size: 16))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 40)
    }

    // MARK: - ページ3: 左目に想いを込めて（動画）
    private var page3: some View {
        VStack(spacing: 20) {
            // 動画プレイヤー
            VideoPlayerView(resourceName: "daruma_hidari", fileExtension: "mov")
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

            Text("Put Your Intention in the Left Eye")
                .font(.shiranui(size: 32))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Here, you'll begin by drawing the left eye\nwhile focusing on your wish.")
                .font(.shiranui(size: 16))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 40)
    }

    // MARK: - ページ4: やってみよう！
    private var page4: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hand.draw.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text("Let's Do It!")
                .font(.shiranui(size: 32))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("First write your wish,\nthen draw the left eye!")
                .font(.shiranui(size: 18))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // CTAボタン
            Button(action: {
                SoundPlayer.shared.playSelect()
                onStart()
            }) {
                Text("Start")
                    .font(.shiranui(size: 20))
                    .foregroundColor(Color.customRed)
                    .frame(maxWidth: 320)
                    .frame(height: 60)
                    .background(Color.white)
                    .cornerRadius(40)
            }
            .padding(.top, 16)

            Spacer()
        }
    }

    // MARK: - セットアップ
    private func setupSceneViewModels() {
        // ページ1用: 診断された色のだるまを正面表示
        var scores1: [DarumaColor: Double] = [:]
        for color in DarumaColor.allCases {
            scores1[color] = (color == darumaColor) ? 1.0 : 0.0
        }
        sceneViewModel1.currentScores = scores1
        sceneViewModel1.targetScores = scores1
        sceneViewModel1.scoreTransitionProgress = 1.0

        // ページ2用: 底面表示用
        var scores2: [DarumaColor: Double] = [:]
        for color in DarumaColor.allCases {
            scores2[color] = (color == darumaColor) ? 1.0 : 0.0
        }
        sceneViewModel2.currentScores = scores2
        sceneViewModel2.targetScores = scores2
        sceneViewModel2.scoreTransitionProgress = 1.0
    }
}
