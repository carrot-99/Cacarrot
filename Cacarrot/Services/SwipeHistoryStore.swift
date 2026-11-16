//  SwipeHistoryStore.swift

import Foundation
import SwiftData

/// スワイプ履歴の読み書きを担当（ViewModel から SwiftData の詳細を隠す）
@MainActor
final class SwipeHistoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// すでに判定済みの作品ID
    func swipedIDs() -> Set<Int> {
        let records = (try? context.fetch(FetchDescriptor<SwipeRecord>())) ?? []
        return Set(records.map(\.mangaID))
    }

    func record(_ manga: Manga, action: SwipeAction) {
        if let existing = find(mangaID: manga.id) {
            existing.action = action
            existing.createdAt = .now
        } else {
            context.insert(SwipeRecord(manga: manga, action: action))
        }
        save()
    }

    func remove(mangaID: Int) {
        guard let record = find(mangaID: mangaID) else { return }
        context.delete(record)
        save()
    }

    /// 指定した判定の履歴を削除（nil なら全件）
    func removeAll(of action: SwipeAction? = nil) {
        let records = (try? context.fetch(FetchDescriptor<SwipeRecord>())) ?? []
        for record in records where action == nil || record.action == action {
            context.delete(record)
        }
        save()
    }

    private func find(mangaID: Int) -> SwipeRecord? {
        var descriptor = FetchDescriptor<SwipeRecord>(predicate: #Predicate { $0.mangaID == mangaID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("SwipeHistoryStore save failed: \(error)")
        }
    }
}
