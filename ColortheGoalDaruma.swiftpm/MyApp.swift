import SwiftUI

@main
struct MyApp: App {
    @State private var showTitleOverlay = false
    @State private var navigationPath = NavigationPath()
    @State private var darumaStore = DarumaStore()
    @State private var titleSceneResetKey = UUID()

    init() {
        FontRegistration.registerShiranuiIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                ZStack {
                    DarumaRainView(onCameraAnimationComplete: {
                        withAnimation(.easeOut(duration: 0.8)) {
                            showTitleOverlay = true
                        }
                    })
                    .id(titleSceneResetKey)

                    // タイトル + Startボタンオーバーレイ
                    TitleAndButtonOverlay(
                        isVisible: showTitleOverlay,
                        hasCollection: !darumaStore.savedDarumas.isEmpty,
                        onStart: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showTitleOverlay = false
                            }
                            navigationPath.append(AppRoute.diagnosis)
                        },
                        onShowCollection: {
                            navigationPath.append(AppRoute.collection)
                        }
                    )
                }
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .diagnosis:
                        ContentView(
                            darumaStore: darumaStore,
                            onReturnToTop: {
                                showTitleOverlay = true
                                titleSceneResetKey = UUID()
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast(navigationPath.count)
                                }
                            },
                            onShowCollection: {
                                showTitleOverlay = true
                                titleSceneResetKey = UUID()
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast(navigationPath.count)
                                }
                                navigationPath.append(AppRoute.collection)
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                        .toolbar(.hidden, for: .navigationBar)

                    case .collection:
                        CollectionRouteView(store: darumaStore) {
                            showTitleOverlay = true
                            titleSceneResetKey = UUID()
                            if !navigationPath.isEmpty {
                                navigationPath.removeLast(navigationPath.count)
                            }
                        }
                    }
                }
            }
            .tint(Color.customRed)
            .environment(\.font, Font.shiranui(.body))
        }
    }
}

private enum AppRoute: Hashable {
    case diagnosis
    case collection
}

private struct CollectionRouteView: View {
    let store: DarumaStore
    let onBack: () -> Void
    @State private var isZoomedIn = false

    var body: some View {
        DarumaCollectionListView(
            store: store,
            onDismiss: onBack,
            onZoomStateChange: { zoomed in
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    isZoomedIn = zoomed
                }
            }
        )
            .navigationBarBackButtonHidden(true)
            .toolbar {
                if !isZoomedIn {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            SoundPlayer.shared.playSelect()
                            onBack()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                                    .font(.shiranui(size: 16))
                            }
                        }
                    }
                }
            }
    }
}

private struct TitleAndButtonOverlay: View {
    let isVisible: Bool
    let hasCollection: Bool
    let onStart: () -> Void
    let onShowCollection: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TitleBackgroundImage()
                    .scaleEffect(0.7)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .offset(
                        x: -proxy.frame(in: .global).origin.x,
                        y: -proxy.frame(in: .global).origin.y
                    )
                VStack(spacing: 24) {
                    Text("Color the \nGoal Daruma")
                        .font(.shiranui(size: 48))
                        .lineSpacing(-8)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.white)

                    // Startボタン
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

                    // コレクションボタン（だるまが1体以上いる場合のみ表示）
                    if hasCollection {
                        Button(action: {
                            SoundPlayer.shared.playSelect()
                            onShowCollection()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 16))
                                Text("View My Darumas")
                                    .font(.shiranui(size: 16))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .frame(maxWidth: 320)
                            .frame(height: 48)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(.easeOut(duration: 0.8), value: isVisible)
        .ignoresSafeArea()
    }
}
