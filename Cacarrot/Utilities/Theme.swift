//  Theme.swift

import SwiftUI

/// アプリ全体で使う色・サイズ
enum Theme {
    static let accent = Color.accentColor
    static let like = Color(red: 0.16, green: 0.78, blue: 0.47)
    static let nope = Color(red: 0.96, green: 0.27, blue: 0.33)
    static let superLike = Color(red: 0.20, green: 0.60, blue: 0.98)
    static let undo = Color(red: 0.98, green: 0.71, blue: 0.16)

    static let cardCornerRadius: CGFloat = 20
    /// カード領域の最大幅（iPad で横に広がりすぎないように）
    static let maxCardWidth: CGFloat = 520
}
