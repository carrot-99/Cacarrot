//  ContentView.swift

import SwiftUI
import SwiftData

struct ContentView: View {
    enum Tab: Hashable { case discover, library, profile }

    @Environment(SwipeDeckViewModel.self) private var deck
    @State private var selection: Tab = .discover
    @Query(filter: SwipeRecord.likedPredicate)
    private var likedRecords: [SwipeRecord]

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
