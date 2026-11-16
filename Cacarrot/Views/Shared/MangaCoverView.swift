//  MangaCoverView.swift

import SwiftUI
import UIKit

/// 表紙画像。ローカル画像 → リモート画像（キャッシュ付き）→ プレースホルダーの順に表示する
struct MangaCoverView: View {
    let manga: Manga

    var body: some View {
        Color(.secondarySystemBackground)
            .overlay { image }
            .clipped()
    }

    @ViewBuilder
    private var image: some View {
        if let name = manga.imageName, UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFill()
        } else if let url = manga.imageURL {
            RemoteCoverImage(url: url)
        } else {
            CoverPlaceholder()
        }
    }
}

/// ImageLoader を使ってリモート画像を表示する（AsyncImage の代わり）
private struct RemoteCoverImage: View {
    let url: URL

    private enum Phase {
        case loading, success(UIImage), failure
    }

    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            switch phase {
            case .success(let image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            case .failure:
                CoverPlaceholder()
                    .overlay(alignment: .bottom) {
                        Button("再読み込み", systemImage: "arrow.clockwise") {
                            Task { await load() }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .padding(.bottom, 16)
                    }
            case .loading:
                ProgressView()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        // メモリにあれば即表示（スワイプ直後のちらつき防止）
        if let cached = ImageLoader.shared.cachedImage(for: url) {
            phase = .success(cached)
            return
        }
        phase = .loading
        do {
            let image = try await ImageLoader.shared.image(for: url)
            phase = .success(image)
        } catch is CancellationError {
            // 画面から外れた場合は何もしない
        } catch {
            phase = .failure
        }
    }
}

private struct CoverPlaceholder: View {
    var body: some View {
        Image(systemName: "book.closed.fill")
            .font(.system(size: 48))
            .foregroundStyle(.tertiary)
    }
}
