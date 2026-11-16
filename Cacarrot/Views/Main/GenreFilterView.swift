//  GenreFilterView.swift

import SwiftUI

/// デッキをジャンルで絞り込むシート（複数選択。いずれかのジャンルを含む作品を表示）
struct GenreFilterView: View {
    @Environment(SwipeDeckViewModel.self) private var deck
    @Environment(\.dismiss) private var dismiss

    /// 「完了」を押すまではデッキに反映しない
    @State private var draft: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(deck.availableGenres, id: \.name) { genre in
                        Button {
                            toggle(genre.name)
                        } label: {
                            HStack {
                                Text(genre.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(genre.count)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Image(systemName: draft.contains(genre.name) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(draft.contains(genre.name) ? Theme.accent : Color(.tertiaryLabel))
                                    .font(.title3)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(draft.contains(genre.name) ? .isSelected : [])
                    }
                } footer: {
                    Text("選んだジャンルのいずれかを含む作品だけをデッキに表示します。数字は作品数です。")
                }
            }
            .navigationTitle("ジャンルで絞り込む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("すべて解除") { draft.removeAll() }
                        .disabled(draft.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        deck.setGenreFilter(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear { draft = deck.selectedGenres }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // 半分の高さでも後ろのカードが透けて読みにくくならないよう、不透明な背景にする
        .presentationBackground(Color(.systemGroupedBackground))
    }

    private func toggle(_ genre: String) {
        if draft.contains(genre) {
            draft.remove(genre)
        } else {
            draft.insert(genre)
        }
        Haptics.selection()
    }
}

#Preview {
    PreviewContainer { GenreFilterView() }
}
