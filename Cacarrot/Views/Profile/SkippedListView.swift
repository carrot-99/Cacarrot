//  SkippedListView.swift

import SwiftUI
import SwiftData

/// スキップした作品の一覧。1作品ずつデッキに戻したり、いいねに変えたりできる
struct SkippedListView: View {
    @Environment(SwipeDeckViewModel.self) private var deck
    @Query(filter: SwipeRecord.skippedPredicate,
           sort: \SwipeRecord.createdAt, order: .reverse)
    private var records: [SwipeRecord]

    @State private var selected: SwipeRecord?

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView("スキップした作品はありません",
                                       systemImage: "xmark.circle",
                                       description: Text("「さがす」タブで左にスワイプした作品が、ここに表示されます。"))
            } else {
                List {
                    Section {
                        ForEach(records) { record in
                            Button { selected = record } label: {
                                LibraryRow(record: record)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    withAnimation { deck.forget(mangaID: record.mangaID) }
                                } label: {
                                    Label("デッキに戻す", systemImage: "arrow.uturn.backward")
                                }
                                .tint(Theme.accent)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    withAnimation { deck.changeAction(mangaID: record.mangaID, to: .like) }
                                } label: {
                                    Label("いいねにする", systemImage: SwipeAction.like.systemImage)
                                }
                                .tint(Theme.like)
                            }
                        }
                    } footer: {
                        Text("左にスワイプでデッキに戻す、右にスワイプでいいねにできます。")
                    }
                }
            }
        }
        .navigationTitle("スキップした作品")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("すべて戻す") {
                        withAnimation { deck.restoreSkipped() }
                    }
                }
            }
        }
        .sheet(item: $selected) { record in
            MangaDetailView(manga: record.manga, action: record.action)
        }
    }
}

#Preview {
    PreviewContainer {
        NavigationStack { SkippedListView() }
    }
}
