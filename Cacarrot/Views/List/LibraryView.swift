//  LibraryView.swift

import SwiftUI
import SwiftData

/// いいね・スーパーいいねした作品の一覧
struct LibraryView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "すべて"
        case superLike = "スーパー"
        case like = "いいね"
        var id: Self { self }
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case newest = "新しい順"
        case oldest = "古い順"
        case title = "タイトル順"
        var id: Self { self }
    }

    @Environment(SwipeDeckViewModel.self) private var deck
    @Query(filter: SwipeRecord.likedPredicate,
           sort: \SwipeRecord.createdAt, order: .reverse)
    private var records: [SwipeRecord]

    @State private var filter: Filter = .all
    @AppStorage("librarySortOrder") private var sortOrder: SortOrder = .newest
    @State private var searchText = ""
    @State private var selected: SwipeRecord?

    private var filtered: [SwipeRecord] {
        records.filter { record in
            switch filter {
            case .all: true
            case .like: record.action == .like
            case .superLike: record.action == .superLike
            }
        }
        .filter { record in
            searchText.isEmpty
                || record.title.localizedCaseInsensitiveContains(searchText)
                || record.author.localizedCaseInsensitiveContains(searchText)
                || record.genres.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        .sorted { lhs, rhs in
            switch sortOrder {
            case .newest: lhs.createdAt > rhs.createdAt
            case .oldest: lhs.createdAt < rhs.createdAt
            case .title: lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView("まだお気に入りがありません",
                                           systemImage: "heart.slash",
                                           description: Text("「さがす」タブで気になる作品を右にスワイプしましょう。"))
                } else {
                    list
                }
            }
            .navigationTitle("お気に入り")
            .toolbar {
                if !records.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("並び順", selection: $sortOrder) {
                                ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                            }
                        } label: {
                            Label("並び順", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
            }
            .sheet(item: $selected) { record in
                MangaDetailView(manga: record.manga, action: record.action)
            }
        }
    }

    private var list: some View {
        List {
            Section {
                Picker("絞り込み", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if filtered.isEmpty {
                if searchText.isEmpty {
                    // 検索していないのに空 ＝ 選んだ種類（スーパー / いいね）の作品がない
                    ContentUnavailableView("まだありません",
                                           systemImage: filter == .superLike ? "star" : "heart",
                                           description: Text(filter == .superLike
                                                             ? "「さがす」タブで上にスワイプした作品が、ここに表示されます。"
                                                             : "「さがす」タブで右にスワイプした作品が、ここに表示されます。"))
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }

            ForEach(filtered) { record in
                Button { selected = record } label: {
                    LibraryRow(record: record)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    deleteButton(record)
                }
                .swipeActions(edge: .leading) {
                    toggleRatingButton(record)
                }
                .contextMenu {
                    toggleRatingButton(record)
                    deleteButton(record)
                }
            }
        }
        .searchable(text: $searchText, prompt: "タイトル・作者・ジャンル")
        .animation(.default, value: filter)
        .animation(.default, value: sortOrder)
    }

    /// いいね ⇄ スーパーいいね を切り替える
    private func toggleRatingButton(_ record: SwipeRecord) -> some View {
        let target: SwipeAction = record.action == .superLike ? .like : .superLike
        return Button {
            withAnimation { deck.changeAction(mangaID: record.mangaID, to: target) }
        } label: {
            Label(target == .superLike ? "スーパーいいねにする" : "いいねにする", systemImage: target.systemImage)
        }
        .tint(target.color)
    }

    private func deleteButton(_ record: SwipeRecord) -> some View {
        Button(role: .destructive) {
            withAnimation { deck.forget(mangaID: record.mangaID) }
        } label: {
            Label("削除", systemImage: "trash")
        }
    }
}

private struct LibraryRow: View {
    let record: SwipeRecord

    var body: some View {
        HStack(spacing: 12) {
            MangaCoverView(manga: record.manga)
                .frame(width: 56, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(record.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(record.genres.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: record.action.systemImage)
                .foregroundStyle(record.action.color)
                .accessibilityLabel(record.action.displayName)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    PreviewContainer { LibraryView() }
}
