import SwiftUI
import UIKit

struct ResultView: View {
    let result: DarumaResult
    var onRestart: () -> Void
    var onNext: () -> Void
    var nextButtonTitle: String = "Next"
    @State private var darumaViewModel = DarumaSceneViewModel()

    var body: some View {
        ZStack {
            backgroundView
            glassBackdrop
            resultOverlayImage

            VStack(spacing: 24) {
                controlBar

                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 20) {
                        headerBlock

                        // だるま表示（shadow削除）
                        DarumaSceneView(viewModel: darumaViewModel)
                            .frame(height: 620)
                            .background(darumaStage)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)

                    resultPanel
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(EdgeInsets(top: 24, leading: 32, bottom: 32, trailing: 32))
        }
        .onAppear {
            let scores: [DarumaColor: Double] = [result.color: 1.0]
            darumaViewModel.updateScores(scores)
            darumaViewModel.wishImage = nil
        }
    }

    private var controlBar: some View {
        HStack {
            Button(action: {
                SoundPlayer.shared.playSelect()
                onRestart()
            }) {
                controlButton(symbol: "xmark", color: .red)
            }
            .accessibilityLabel("Restart from the beginning")

            Spacer()

            Text("DARUMA READING")
                .font(.shiranui(size: 12))
                .tracking(2.2)
                .foregroundStyle(.primary.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )

            Spacer()

            Button(action: {
                SoundPlayer.shared.playSelect()
                onNext()
            }) {
                controlButton(symbol: "checkmark", color: .green)
            }
            .accessibilityLabel(nextButtonTitle)
        }
    }

    private func controlButton(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.shiranui(size: 18))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(color, in: Circle())
            .shadow(color: color.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    /// 統合された結果カード
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionCard(title: "Wish", subtitle: "Your intention") {
                Text(result.wishSummary)
                    .font(.shiranui(size: 26))
                    .foregroundStyle(.primary)
            }

            sectionCard(title: "Daruma Word", subtitle: "The oracle speaks") {
                Text(result.darumaWord)
                    .font(.shiranui(size: 20))
                    .foregroundStyle(.primary)
            }

            sectionCard(title: "Current State", subtitle: "What surrounds you") {
                Text(result.currentAnalysis)
                    .font(.shiranui(size: 15))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineSpacing(4)
            }

            sectionCard(title: "Next Steps", subtitle: "Where to step") {
                Text(result.futureGuidance)
                    .font(.shiranui(size: 15))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineSpacing(4)
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Result")
                .font(.shiranui(size: 12))
                .tracking(2.4)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(colors: result.color.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.color.title)
                        .font(.shiranui(size: 30))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .layoutPriority(1)
                    Text(result.color.focusKeyword.uppercased())
                        .font(.shiranui(size: 11))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(result.color.meaning)
                .font(.shiranui(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var darumaStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func sectionCard(title: String, subtitle: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 16) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LinearGradient(colors: result.color.gradient, startPoint: .top, endPoint: .bottom))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.shiranui(size: 14))
                        .foregroundStyle(.secondary)
                    Text(subtitle)
                        .font(.shiranui(size: 12))
                        .foregroundStyle(.secondary.opacity(0.8))
                }

                content()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var resultPanel: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reading Detail")
                        .font(.shiranui(size: 14))
                        .foregroundStyle(.primary.opacity(0.85))
                    Text(result.color.focusKeyword.uppercased())
                        .font(.shiranui(size: 11))
                        .tracking(2.0)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    resultCard
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 12)
    }

    private var backgroundView: some View {
        ZStack {
            // Colorfulライブラリ：派手に、早く
            ColorfulView(
                colors: result.color.gradient + [.white, result.color.gradient.first ?? .red],
                colorCount: 8
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.clear,
                    Color.black.opacity(0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(result.color.gradient.first?.opacity(0.4) ?? Color.white.opacity(0.3))
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: -180, y: -220)

            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 360, height: 360)
                .blur(radius: 140)
                .offset(x: 200, y: 260)
        }
    }

    private var resultOverlayImage: some View {
        VStack {
            Image("huti")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320)
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
            Spacer()
        }
        .padding(.top, 12)
        .allowsHitTesting(false)
    }

    private var glassBackdrop: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()
    }
}
