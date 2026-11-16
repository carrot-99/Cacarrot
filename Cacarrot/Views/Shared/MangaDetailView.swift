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
