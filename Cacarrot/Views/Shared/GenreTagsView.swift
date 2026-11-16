//  GenreTagsView.swift

import SwiftUI

/// ジャンルタグの横並び
struct GenreTagsView: View {
    enum Style { case onDark, standard }

    let genres: [String]
    var style: Style = .standard

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(style == .onDark ? Color.white : Theme.accent)
                        .background(
                            style == .onDark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Theme.accent.opacity(0.12)),
                            in: Capsule()
                        )
                }
            }
        }
        .scrollDisabled(genres.count < 4)
    }
}
