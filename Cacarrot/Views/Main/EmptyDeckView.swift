//  EmptyDeckView.swift

import SwiftUI

/// すべてのカードを判定し終えたときの表示
struct EmptyDeckView: View {
    @Environment(SwipeDeckViewModel.self) private var deck

    var body: some View {
        if deck.isFiltering {
            filteredEmpty
        } else {
            allChecked
        }
    }

    /// 絞り込み中に、条件に合う作品がなくなった場合
    private var filteredEmpty: some View {
        ContentUnavailableView {
            Label("この条件の作品はすべてチェックしました", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text("絞り込み：\(deck.selectedGenres.sorted().joined(separator: "・"))")
        } actions: {
            Button {
                deck.setGenreFilter([])
            } label: {
                Label("絞り込みを解除する", systemImage: "xmark.circle")
            }
            .buttonStyle(.borderedProminent)

            Button("スキップした作品をもう一度見る") { deck.restoreSkipped() }

            if deck.canUndo {
                Button("直前の判定を取り消す") { deck.undo() }
            }
        }
    }

    private var allChecked: some View {
        ContentUnavailableView {
            Label("すべての作品をチェックしました", systemImage: "checkmark.seal.fill")
        } description: {
            Text("お気に入りタブで「いいね」した作品を確認できます。")
        } actions: {
            Button {
                deck.restoreSkipped()
            } label: {
                Label("スキップした作品をもう一度見る", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderedProminent)

            if deck.canUndo {
                Button("直前の判定を取り消す") { deck.undo() }
            }
        }
    }
}
