//  SwipeGuideView.swift

import SwiftUI

/// スワイプ操作の説明（初回起動時と、マイページの「使い方」から表示）
struct SwipeGuideView: View {
    var buttonTitle: String = "はじめる"
    var onClose: () -> Void

    private struct Step: Identifiable {
        let id = UUID()
        let gesture: String
        let action: SwipeAction?
        let icon: String
        let color: Color
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(gesture: "arrow.right", action: .like, icon: SwipeAction.like.systemImage, color: Theme.like,
             title: "右にスワイプ：いいね", detail: "気になる作品はお気に入りに入ります"),
        Step(gesture: "arrow.left", action: .nope, icon: SwipeAction.nope.systemImage, color: Theme.nope,
             title: "左にスワイプ：スキップ", detail: "あとでマイページから戻せます"),
        Step(gesture: "arrow.up", action: .superLike, icon: SwipeAction.superLike.systemImage, color: Theme.superLike,
             title: "上にスワイプ：スーパーいいね", detail: "特に読みたい作品に。おすすめに強く反映されます"),
        Step(gesture: "hand.tap", action: nil, icon: "info.circle.fill", color: Theme.accent,
             title: "タップ：詳細を見る", detail: "あらすじの全文を読んで、そのまま判定できます"),
    ]

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .accessibilityLabel("Cacarrot")
                Text("スワイプで、次に読む漫画を見つけよう")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 18) {
                ForEach(steps) { step in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(step.color.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: step.icon)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(step.color)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: step.gesture)
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(step.color, in: Circle())
                                .offset(x: 4, y: 4)
                        }
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.subheadline.weight(.semibold))
                            Text(step.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.4).ignoresSafeArea()
        SwipeGuideView(onClose: {})
    }
}
