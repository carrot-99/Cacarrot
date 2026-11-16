//  ImageLoader.swift

import UIKit

/// 表紙画像の読み込みとキャッシュ
/// - メモリ: NSCache（デコード済みの UIImage。スワイプ中に再デコードしない）
/// - ディスク: 専用の URLCache（再起動後やオフライン時にも表示できる）
/// - 同じURLへの同時リクエストは1本にまとめる
final class ImageLoader: @unchecked Sendable {
    static let shared = ImageLoader()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private let lock = NSLock()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    enum LoadError: Error {
        case invalidImageData
    }

    init(memoryLimit: Int = 150 * 1024 * 1024,
         diskCapacity: Int = 300 * 1024 * 1024) {
        memoryCache.totalCostLimit = memoryLimit

        let cacheDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CoverImages", isDirectory: true)
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 0,
                                          diskCapacity: diskCapacity,
                                          directory: cacheDirectory)
        // 表紙は変わらないので、キャッシュがあればネットワークに問い合わせない
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 20
        session = URLSession(configuration: configuration)
    }

    /// メモリにある画像を同期的に返す（表示の一瞬のちらつきを防ぐ）
    func cachedImage(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    /// 画像を取得する（メモリ → ディスク → ネットワーク）
    func image(for url: URL) async throws -> UIImage {
        if let cached = cachedImage(for: url) { return cached }

        let task = lock.withLock {
            if let existing = inFlight[url] { return existing }
            let task = Task { [session] () throws -> UIImage in
                let (data, _) = try await session.data(from: url)
                guard let image = UIImage(data: data) else { throw LoadError.invalidImageData }
                // 表示前にデコードしておき、メインスレッドでの描画負荷を減らす
                return await image.byPreparingForDisplay() ?? image
            }
            inFlight[url] = task
            return task
        }

        defer { lock.withLock { inFlight[url] = nil } }
        let image = try await task.value
        memoryCache.setObject(image, forKey: url as NSURL, cost: image.memoryCost)
        return image
    }

    /// 次に表示する画像を先に読み込んでおく（失敗は無視）
    func prefetch(_ urls: [URL]) {
        for url in urls where cachedImage(for: url) == nil {
            Task.detached(priority: .utility) { [self] in
                _ = try? await image(for: url)
            }
        }
    }
}

private extension UIImage {
    /// NSCache のコスト計算用（デコード後のおおよそのバイト数）
    var memoryCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
