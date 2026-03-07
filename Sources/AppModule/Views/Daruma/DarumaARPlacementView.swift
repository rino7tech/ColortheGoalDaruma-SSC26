import SwiftUI

/// AR画面用の大きなだるまチップ
private struct DarumaChipLarge: View {
    let color: DarumaColor

    var body: some View {
        ZStack {
            // 本体（楕円）
            Ellipse()
                .fill(LinearGradient(
                    colors: color.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 56, height: 62)

            // 顔の部分（白い楕円）
            Ellipse()
                .fill(Color.white.opacity(0.9))
                .frame(width: 32, height: 26)
                .offset(y: -8)

            // 目（2つの点）
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.black)
                    .frame(width: 6, height: 6)
            }
            .offset(y: -8)
        }
        .shadow(color: color.gradient.first?.opacity(0.5) ?? .clear, radius: 8, x: 0, y: 4)
    }
}

struct DarumaARPlacementView: View {
    let color: DarumaColor
    let eyeImage: UIImage?
    let wishImage: UIImage?
    var onDrawRightEye: () -> Void
    var onReturnToTitle: () -> Void
    @State private var hasPlacedDaruma = false
    @State private var showPlacedCheckmark = false
    @State private var showWishMessage = false
    @State private var showActionButtons = false
    @State private var hasTriggeredAutoFinish = false
    @State private var showPlaneHint = false
    @State private var tapIconPulse = false
    @State private var planeHintDismissWorkItem: DispatchWorkItem?
    @State private var showARMeaningGuide = true

    var body: some View {
        ZStack {
            ARViewRepresentable(
                color: color,
                eyeImage: eyeImage,
                wishImage: wishImage,
                onPlacementChange: { placed in
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            hasPlacedDaruma = placed
                        }
                        if placed, !hasTriggeredAutoFinish {
                            hasTriggeredAutoFinish = true
                            showPlacedCheckmark = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    showPlacedCheckmark = false
                                }
                            }
                            // Show a wish message after placement (return is manual)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeIn(duration: 0.4)) {
                                    showWishMessage = true
                                }
                            }
                        }
                    }
                },
                onInvalidPlacementTap: {
                    DispatchQueue.main.async {
                        showInvalidPlaneHint()
                    }
                }
            )
            .ignoresSafeArea()

            if !hasPlacedDaruma && !showWishMessage && !showARMeaningGuide {
                VStack(spacing: 0) {
                    Spacer()
                    HStack {
                        Spacer()
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.white)
                        .scaleEffect(tapIconPulse ? 1.08 : 0.92)
                        .rotationEffect(.degrees(tapIconPulse ? -6 : 6))
                        .offset(y: tapIconPulse ? -6 : 6)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: tapIconPulse)
                        .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 4)
                        .padding(.trailing, 40)
                        .padding(.bottom, 86)
                    }
                }
                .transition(.opacity)
                .onAppear {
                    tapIconPulse = true
                }
            }

            if showPlaneHint && !hasPlacedDaruma && !showARMeaningGuide {
                VStack {
                    Text("Find a flat surface and tap.")
                        .font(.shiranui(size: 16))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.78))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    Spacer()
                }
                .padding(.top, 58)
                .transition(.opacity)
            }

            if showARMeaningGuide && !hasPlacedDaruma {
                PagedGuideOverlay(
                    overlayOpacity: 0.8,
                    pageHeight: 340,
                    widthPadding: 40,
                    minWidth: 280,
                    maxWidth: 720,
                    verticalSpacing: 18,
                    usesSystemPageIndicator: false,
                    showsCTAOnlyOnLastPage: true,
                    pages: [
                        AnyView(
                            VStack(spacing: 22) {
                                Spacer()

                                Image(systemName: "eye.fill")
                                    .font(.system(size: 54, weight: .semibold))
                                    .foregroundStyle(Color.customRed)

                                Text("Place It Where You Can See It")
                                    .font(.shiranui(size: 32))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)

                                Text("Placing your Daruma in a visible spot helps keep your goal in sight and strengthens your daily focus.")
                                    .font(.shiranui(size: 17))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)

                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        )
                    ],
                    cta: AnyView(
                        Button(action: {
                            SoundPlayer.shared.playSelect()
                            withAnimation(.easeOut(duration: 0.25)) {
                                showARMeaningGuide = false
                            }
                        }) {
                            Text("Start AR Placement")
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
                .transition(.opacity)
                .zIndex(30)
            }

            // 願いメッセージ（タップで次へ）
            if showWishMessage {
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            SoundPlayer.shared.playSelect()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showWishMessage = false
                                showActionButtons = true
                            }
                        }

                    VStack(spacing: 18) {
                        Text("May your wish come true!")
                            .font(.shiranui(size: 28))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)

                        HStack(spacing: 8) {
                            Text("Tap to continue")
                                .font(.shiranui(size: 18))
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.92))
                    }
                }
                .padding(.horizontal, 20)
                .transition(.opacity)
            }

            // アクション選択
            if showActionButtons {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Has your wish come true?")
                            .font(.shiranui(size: 30))
                            .foregroundStyle(.white)
                        Text("If it has, let's draw the right eye too.")
                            .font(.shiranui(size: 20))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)

                    Button(action: {
                        SoundPlayer.shared.playSelect()
                        onDrawRightEye()
                    }) {
                        Text("Draw the Right Eye")
                            .font(.shiranui(size: 20))
                            .foregroundColor(Color.customRed)
                            .frame(maxWidth: 320)
                            .frame(height: 60)
                            .background(Color.white)
                            .cornerRadius(40)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        SoundPlayer.shared.playSelect()
                        onReturnToTitle()
                    }) {
                        Text("Return to Title")
                            .font(.shiranui(size: 18))
                            .foregroundStyle(.white)
                            .frame(maxWidth: 320)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .transition(.opacity)
            }

            // 中央: 配置成功インジケーター
            if showPlacedCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .font(.shiranui(size: 72))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showPlacedCheckmark)
                    .transition(.scale.combined(with: .opacity))
            }

        }
        .foregroundColor(.white)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: hasPlacedDaruma)
    }

    private func showInvalidPlaneHint() {
        planeHintDismissWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            showPlaneHint = true
        }
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.25)) {
                showPlaneHint = false
            }
        }
        planeHintDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: workItem)
    }
}
