//  Haptics.swift

import UIKit

/// 触覚フィードバックのヘルパー（マイページの設定でオフにできる）
@MainActor
enum Haptics {
    /// UserDefaults / @AppStorage のキー
    static let settingKey = "isHapticsEnabled"
    /// オフなら何もしない（起動時と設定の変更時に更新する）
    static var isEnabled = true

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
