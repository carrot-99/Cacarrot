//  CardStackView.swift

import SwiftUI

/// カードを重ねて表示し、一番上のカードだけドラッグ可能にする
struct CardStackView: View {
    @Environment(SwipeDeckViewModel.self) private var deck
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onTapCard: (Manga) -> Void = { _ in }

    /// 描画するカードの最大枚数（パフォーマンス対策）
    private let visibleCount = 3

    var body: some View {
        let visible = Array(deck.cards.prefix(visibleCount))

        ZStack {
            ForEach(Array(visible.enumerated()).reversed(), id: \.element.id) { index, manga in
                if index == 0 {
                    topCard(manga)
                } else {
                    SwipeCardView(manga: manga)
                        .scaleEffect(backScale(depth: index))
                        .offset(y: backOffset(depth: index))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { deck.cardSize = $0 }
    }

    private func topCard(_ manga: Manga) -> some View {
        SwipeCardView(
            manga: manga,
            likeOpacity: deck.stampOpacity(for: .like),
            nopeOpacity: deck.stampOpacity(for: .nope),
            superLikeOpacity: deck.stampOpacity(for: .superLike)
        )
        .offset(deck.dragOffset)
        // 「視差効果を減らす」がオンのときは、カードを傾けない
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(deck.dragOffset.width / 20)), anchor: .bottom)
        .gesture(
            DragGesture()
                .onChanged { deck.dragChanged($0.translation) }
                .onEnded { deck.dragEnded(translation: $0.translation, predicted: $0.predictedEndTranslation) }
        )
        .onTapGesture { onTapCard(manga) }
        .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityHint("右スワイプでいいね、左でスキップ、上でスーパーいいね。ダブルタップで詳細")
        .accessibilityAction(named: SwipeAction.like.displayName) { deck.swipe(.like) }
        .accessibilityAction(named: SwipeAction.nope.displayName) { deck.swipe(.nope) }
        .accessibilityAction(named: SwipeAction.superLike.displayName) { deck.swipe(.superLike) }
    }

    /// 一番上のカードを動かすほど、後ろのカードが前に出てくる
    private var dragProgress: CGFloat {
        let distance = hypot(deck.dragOffset.width, deck.dragOffset.height)
        return min(distance / SwipeDeckViewModel.horizontalThreshold, 1)
    }

    private func backScale(depth: Int) -> CGFloat {
        let effectiveDepth = CGFloat(depth) - dragProgress
        return 1 - effectiveDepth * 0.05
    }

    private func backOffset(depth: Int) -> CGFloat {
        let effectiveDepth = CGFloat(depth) - dragProgress
        return effectiveDepth * 14
    }
}
