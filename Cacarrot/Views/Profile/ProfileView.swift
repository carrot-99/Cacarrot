//  ProfileView.swift

import SwiftUI
import SwiftData

/// スワイプ統計と設定
struct ProfileView: View {
    @Environment(SwipeDeckViewModel.self) private var deck
    @Query private var records: [SwipeRecord]
    @State private var isConfirmingReset = false

    private func count(_ action: SwipeAction) -> Int {
        records.filter { $0.action == action }.count
    }

    /// 好きなジャンル（いいね・スーパーいいねした作品から集計）
    private var topGenres: [(genre: String, count: Int)] {
        var counts: [String: Int] = [:]
        for record in records where record.action != .nope {
            let weight = record.action == .superLike ? 2 : 1
            for genre in record.genres { counts[genre, default: 0] += weight }
        }
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(5)
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("スワイプ統計") {
                    HStack {
                        StatTile(action: .like, value: count(.like))
                        StatTile(action: .superLike, value: count(.superLike))
                        StatTile(action: .nope, value: count(.nope))
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))

                    if deck.totalCount > 0 {
                        let checked = deck.totalCount - deck.remainingCount
                        VStack(alignment: .leading, spacing: 6) {
                            Text("チェック済み \(checked) / \(deck.totalCount) 作品")
                                .font(.subheadline)
                            ProgressView(value: Double(checked), total: Double(deck.totalCount))
                        }
                    }
                }

                Section("好きなジャンル") {
                    if topGenres.isEmpty {
                        Text("いいねした作品からジャンルを集計します")
                            .foregroundStyle(.secondary)
                    } else {
                        let maxCount = topGenres.first?.count ?? 1
                        ForEach(topGenres, id: \.genre) { item in
                            HStack {
                                Text(item.genre)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(width: 110, alignment: .leading)
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(Theme.accent.gradient)
                                        .frame(width: proxy.size.width * CGFloat(item.count) / CGFloat(maxCount))
                                }
                                .frame(height: 10)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityValue("\(item.count)")
                        }
                    }
                }

                Section {
                    Button("スキップした作品をデッキに戻す") { deck.restoreSkipped() }
                        .disabled(count(.nope) == 0)
                    Button("すべての履歴をリセット", role: .destructive) { isConfirmingReset = true }
                        .disabled(records.isEmpty)
                } footer: {
                    Text("リセットすると、お気に入りを含むすべての判定が削除されます。")
                }
            }
            .navigationTitle("マイページ")
            .confirmationDialog("すべての履歴をリセットしますか？",
                                isPresented: $isConfirmingReset,
                                titleVisibility: .visible) {
                Button("リセット", role: .destructive) { deck.resetAll() }
            } message: {
                Text("この操作は取り消せません。")
            }
        }
    }
}

private struct StatTile: View {
    let action: SwipeAction
    let value: Int

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: action.systemImage)
                .font(.title3)
                .foregroundStyle(action.color)
            Text("\(value)")
                .font(.title2.bold().monospacedDigit())
                .contentTransition(.numericText())
            Text(action.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(action.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PreviewContainer { ProfileView() }
}
