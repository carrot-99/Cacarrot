//  MangaCoverView.swift

import SwiftUI
import UIKit

/// 表紙画像。ローカル画像 → リモート画像 → プレースホルダーの順に表示する
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
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder
                default:
                    ProgressView()
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: "book.closed.fill")
            .font(.system(size: 48))
            .foregroundStyle(.tertiary)
    }
}
