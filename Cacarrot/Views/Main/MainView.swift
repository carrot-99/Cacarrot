//  MainView.swift

import SwiftUI

/// スワイプ画面
struct MainView: View {
    @Environment(SwipeDeckViewModel.self) private var deck
    @State private var detailManga: Manga?
    @State private var isShowingFilter = false
    @AppStorage("hasSeenSwipeGuide") private var hasSeenSwipeGuide = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            HeaderView(remaining: deck.remainingCount,
                       total: deck.filteredTotalCount,
                       filterCount: deck.selectedGenres.count,
                       onFilterTap: { isShowingFilter = true })
                .frame(maxWidth: Theme.maxCardWidth + 24)

            content
                // iPad などの広い画面では、カードが横に広がりすぎないよう幅を抑える
                .frame(maxWidth: Theme.maxCardWidth, maxHeight: .infinity)
                .padding(.horizontal, 12)

            ActionBarView()
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .task { await deck.loadIfNeeded() }
        .onChange(of: reduceMotion, initial: true) { _, newValue in
            deck.reduceMotion = newValue
        }
        .sheet(item: $detailManga) { manga in
            MangaDetailView(manga: manga, onDecide: { action in
                // 詳細を開いたのは一番上のカードなので、そのまま判定する
                guard deck.topCard?.id == manga.id else { return }
                deck.swipe(action, source: .detail)
            })
        }
        .sheet(isPresented: $isShowingFilter) {
            GenreFilterView()
        }
        .overlay {
            if !hasSeenSwipeGuide && deck.loadState == .loaded {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { closeGuide() }
                    SwipeGuideView(onClose: closeGuide)
                }
                .transition(.opacity)
            }
        }
    }

    private func closeGuide() {
        withAnimation(.easeOut(duration: 0.25)) { hasSeenSwipeGuide = true }
    }

    @ViewBuilder
    private var content: some View {
        switch deck.loadState {
        case .idle, .loading:
            ProgressView("読み込み中…")
        case .failed(let message):
            ContentUnavailableView {
                Label("読み込みに失敗しました", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("再試行") { Task { await deck.reload() } }
                    .buttonStyle(.borderedProminent)
            }
        case .loaded:
            if deck.cards.isEmpty {
                EmptyDeckView()
            } else {
                CardStackView(onTapCard: { manga in
                    detailManga = manga
                    deck.track(.openDetail)
                })
            }
        }
    }
}

#Preview {
    PreviewContainer { MainView() }
}
