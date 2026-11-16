//  MangaDetailView.swift

import SwiftUI

/// 作品の詳細シート
struct MangaDetailView: View {
    let manga: Manga
    var action: SwipeAction?
    /// デッキから開いた場合の判定（指定するとシート下部に判定ボタンを表示する）
    var onDecide: ((SwipeAction) -> Void)?

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
                if manga.itemURL != nil || onDecide != nil {
                    bottomBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    shareButton
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
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

#Preview {
    MangaDetailView(manga: SampleMangaRepository.items[1], action: .like)
}

#Preview("楽天リンクあり") {
    MangaDetailView(manga: Manga(id: 99, title: "サンプル", author: "作者",
                                 genres: ["少年", "アクション"], summary: "あらすじ",
                                 imageName: "ONE PIECE", publisher: "集英社",
                                 itemURL: URL(string: "https://books.rakuten.co.jp/")))
}
