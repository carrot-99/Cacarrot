//  HeaderView.swift

import SwiftUI

/// ロゴと残り枚数を表示するヘッダー
struct HeaderView: View {
    let remaining: Int
    let total: Int

    var body: some View {
        ZStack {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 36)
                .accessibilityLabel("Cacarrot")

            HStack {
                Spacer()
                if total > 0 {
                    Text("\(remaining) / \(total)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                        .accessibilityLabel("残り \(remaining) 作品")
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
}
