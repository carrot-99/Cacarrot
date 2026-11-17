//  ReminderScheduler.swift

import Foundation
import UserNotifications

/// 通知センターのうち、リマインダーで使う部分（テストでは偽物に差し替える）
protocol NotificationCentering: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCentering {}

/// 毎日決まった時刻に「新しい作品をチェック」の通知を出す
///
/// 端末内で完結するローカル通知なので、サーバーやプッシュ通知の設定は不要。
/// 時刻は 0:00 からの分数で保存する（@AppStorage で扱いやすいため）
struct ReminderScheduler: Sendable {
    /// UserDefaults / @AppStorage のキー
    static let enabledKey = "isDailyReminderEnabled"
    static let minutesKey = "dailyReminderMinutes"
    /// 既定の時刻（20:00）
    static let defaultMinutes = 20 * 60
    static let identifier = "daily-reminder"

    enum ScheduleError: LocalizedError {
        case denied
        var errorDescription: String? { "通知が許可されていません。設定アプリの「通知」から Cacarrot を許可してください。" }
    }

    let center: NotificationCentering

    init(center: NotificationCentering = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// 毎日の通知を登録し直す。許可されなければ `ScheduleError.denied`
    func schedule(minutes: Int) async throws {
        guard try await center.requestAuthorization(options: [.alert, .sound]) else {
            throw ScheduleError.denied
        }
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        let trigger = UNCalendarNotificationTrigger(dateMatching: Self.dateComponents(minutes: minutes),
                                                    repeats: true)
        try await center.add(UNNotificationRequest(identifier: Self.identifier,
                                                   content: Self.content(),
                                                   trigger: trigger))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }

    // MARK: - 組み立て（テストのため static）

    static func dateComponents(minutes: Int) -> DateComponents {
        let clamped = min(max(minutes, 0), 24 * 60 - 1)
        return DateComponents(hour: clamped / 60, minute: clamped % 60)
    }

    static func content() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "今日の漫画をさがそう"
        content.body = "スワイプして、次に読む作品を見つけましょう。"
        content.sound = .default
        return content
    }

    /// 0:00 からの分数 ⇄ DatePicker 用の Date
    static func date(fromMinutes minutes: Int, calendar: Calendar = .current) -> Date {
        let components = dateComponents(minutes: minutes)
        return calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0,
                             second: 0, of: .now) ?? .now
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
