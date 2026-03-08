import SwiftUI

struct PagedGuideOverlay: View {
    let overlayOpacity: Double
    let pageHeight: CGFloat
    let widthPadding: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let verticalSpacing: CGFloat
    let usesSystemPageIndicator: Bool
    let enablesVerticalSwipePaging: Bool
    let showsCTAOnlyOnLastPage: Bool
    let pages: [AnyView]
    let indicator: ((Int) -> AnyView)?
    let cta: AnyView?

    @State private var currentPage: Int = 0

    init(
        overlayOpacity: Double = 0.5,
        pageHeight: CGFloat,
        widthPadding: CGFloat = 40,
        minWidth: CGFloat = 280,
        maxWidth: CGFloat = 720,
        verticalSpacing: CGFloat = 18,
        usesSystemPageIndicator: Bool = false,
        enablesVerticalSwipePaging: Bool = false,
        showsCTAOnlyOnLastPage: Bool = false,
        pages: [AnyView],
        indicator: ((Int) -> AnyView)? = nil,
        cta: AnyView? = nil
    ) {
        self.overlayOpacity = overlayOpacity
        self.pageHeight = pageHeight
        self.widthPadding = widthPadding
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.verticalSpacing = verticalSpacing
        self.usesSystemPageIndicator = usesSystemPageIndicator
        self.enablesVerticalSwipePaging = enablesVerticalSwipePaging
        self.showsCTAOnlyOnLastPage = showsCTAOnlyOnLastPage
        self.pages = pages
        self.indicator = indicator
        self.cta = cta
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(overlayOpacity)
                    .ignoresSafeArea()

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        page
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: usesSystemPageIndicator ? .always : .never))
                .frame(width: proxy.size.width, height: proxy.size.height)

                VStack(spacing: 0) {
                    Spacer()

                    if let cta, (!showsCTAOnlyOnLastPage || currentPage == max(pages.count - 1, 0)) {
                        cta
                            .padding(.bottom, 158)
                    }

                    if let indicator {
                        indicator(currentPage)
                            .padding(.top, 16)
                    }

                    // Keep controls clear of the bottom safe area.
                    Color.clear
                        .frame(height: max(proxy.safeAreaInsets.bottom, 20))
                        .padding(.top, 18)
                }
                .padding(.horizontal, 20)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .allowsHitTesting(true)
            }
        }
        .ignoresSafeArea()
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    guard enablesVerticalSwipePaging else { return }
                    let h = abs(value.translation.width)
                    let v = abs(value.translation.height)
                    guard v > h, v > 50 else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if value.translation.height < 0 {
                            currentPage = min(currentPage + 1, max(pages.count - 1, 0))
                        } else {
                            currentPage = max(currentPage - 1, 0)
                        }
                    }
                }
        )
    }
}
