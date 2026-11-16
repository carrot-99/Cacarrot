//  MainView.swift

import SwiftUI

/// スワイプ画面
struct MainView: View {
    @Environment(SwipeDeckViewModel.self) private var deck
    @State private var detailManga: Manga?

    var body: some View {
        VStack(spacing: 12) {
            HeaderView(remaining: deck.remainingCount, total: deck.totalCount)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)

            ActionBarView()
                .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
        .task { await deck.loadIfNeeded() }
        .sheet(item: $detailManga) { manga in
            MangaDetailView(manga: manga)
        }
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
                CardStackView(onTapCard: { detailManga = $0 })
            }
        }
    }
}

#Preview {
    PreviewContainer { MainView() }
}
