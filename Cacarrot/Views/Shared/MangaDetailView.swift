//  MangaDetailView.swift

import SwiftUI

/// 作品の詳細シート
struct MangaDetailView: View {
    let manga: Manga
    var action: SwipeAction?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MangaCoverView(manga: manga)
                        .frame(height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(manga.title)
                            .font(.title.bold())
                        Text(manga.author)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        if let publisher = manga.publisher {
                            Text(publisher)
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if let action {
                        Label(action.displayName, systemImage: action.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(action.color)
                    }

                    GenreTagsView(genres: manga.genres)

                    Text(manga.summary)
                        .font(.body)
                        .lineSpacing(4)
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                if let itemURL = manga.itemURL {
                    Link(destination: itemURL) {
                        Label("楽天ブックスで見る", systemImage: "cart.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(.bar)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    MangaDetailView(manga: SampleMangaRepository.items[1], action: .like)
}

#Preview("楽天リンクあり") {
    MangaDetailView(manga: Manga(id: 99, title: "サンプル", author: "作者",
                                 genres: ["少年", "アクション"], summary: "あらすじ",
                                 imageName: "ONE PIECE", publisher: "集英社",
                                 itemURL: URL(string: "https://books.rakuten.co.jp/")))
}
