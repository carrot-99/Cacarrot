//  SwipeAction.swift

import SwiftUI

/// カードに対するユーザーの判定
enum SwipeAction: String, Codable, CaseIterable, Sendable {
    case like
    case superLike
    case nope

    var label: String {
        switch self {
        case .like: "GOOD"
        case .superLike: "SUPER"
        case .nope: "NOPE"
        }
    }

    var displayName: String {
        switch self {
        case .like: "いいね"
        case .superLike: "スーパーいいね"
        case .nope: "スキップ"
        }
    }

    var systemImage: String {
        switch self {
        case .like: "heart.fill"
        case .superLike: "star.fill"
        case .nope: "xmark"
        }
    }

    var color: Color {
        switch self {
        case .like: Theme.like
        case .superLike: Theme.superLike
        case .nope: Theme.nope
        }
    }

    /// カードが画面外へ飛んでいく方向
    func exitOffset(in size: CGSize) -> CGSize {
        switch self {
        case .like: CGSize(width: size.width * 1.5, height: 60)
        case .nope: CGSize(width: -size.width * 1.5, height: 60)
        case .superLike: CGSize(width: 0, height: -size.height * 1.5)
        }
    }
}
