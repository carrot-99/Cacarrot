//  CacarrotApp.swift

import SwiftUI
import SwiftData
import FirebaseCore

/// Firebase の初期化
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct CacarrotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container: ModelContainer
    @State private var deck: SwipeDeckViewModel

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: SwipeRecord.self)
        } catch {
            // 保存領域が壊れている等で開けない場合はメモリ上で起動する
            container = try! ModelContainer(for: SwipeRecord.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
        self.container = container
        _deck = State(initialValue: SwipeDeckViewModel(
            repository: BundledMangaRepository(),
            store: SwipeHistoryStore(context: container.mainContext)
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(deck)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
