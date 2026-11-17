//  MangaDetailView.swift

import SwiftUI

/// 作品の詳細シート
struct MangaDetailView: View {
    let manga: Manga
    var action: SwipeAction?
    /// デッキから開いた場合の判定（指定するとシート下部に判定ボタンを表示する）
    var onDecide: ((SwipeAction) -> Void)?
    /// 「似ている作品」から開いた場合は、親のナビゲーションに積む（NavigationStack を入れ子にしない）
    var isPushed = false

    @Environment(\.dismiss) private var dismiss
    /// プレビューなど ViewModel がない場所では、似ている作品を出さない
    @Environment(SwipeDeckViewModel.self) private var deck: SwipeDeckViewModel?

    var body: some View {
        if isPushed {
            content
        } else {
            NavigationStack { content }
                .presentationDragIndicator(.visible)
        }
    }

    private var content: some View {
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

                if let deck {
                    SimilarTitlesSection(titles: deck.similarTitles(to: manga),
                                         isChecked: deck.isChecked)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if manga.itemURL != nil || onDecide != nil {
                bottomBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                shareButton
            }
            if !isPushed {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .navigationDestination(for: Manga.self) { similar in
            MangaDetailView(manga: similar, isPushed: true)
        }
    }

    /// 作品を共有する（商品ページがあればそのURLも付ける）
    @ViewBuilder
    private var shareButton: some View {
        let message = "『\(manga.title)』\(manga.author.isEmpty ? "" : "（\(manga.author)）")をCacarrotで見つけました"
        if let itemURL = manga.itemURL {
            ShareLink(item: itemURL, subject: Text(manga.title), message: Text(message)) {
                Label("共有", systemImage: "square.and.arrow.up")
            }
        } else {
            ShareLink(item: message, subject: Text(manga.title)) {
                Label("共有", systemImage: "square.and.arrow.up")
            }
        }
    }

    /// 購入リンクと、デッキから開いた場合の判定ボタン
    private var bottomBar: some View {
        VStack(spacing: 12) {
            if let itemURL = manga.itemURL {
                Link(destination: itemURL) {
                    Label("楽天ブックスで見る", systemImage: "cart.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }

            if let onDecide {
                HStack(spacing: 28) {
                    ForEach([SwipeAction.nope, .superLike, .like], id: \.self) { action in
                        CircleActionButton(systemImage: action.systemImage,
                                           color: action.color,
                                           size: action == .superLike ? 48 : 60,
                                           label: action.displayName) {
                            dismiss()
                            onDecide(action)
                        }
                        .accessibilityIdentifier("detail.\(action.rawValue)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

/// ジャンルや作者が近い作品（横スクロール）。タップで詳細へ進む
private struct SimilarTitlesSection: View {
    let titles: [Manga]
    let isChecked: (Manga) -> Bool

    var body: some View {
        if !titles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("似ている作品")
                    .font(.headline)
                    .padding(.top, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(titles) { manga in
                            NavigationLink(value: manga) {
                                SimilarTitleCell(manga: manga, isChecked: isChecked(manga))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .accessibilityIdentifier("detail.similar")
            }
        }
    }
}

private struct SimilarTitleCell: View {
    let manga: Manga
    let isChecked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MangaCoverView(manga: manga)
                .frame(width: 96, height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if isChecked {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Theme.accent)
                            .padding(4)
                    }
                }
            Text(manga.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 96, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isChecked ? "チェック済み" : "")
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
