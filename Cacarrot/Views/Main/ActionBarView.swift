//  ActionBarView.swift

import SwiftUI

/// 画面下部の操作ボタン
struct ActionBarView: View {
    @Environment(SwipeDeckViewModel.self) private var deck

    var body: some View {
        let hasCard = deck.topCard != nil && !deck.isAnimating

        HStack(spacing: 18) {
            CircleActionButton(systemImage: "arrow.uturn.backward", color: Theme.undo,
                               size: 50, label: "取り消す") {
                deck.undo()
            }
            .disabled(!deck.canUndo)
            .accessibilityIdentifier("action.undo")

            CircleActionButton(systemImage: SwipeAction.nope.systemImage, color: SwipeAction.nope.color,
                               size: 68, label: SwipeAction.nope.displayName) {
                deck.swipe(.nope)
            }
            .disabled(!hasCard)
            .accessibilityIdentifier("action.nope")

            CircleActionButton(systemImage: SwipeAction.superLike.systemImage, color: SwipeAction.superLike.color,
                               size: 50, label: SwipeAction.superLike.displayName) {
                deck.swipe(.superLike)
            }
            .disabled(!hasCard)
            .accessibilityIdentifier("action.superLike")

            CircleActionButton(systemImage: SwipeAction.like.systemImage, color: SwipeAction.like.color,
                               size: 68, label: SwipeAction.like.displayName) {
                deck.swipe(.like)
            }
            .disabled(!hasCard)
            .accessibilityIdentifier("action.like")
        }
        .frame(maxWidth: .infinity)
    }
}

struct CircleActionButton: View {
    let systemImage: String
    let color: Color
    let size: CGFloat
    let label: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}

/// 押下時に少し縮むボタンスタイル
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
