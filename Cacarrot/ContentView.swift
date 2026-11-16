//  ContentView.swift

import SwiftUI
import SwiftData

struct ContentView: View {
    enum Tab: Hashable { case discover, library, profile }

    @State private var selection: Tab = .discover
    @Query(filter: #Predicate<SwipeRecord> { $0.actionRawValue != "nope" })
    private var likedRecords: [SwipeRecord]

    var body: some View {
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
