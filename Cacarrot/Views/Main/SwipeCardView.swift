//  SwipeCardView.swift

import SwiftUI

/// 1枚のカードの見た目
struct SwipeCardView: View {
    let manga: Manga
    var likeOpacity: Double = 0
    var nopeOpacity: Double = 0
    var superLikeOpacity: Double = 0

    var body: some View {
        MangaCoverView(manga: manga)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                LinearGradient(colors: [.clear, .clear, .black.opacity(0.85)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) { info }
            .overlay(alignment: .topLeading) {
                StampView(action: .like)
                    .rotationEffect(.degrees(-15))
                    .padding(28)
                    .opacity(likeOpacity)
            }
            .overlay(alignment: .topTrailing) {
                StampView(action: .nope)
                    .rotationEffect(.degrees(15))
                    .padding(28)
                    .opacity(nopeOpacity)
            }
            .overlay(alignment: .bottom) {
                StampView(action: .superLike)
                    .padding(.bottom, 180)
                    .opacity(superLikeOpacity)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(manga.title)
                .font(.system(size: 32, weight: .heavy))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(manga.author)
                .font(.title3.weight(.medium))
                .opacity(0.9)

            GenreTagsView(genres: manga.genres, style: .onDark)

            Text(manga.summary)
                .font(.subheadline)
                .lineLimit(3)
                .opacity(0.9)

            Label("タップで詳細", systemImage: "info.circle")
                .font(.caption)
                .opacity(0.7)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// GOOD / NOPE / SUPER のスタンプ
struct StampView: View {
    let action: SwipeAction

    var body: some View {
        Text(action.label)
            .font(.system(size: 40, weight: .black))
            .foregroundStyle(action.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(action.color, lineWidth: 5)
            )
            .accessibilityHidden(true)
    }
}

#Preview {
    SwipeCardView(manga: SampleMangaRepository.items[0], likeOpacity: 0.8)
        .padding()
}
