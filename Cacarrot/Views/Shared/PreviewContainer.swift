//  PreviewContainer.swift

import SwiftUI
import SwiftData

/// Xcode プレビュー用：メモリ上の SwiftData と ViewModel を注入する
struct PreviewContainer<Content: View>: View {
    private let container: ModelContainer
    @State private var deck: SwipeDeckViewModel
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        let container = try! ModelContainer(for: SwipeRecord.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = SwipeHistoryStore(context: container.mainContext)
        try? store.record(SampleMangaRepository.items[0], action: .superLike)
        try? store.record(SampleMangaRepository.items[1], action: .like)
        try? store.record(SampleMangaRepository.items[3], action: .nope)
        self.container = container
        _deck = State(initialValue: SwipeDeckViewModel(repository: SampleMangaRepository(), store: store))
        self.content = content()
    }

    var body: some View {
        content
            .environment(deck)
            .modelContainer(container)
            .task { await deck.loadIfNeeded() }
    }
}
