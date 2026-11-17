//  CacarrotWidget.swift

import SwiftUI
import UIKit
import WidgetKit

/// ホーム画面の「今日の1冊」ウィジェット
///
/// アプリに同梱した manga.json から、日付で決めた1作品を表示する（DailyPick）。
/// ウィジェットはアプリの履歴（SwiftData）を読めないため、判定済みかどうかは考慮しない。
/// タップするとアプリが開く
@main
struct CacarrotWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyPickWidget()
    }
}

struct DailyPickWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyPick", provider: DailyPickProvider()) { entry in
            DailyPickView(entry: entry)
        }
        .configurationDisplayName("今日の1冊")
        .description("毎日1作品、おすすめの漫画を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
        // 小サイズは表紙を端まで表示するため、余白は各レイアウトで付ける
        .contentMarginsDisabled()
    }
}

struct DailyPickEntry: TimelineEntry {
    let date: Date
    let manga: Manga?
    let cover: UIImage?
}

struct DailyPickProvider: TimelineProvider {
    private static let sample = Manga(id: 0, title: "今日の1冊", author: "Cacarrot",
                                      genres: ["冒険", "バトル"], summary: "")

    func placeholder(in context: Context) -> DailyPickEntry {
        DailyPickEntry(date: .now, manga: Self.sample, cover: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyPickEntry) -> Void) {
        Task { completion(await makeEntry(for: .now)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyPickEntry>) -> Void) {
        Task {
            let now = Date.now
            let entry = await makeEntry(for: now)
            // 日付が変わったら次の作品にする
            completion(Timeline(entries: [entry], policy: .after(DailyPick.nextChange(after: now))))
        }
    }

    private func makeEntry(for date: Date) async -> DailyPickEntry {
        let manga = DailyPick.pick(from: Self.loadAll(), on: date)
        let cover = await manga?.imageURL.asyncMap(Self.loadCover)
        return DailyPickEntry(date: date, manga: manga, cover: cover ?? nil)
    }

    private static func loadAll() -> [Manga] {
        guard let url = Bundle.main.url(forResource: "manga", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Manga].self, from: data)) ?? []
    }

    /// 表紙を取得して縮小する（ウィジェットはメモリの上限が小さいため）
    private static func loadCover(_ url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 300
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        guard scale < 1 else { return image }
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

private extension Optional {
    func asyncMap<T>(_ transform: (Wrapped) async -> T) async -> T? {
        guard let value = self else { return nil }
        return await transform(value)
    }
}

// MARK: - 表示

private let accent = Color(red: 0.976, green: 0.478, blue: 0.122)

struct DailyPickView: View {
    let entry: DailyPickEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let manga = entry.manga {
                switch family {
                case .systemMedium: medium(manga)
                default: small(manga)
                }
            } else {
                Text("作品を読み込めませんでした")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private func small(_ manga: Manga) -> some View {
        ZStack(alignment: .bottomLeading) {
            cover
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text("今日の1冊")
                    .font(.caption2.bold())
                    .foregroundStyle(accent)
                Text(manga.title)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(10)
        }
        .widgetAccentable()
    }

    private func medium(_ manga: Manga) -> some View {
        HStack(spacing: 12) {
            cover
                .frame(width: 96)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("今日の1冊")
                    .font(.caption.bold())
                    .foregroundStyle(accent)
                Text(manga.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(manga.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(manga.genres.prefix(3).joined(separator: " ・ "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    @ViewBuilder
    private var cover: some View {
        if let image = entry.cover {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                accent.opacity(0.15)
                Image(systemName: "book.closed.fill")
                    .font(.largeTitle)
                    .foregroundStyle(accent)
            }
        }
    }
}

#Preview(as: .systemMedium) {
    DailyPickWidget()
} timeline: {
    DailyPickEntry(date: .now, manga: Manga(id: 1, title: "サンプル作品のタイトル", author: "作者",
                                            genres: ["冒険", "バトル", "ファンタジー"], summary: ""),
                   cover: nil)
}
