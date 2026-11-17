//  ContentView.swift

import SwiftUI
import SwiftData

struct ContentView: View {
    enum Tab: Hashable { case discover, library, profile }

    @Environment(SwipeDeckViewModel.self) private var deck
    @State private var selection: Tab = .discover
    @Query(filter: SwipeRecord.likedPredicate)
    private var likedRecords: [SwipeRecord]
    /// URL（ウィジェット）で開くよう頼まれた作品。データの読み込みが終わってから表示する
    @State private var pendingMangaID: Int?
    @State private var linkedManga: Manga?

    var body: some View {
        @Bindable var deck = deck
        tabs
            .alert("保存できませんでした",
                   isPresented: Binding(get: { deck.errorMessage != nil },
                                        set: { if !$0 { deck.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deck.errorMessage ?? "")
            }
            .onOpenURL { url in
                guard let id = DeepLink.mangaID(from: url) else { return }
                pendingMangaID = id
                openPendingManga()
            }
            .onChange(of: deck.loadState) { _, _ in openPendingManga() }
            .sheet(item: $linkedManga) { manga in
                // まだ判定していなければ、その場で判定できるようにする
                MangaDetailView(manga: manga,
                                onDecide: deck.isChecked(manga) ? nil : { action in
                                    deck.decide(manga, action: action, source: .widget)
                                })
            }
    }

    private func openPendingManga() {
        guard let id = pendingMangaID, deck.loadState == .loaded else { return }
        pendingMangaID = nil
        guard let manga = deck.manga(id: id) else { return }
        selection = .discover
        linkedManga = manga
        deck.track(.openFromWidget)
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            MainView()
                .tabItem { Label("さがす", systemImage: "rectangle.stack.fill") }
                .tag(Tab.discover)

            LibraryView()
                .tabItem { Label("お気に入り", systemImage: "heart.fill") }
                .badge(likedRecords.count)
                .tag(Tab.library)

            ProfileView()
                .tabItem { Label("マイページ", systemImage: "person.fill") }
                .tag(Tab.profile)
        }
    }
}
