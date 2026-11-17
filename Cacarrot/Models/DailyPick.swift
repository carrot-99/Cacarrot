//  DailyPick.swift

import Foundation

/// 「今日の1冊」を日付から決める（アプリとウィジェットで共有）
///
/// 同じ日なら何度呼んでも同じ作品になり、日が変わると別の作品になる。
/// 作品数と互いに素な数ずつ進めるので、作品数の日数で全作品を一巡する
enum DailyPick {
    /// 日ごとに進める幅（素数。作品数の約数でなければ全作品を一巡する）
    static let stride = 7919

    static func pick(from items: [Manga], on date: Date = .now, calendar: Calendar = .current) -> Manga? {
        guard !items.isEmpty else { return nil }
        let count = items.count
        let day = dayNumber(of: date, calendar: calendar)
        // 作品数と互いに素でなければ一巡しないので、1ずつ進める
        let step = gcd(stride % count, count) == 1 ? stride % count : 1
        return items[(day % count) * step % count]
    }

    /// 2000-01-01 からの日数（その暦・タイムゾーンでの日付で数える）
    static func dayNumber(of date: Date, calendar: Calendar) -> Int {
        let origin = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .distantPast
        let days = calendar.dateComponents([.day], from: origin, to: calendar.startOfDay(for: date)).day ?? 0
        return max(days, 0)
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }

    /// 次に作品が変わる時刻（翌日の 0:00）
    static func nextChange(after date: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(24 * 60 * 60)
    }
}

/// アプリを開くURL（ウィジェットのタップなど）。形式は cacarrot://manga/<作品ID>
enum DeepLink {
    static let scheme = "cacarrot"

    static func mangaURL(id: Int) -> URL {
        URL(string: "\(scheme)://manga/\(id)")!
    }

    /// 作品を開くURLなら作品IDを返す
    static func mangaID(from url: URL) -> Int? {
        guard url.scheme == scheme, url.host() == "manga" else { return nil }
        return Int(url.lastPathComponent)
    }
}
