//  ProfileView.swift

import SwiftUI
import SwiftData

/// スワイプ統計と設定
struct ProfileView: View {
    @Environment(SwipeDeckViewModel.self) private var deck
    @Query private var records: [SwipeRecord]
    @State private var isConfirmingReset = false
    @State private var isShowingGuide = false
    @AppStorage(Haptics.settingKey) private var isHapticsEnabled = true

    private func closeGuide() {
        withAnimation(.easeOut(duration: 0.25)) { isShowingGuide = false }
    }

    var body: some View {
        // 履歴の集計は1回の走査で済ませる（判定が数千件になっても重くならないように）
        let stats = SwipeStats(records: records)
        let topGenres = stats.topGenres
        NavigationStack {
            List {
                Section("スワイプ統計") {
                    HStack {
                        StatTile(action: .like, value: stats.count(.like))
                        StatTile(action: .superLike, value: stats.count(.superLike))
                        StatTile(action: .nope, value: stats.count(.nope))
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))

                    if deck.totalCount > 0 {
                        let checked = deck.checkedCount
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
                            GenreBarRow(genre: item.genre, ratio: CGFloat(item.count) / CGFloat(maxCount))
                                .accessibilityElement(children: .combine)
                                .accessibilityValue("\(item.count)")
                        }
                    }
                }

                Section {
                    @Bindable var deck = deck
                    Toggle(isOn: $deck.isRecommendationEnabled) {
                        Label("おすすめ順で表示", systemImage: "sparkles")
                    }
                    Toggle(isOn: $isHapticsEnabled) {
                        Label("触覚フィードバック", systemImage: "hand.tap")
                    }
                    .onChange(of: isHapticsEnabled) { _, newValue in
                        Haptics.isEnabled = newValue
                    }
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { isShowingGuide = true }
                    } label: {
                        Label("使い方を見る", systemImage: "questionmark.circle")
                    }
                } footer: {
                    Text("いいねした作品のジャンルをもとに、好みに近い作品を先に表示します。オフにするとランダムな順番になります。")
                }

                Section {
                    NavigationLink {
                        SkippedListView()
                    } label: {
                        LabeledContent("スキップした作品", value: "\(stats.count(.nope))")
                    }
                    Button("すべての履歴をリセット", role: .destructive) { isConfirmingReset = true }
                        .disabled(records.isEmpty)
                } footer: {
                    Text("リセットすると、お気に入りを含むすべての判定が削除されます。")
                }

                Section("データ提供") {
                    if deck.usesRakutenData {
                        // 楽天ウェブサービスの規約で求められるクレジット表記
                        Link("Supported by Rakuten Developers",
                             destination: URL(string: "https://webservice.rakuten.co.jp/")!)
                        LabeledContent("作品情報・表紙", value: "楽天ブックス")
                        LabeledContent("ジャンル", value: "AniList")
                    } else {
                        LabeledContent("作品情報・表紙", value: "AniList")
                    }
                }
                .font(.footnote)
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
        .overlay {
            if isShowingGuide {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { closeGuide() }
                    SwipeGuideView(buttonTitle: "閉じる", onClose: closeGuide)
                }
                .transition(.opacity)
            }
        }
    }
}

/// 好きなジャンルの横棒。文字が大きい設定では、ジャンル名を棒の上に置く
private struct GenreBarRow: View {
    let genre: String
    let ratio: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Text(genre)
                bar
            }
        } else {
            HStack {
                Text(genre)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 110, alignment: .leading)
                bar
            }
        }
    }

    private var bar: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Theme.accent.gradient)
                .frame(width: proxy.size.width * ratio)
        }
        .frame(height: 10)
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
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
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
