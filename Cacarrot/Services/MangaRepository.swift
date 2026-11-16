//  MangaRepository.swift

import Foundation

/// 作品データの取得元。将来 API / CSV / Firestore などに差し替えられるようプロトコル化
protocol MangaRepository: Sendable {
    func fetchAll() async throws -> [Manga]
}

/// アプリに同梱した manga.json（MangaInfoFetcher/build_app_data.py で生成）を読み込む
struct BundledMangaRepository: MangaRepository {
    enum LoadError: LocalizedError {
        case fileNotFound(String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let name): "\(name) がアプリに含まれていません"
            }
        }
    }

    var resourceName = "manga"
    var shuffled = true

    func fetchAll() async throws -> [Manga] {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw LoadError.fileNotFound("\(resourceName).json")
        }
        let items = try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode([Manga].self, from: Data(contentsOf: url))
        }.value
        return shuffled ? items.shuffled() : items
    }
}

/// プレビュー用の小さなサンプルデータ（ローカル画像を使用）
struct SampleMangaRepository: MangaRepository {
    func fetchAll() async throws -> [Manga] {
        Self.items
    }

    static let items: [Manga] = [
        Manga(id: 0, title: "ONE PIECE", author: "尾田栄一郎",
              genres: ["冒険", "バトル", "ファンタジー"],
              summary: "海賊王を目指す少年モンキー・D・ルフィと仲間たちが、伝説の秘宝「ひとつなぎの大秘宝」を求めて大海原を旅する冒険漫画。",
              imageName: "ONE PIECE"),
        Manga(id: 1, title: "DRAGON BALL", author: "鳥山明",
              genres: ["バトル", "冒険"],
              summary: "孫悟空が7つ集めると願いが叶う「ドラゴンボール」をめぐって、仲間やライバルと共に強敵へ立ち向かうバトル漫画。",
              imageName: "DRAGON BALL"),
        Manga(id: 2, title: "ボボボーボ・ボーボボ", author: "澤井啓夫",
              genres: ["ギャグ", "バトル"],
              summary: "鼻毛真拳の使い手ボーボボが、毛狩り隊からみんなの毛を守るために戦う不条理ギャグ漫画。",
              imageName: "ボボボーボ・ボーボボ"),
        Manga(id: 3, title: "あああああ", author: "あああああ",
              genres: ["ファンタジー"],
              summary: "サンプル作品です。ここに作品のあらすじが入ります。",
              imageName: "あああああ"),
        Manga(id: 4, title: "いいいいい", author: "いいいいいいい",
              genres: ["ファンタジー"],
              summary: "サンプル作品です。ここに作品のあらすじが入ります。",
              imageName: "いいいいい"),
        Manga(id: 5, title: "ううううううう", author: "ううううう",
              genres: ["ファンタジー"],
              summary: "サンプル作品です。ここに作品のあらすじが入ります。",
              imageName: "ううううううう"),
    ]
}
