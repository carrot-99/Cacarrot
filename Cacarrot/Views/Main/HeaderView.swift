//  HeaderView.swift

import SwiftUI

/// ロゴ・絞り込みボタン・残り枚数を表示するヘッダー
struct HeaderView: View {
    let remaining: Int
    let total: Int
    var filterCount: Int = 0
    var onFilterTap: () -> Void = {}

    var body: some View {
        ZStack {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 36)
                .accessibilityLabel("Cacarrot")

            HStack {
                filterButton
                Spacer()
                if total > 0 {
                    Text("\(remaining) / \(total)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                        .accessibilityLabel("残り \(remaining) 作品")
                        .accessibilityIdentifier("deck.remaining")
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
        // ロゴと重ならないよう、ヘッダーの文字の拡大は一定までにする
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private var filterButton: some View {
        Button(action: onFilterTap) {
            HStack(spacing: 4) {
                Image(systemName: filterCount > 0
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.title2)
                if filterCount > 0 {
                    Text("\(filterCount)")
                        .font(.caption.weight(.bold).monospacedDigit())
                }
            }
            .foregroundStyle(filterCount > 0 ? Theme.accent : .secondary)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
        }
        .accessibilityLabel(filterCount > 0 ? "ジャンルで絞り込み中（\(filterCount)件）" : "ジャンルで絞り込む")
        .accessibilityIdentifier("deck.filter")
    }
}
