//  SwipeHistoryStore.swift

import Foundation
import SwiftData

/// スワイプ履歴の読み書き（ViewModel はこのプロトコルだけに依存する。テストでは失敗する偽物に差し替える）
@MainActor
protocol SwipeHistoryStoring: AnyObject {
    /// すでに判定済みの作品ID
    func swipedIDs() -> Set<Int>
    /// おすすめ順の計算に使う判定履歴
    func history() -> [(genres: [String], action: SwipeAction)]
    /// 新しい順の判定履歴（取り消し用）
    func recentHistory(limit: Int) -> [(mangaID: Int, action: SwipeAction)]
    func record(_ manga: Manga, action: SwipeAction) throws
    func updateAction(mangaID: Int, to action: SwipeAction) throws
    func remove(mangaID: Int) throws
    /// 指定した判定の履歴を削除（nil なら全件）
    func removeAll(of action: SwipeAction?) throws
    /// 保存している作品情報のコピーを最新のデータで更新し、更新した件数を返す
    func refreshSnapshots(with mangas: [Manga]) throws -> Int
}

extension SwipeHistoryStoring {
    func removeAll() throws { try removeAll(of: nil) }
}

/// SwiftData を使った実装（ViewModel から SwiftData の詳細を隠す）
///
/// 書き込み系のメソッドは保存に失敗すると変更を取り消して（rollback）エラーを投げる。
/// 呼び出し側（ViewModel）は画面の状態を元に戻し、ユーザーに知らせる。
@MainActor
final class SwipeHistoryStore: SwipeHistoryStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 読み取り

    /// すでに判定済みの作品ID
    func swipedIDs() -> Set<Int> {
        Set(allRecords().map(\.mangaID))
    }

    /// おすすめ順の計算に使う判定履歴（ジャンルと判定のみ）
    func history() -> [(genres: [String], action: SwipeAction)] {
        allRecords().map { ($0.genres, $0.action) }
    }

    /// 新しい順の判定履歴（取り消し用）
    func recentHistory(limit: Int) -> [(mangaID: Int, action: SwipeAction)] {
        var descriptor = FetchDescriptor<SwipeRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit
        let records = (try? context.fetch(descriptor)) ?? []
        return records.map { ($0.mangaID, $0.action) }
    }

    // MARK: - 書き込み

    func record(_ manga: Manga, action: SwipeAction) throws {
        if let existing = find(mangaID: manga.id) {
            existing.action = action
            existing.createdAt = .now
        } else {
            context.insert(SwipeRecord(manga: manga, action: action))
        }
        try save()
    }

    /// 判定だけを変更する（判定した日時は変えないので、お気に入りの並び順は保たれる）
    func updateAction(mangaID: Int, to action: SwipeAction) throws {
        guard let record = find(mangaID: mangaID), record.action != action else { return }
        record.action = action
        try save()
    }

    func remove(mangaID: Int) throws {
        guard let record = find(mangaID: mangaID) else { return }
        context.delete(record)
        try save()
    }

    /// 指定した判定の履歴を削除（nil なら全件）
    func removeAll(of action: SwipeAction?) throws {
        for record in allRecords() where action == nil || record.action == action {
            context.delete(record)
        }
        try save()
    }

    func refreshSnapshots(with mangas: [Manga]) throws -> Int {
        let byID = Dictionary(mangas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var updated = 0
        for record in allRecords() {
            if let manga = byID[record.mangaID], record.refresh(from: manga) {
                updated += 1
            }
        }
        if updated > 0 { try save() }
        return updated
    }

    // MARK: - 内部

    private func allRecords() -> [SwipeRecord] {
        (try? context.fetch(FetchDescriptor<SwipeRecord>())) ?? []
    }

    private func find(mangaID: Int) -> SwipeRecord? {
        var descriptor = FetchDescriptor<SwipeRecord>(predicate: #Predicate { $0.mangaID == mangaID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            // 保存できなかった変更をメモリ上にも残さない
            context.rollback()
            throw error
        }
    }
}
