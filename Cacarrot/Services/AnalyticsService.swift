//  AnalyticsService.swift

import Foundation
import FirebaseAnalytics

/// 判定がどこから行われたか
enum SwipeSource: String, Sendable {
    case gesture     // カードをスワイプ
    case button      // 下のボタン・VoiceOver
    case detail      // 詳細シートのボタン
    case widget      // ウィジェットから開いた詳細シートのボタン
}

/// 記録する利用イベント
///
/// 作品名や ID などは送らず、操作の種類と回数が分かる最小限の情報だけにする
/// （PrivacyInfo.xcprivacy の「製品の操作・分析目的」の範囲）。
enum AnalyticsEvent: Equatable, Sendable {
    case swipe(action: SwipeAction, source: SwipeSource)
    case undo
    case openDetail
    case openFromWidget
    case applyGenreFilter(genreCount: Int)
    case setRecommendation(enabled: Bool)
    case deckFinished

    var name: String {
        switch self {
        case .swipe: "swipe"
        case .undo: "swipe_undo"
        case .openDetail: "open_detail"
        case .openFromWidget: "open_from_widget"
        case .applyGenreFilter: "apply_genre_filter"
        case .setRecommendation: "set_recommendation"
        case .deckFinished: "deck_finished"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .swipe(let action, let source): ["action": action.rawValue, "source": source.rawValue]
        case .applyGenreFilter(let count): ["genre_count": String(count)]
        case .setRecommendation(let enabled): ["enabled": enabled ? "true" : "false"]
        case .undo, .openDetail, .openFromWidget, .deckFinished: [:]
        }
    }
}

/// 利用イベントの記録先（テストでは偽物に差し替える）
protocol AnalyticsLogging: Sendable {
    func log(_ event: AnalyticsEvent)
}

/// Firebase Analytics に送る
struct FirebaseAnalyticsLogger: AnalyticsLogging {
    func log(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters.isEmpty ? nil : event.parameters)
    }
}

/// 何も送らない（プレビュー・テストの既定値）
struct NoopAnalyticsLogger: AnalyticsLogging {
    func log(_ event: AnalyticsEvent) {}
}
