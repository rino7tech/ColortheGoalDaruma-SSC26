import SwiftUI

/// だるまコレクション一覧画面（3Dシーン版）
struct DarumaCollectionListView: View {
    let store: DarumaStore
    let onDismiss: () -> Void
    var onZoomStateChange: (Bool) -> Void = { _ in }

    @State private var collectionScene = DarumaCollectionScene()
    @State private var selectedDaruma: SavedDaruma?
    @State private var isZoomedIn: Bool = false
    @State private var isZoomTransitioning: Bool = false
    @State private var showBottomPanel: Bool = false
    @State private var showEyeDrawing: Bool = false
    @State private var showAchievement: Bool = false
    @State private var eyeDrawingViewModel = DarumaEyeDrawingViewModel()

    var body: some View {
        ZStack {
            // 畳背景（タイトル画面と同じ2層構造）
            Image.tatamiBackground
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blur(radius: 8)

            Color.black.opacity(0.15).ignoresSafeArea()

            if store.savedDarumas.isEmpty {
                emptyView
            } else {
                // 3DコレクションシーンView（背景透明）
                DarumaCollectionSceneView(scene: collectionScene) { tappedID in
                    guard !isZoomTransitioning else { return }
                    if let tappedID {
                        if isZoomedIn {
                            // ズーム中のだるまタップは現状維持（下部パネルは既に表示済み）
                        } else {
                            handleTap(id: tappedID)
                        }
                    } else if isZoomedIn {
                        handleBack()
                    }
                }
                .ignoresSafeArea()

                // 願いバブル（ズーム中は常時表示）
                if isZoomedIn, showBottomPanel, let daruma = selectedDaruma {
                    wishOverlay(for: daruma)
                }

                // 下部パネル（タップ時に表示）
                if showBottomPanel, let daruma = selectedDaruma {
                    bottomPanelOverlay(for: daruma)
                }
            }

            // ナビゲーションボタン（概観/ズームイン で切り替え）
            navigationButtons
        }
        .onAppear {
            collectionScene.loadDarumas(store.savedDarumas)
            collectionScene.setupOverviewCamera()
            onZoomStateChange(isZoomedIn)
        }
        .onChange(of: isZoomedIn) { _, newValue in
            onZoomStateChange(newValue)
        }
        .fullScreenCover(isPresented: $showEyeDrawing) {
            if let daruma = selectedDaruma {
                DarumaEyeDrawingView(
                    viewModel: eyeDrawingViewModel,
                    darumaColor: daruma.darumaColor,
                    eyeSide: .right,
                    onComplete: { image in
                        showEyeDrawing = false
                        store.fulfillWish(
                            id: daruma.id,
                            rightEyeImageData: image?.pngData()
                        )
                        // シーンを再ロードして右目を反映（カメラは動かさない）
                        collectionScene.loadDarumas(store.savedDarumas)
                        showAchievement = true
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showAchievement) {
            if let daruma = selectedDaruma,
               let updatedDaruma = store.savedDarumas.first(where: { $0.id == daruma.id }) {
                DarumaAchievementView(
                    daruma: updatedDaruma,
                    onViewCollection: {
                        showAchievement = false
                        handleBack()
                    },
                    onReturnToTitle: {
                        showAchievement = false
                        onDismiss()
                    }
                )
            }
        }
    }

    // MARK: - ナビゲーションボタン

    private var navigationButtons: some View {
        VStack {
            HStack {
                Spacer()

                if isZoomedIn {
                    Button(action: {
                        SoundPlayer.shared.playSelect()
                        handleBack()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 24)
                    .disabled(isZoomTransitioning)
                }
            }
            .padding(.top, 56)

            // タイトル（概観時のみ）
            if !isZoomedIn {
                Text("Daruma Collection")
                    .font(.shiranui(size: 28))
                    .foregroundStyle(.white)
            }

            Spacer()
        }
    }

    // MARK: - 願いバブル

    private func wishOverlay(for daruma: SavedDaruma) -> some View {
        VStack(spacing: 0) {
            // 願い事バブル（上部）
            if let wish = daruma.wishSentence {
                DarumaGuideBubble(
                    minHeight: 80,
                    horizontalPadding: 24,
                    verticalPadding: 20,
                    showsTail: false
                ) {
                    HStack(alignment: .top, spacing: 12) {
                        Text("Wish.")
                            .font(.shiranui(size: 22))
                            .foregroundStyle(Color.customRed)
                        Text(wish)
                            .font(.shiranui(size: 18))
                            .foregroundStyle(.black.opacity(0.85))
                            .lineLimit(3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 120)
            } else {
                Spacer().frame(height: 120)
            }

            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - 下部パネルオーバーレイ

    private func bottomPanelOverlay(for daruma: SavedDaruma) -> some View {
        VStack {
            Spacer()

            bottomPanel(for: daruma)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
        }
        .transition(.opacity)
    }

    // MARK: - 下部パネル

    private func bottomPanel(for daruma: SavedDaruma) -> some View {
        Group {
            if daruma.isWishFulfilled {
                // 達成済みメッセージ
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                    Text("Both Eyes Are Complete")
                        .font(.shiranui(size: 20))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.yellow, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
            } else {
                // 未達成パネル
                VStack(spacing: 14) {
                    Text("Did Your Wish Come True!?")
                        .font(.shiranui(size: 20))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)

                    Button(action: {
                        SoundPlayer.shared.playSelect()
                        showEyeDrawing = true
                    }) {
                        HStack(spacing: 10) {
                            Text("It Came True! Draw the Right Eye")
                                .font(.shiranui(size: 17))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .foregroundStyle(Color.customRed)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black.opacity(0.26))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 空のビュー

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.4))
            Text("No Daruma Yet")
                .font(.shiranui(size: 20))
                .foregroundStyle(.white.opacity(0.6))
            Text("Create a Daruma to start your collection")
                .font(.shiranui(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - アクション

    /// だるまタップ時の処理
    private func handleTap(id: UUID) {
        guard !isZoomedIn,
              !isZoomTransitioning,
              let daruma = store.savedDarumas.first(where: { $0.id == id }) else { return }
        selectedDaruma = daruma
        showBottomPanel = false
        isZoomTransitioning = true
        collectionScene.zoomIn(toID: id) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isZoomedIn = true
                showBottomPanel = true
            }
            isZoomTransitioning = false
        }
    }

    /// 戻るボタンの処理
    private func handleBack() {
        guard isZoomedIn, !isZoomTransitioning else { return }
        isZoomTransitioning = true
        showBottomPanel = false
        collectionScene.zoomOut {
            isZoomedIn = false
            selectedDaruma = nil
            isZoomTransitioning = false
        }
    }
}
