import SwiftUI

/// スプラッシュ画面のオンボーディング（3ページスワイプ形式）
struct SplashOnboardingView: View {
    let onStart: () -> Void

    var body: some View {
        PagedGuideOverlay(
            overlayOpacity: 0.8,
            pageHeight: 420,
            usesSystemPageIndicator: false,
            enablesVerticalSwipePaging: true,
            showsCTAOnlyOnLastPage: true,
            pages: [
                AnyView(page1),
                AnyView(page2),
                AnyView(page3)
            ],
            indicator: { currentPage in
                AnyView(
                    OnboardingPageIndicator(totalPages: 3, currentPage: currentPage)
                )
            },
            cta: AnyView(
                Button(action: {
                    SoundPlayer.shared.playSelect()
                    onStart()
                }) {
                    Text("Start Diagnosis")
                        .font(.shiranui(size: 20))
                        .foregroundColor(Color.customRed)
                        .frame(maxWidth: 320)
                        .frame(height: 60)
                        .background(Color.white)
                        .cornerRadius(40)
                }
                .buttonStyle(.plain)
            )
        )
    }

    // MARK: - ページ1: だるまと儀式の体験
    private var page1: some View {
        VStack(spacing: 24) {
            Spacer()

            // だるまアイコン
            Image.darumaRed
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)

            Text("Experience the Daruma Wish Ritual")
                .font(.shiranui(size: 36))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Darumas are traditional Japanese lucky charms, completed by drawing in the eyes with a wish.\nThis app lets you experience the full Daruma ritual.")
                .font(.shiranui(size: 16))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - ページ2: 目標設定のサポート
    private var page2: some View {
        VStack(spacing: 24) {
            Spacer()

            // だるま画像
            Image.darumas
                .resizable()
                .scaledToFit()
                .frame(width: 240, height: 120)

            Text("We Help You Put Your Goals into Words")
                .font(.shiranui(size: 36))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Reflect on what you want most right now, and shape it into a clear wish.\nIt's okay if your goal is still a little vague.")
                .font(.shiranui(size: 16))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - ページ3: 診断の進め方
    private var page3: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text("Answer Daruma's Questions to Find Your Color")
                .font(.shiranui(size: 36))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Daruma will ask you questions in chat.\nBased on your answers, you'll get the Daruma color that fits you best.")
                .font(.shiranui(size: 18))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - だるまカラーチップ
    private var darumaColorChips: some View {
        let colors: [DarumaColor] = [.red, .blue, .green, .pink, .yellow, .purple, .gold, .orange]
        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                ForEach(colors.prefix(4), id: \.self) { color in
                    miniDarumaChip(color: color)
                }
            }
            HStack(spacing: 16) {
                ForEach(colors.suffix(4), id: \.self) { color in
                    miniDarumaChip(color: color)
                }
            }
        }
    }

    private func miniDarumaChip(color: DarumaColor) -> some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(
                    colors: color.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 44, height: 50)

            // 顔の白い部分
            Ellipse()
                .fill(Color.white.opacity(0.85))
                .frame(width: 24, height: 20)
                .offset(y: -6)

            // 目
            HStack(spacing: 6) {
                Circle().fill(Color.black).frame(width: 4, height: 4)
                Circle().fill(Color.black).frame(width: 4, height: 4)
            }
            .offset(y: -6)
        }
        .shadow(color: color.gradient.first?.opacity(0.4) ?? .clear, radius: 6, x: 0, y: 3)
    }
}
