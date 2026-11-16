//  EmptyDeckView.swift

import SwiftUI

/// すべてのカードを判定し終えたときの表示
struct EmptyDeckView: View {
    @Environment(SwipeDeckViewModel.self) private var deck

    var body: some View {
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
