//  CacarrotApp.swift

import SwiftUI
import SwiftData
import FirebaseCore

/// 起動モード
enum LaunchMode {
    /// UI テスト用（起動引数 `-uiTesting`）。
    /// メモリ上のデータ・専用の UserDefaults・サンプル作品を使い、端末に保存されたデータには触れない。
    /// Firebase も初期化しない（テストの操作を分析データに混ぜない）
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
    static let uiTestingDefaultsSuite = "CacarrotUITesting"
}

/// Firebase の初期化
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if !LaunchMode.isUITesting {
            FirebaseApp.configure()
        }
        return true
    }
}

@main
struct CacarrotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container: ModelContainer
    private let defaults: UserDefaults
    @State private var deck: SwipeDeckViewModel

    init() {
        if LaunchMode.isUITesting {
            let container = try! ModelContainer(for: SwipeRecord.self,
                                                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let defaults = UserDefaults(suiteName: LaunchMode.uiTestingDefaultsSuite)!
            defaults.removePersistentDomain(forName: LaunchMode.uiTestingDefaultsSuite)
            // 並び順を固定して、テストで何が表示されるか決まるようにする
            defaults.set(false, forKey: "isRecommendationEnabled")
            self.container = container
            self.defaults = defaults
            _deck = State(initialValue: SwipeDeckViewModel(
                repository: SampleMangaRepository(),
                store: SwipeHistoryStore(context: container.mainContext),
                defaults: defaults
            ))
            return
        }

        let container: ModelContainer
        do {
            container = try ModelContainer(for: SwipeRecord.self)
        } catch {
            // 保存領域が壊れている等で開けない場合はメモリ上で起動する
            container = try! ModelContainer(for: SwipeRecord.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
        self.container = container
        self.defaults = .standard
        Haptics.isEnabled = UserDefaults.standard.object(forKey: Haptics.settingKey) as? Bool ?? true
        // リマインダーがオンなら登録し直す（時刻の変更やOSの更新で消えていても戻るように）
        if UserDefaults.standard.bool(forKey: ReminderScheduler.enabledKey) {
            let minutes = UserDefaults.standard.object(forKey: ReminderScheduler.minutesKey) as? Int
                ?? ReminderScheduler.defaultMinutes
            Task { try? await ReminderScheduler().schedule(minutes: minutes) }
        }
        _deck = State(initialValue: SwipeDeckViewModel(
            repository: BundledMangaRepository(),
            store: SwipeHistoryStore(context: container.mainContext),
            analytics: FirebaseAnalyticsLogger()
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(deck)
                .tint(Theme.accent)
                // @AppStorage（初回ガイド・お気に入りの並び順）も同じ保存先を使う
                .defaultAppStorage(defaults)
        }
        .modelContainer(container)
    }
}
