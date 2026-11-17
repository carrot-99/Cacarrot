//  DailyPickTests.swift

import XCTest
@testable import Cacarrot

final class DailyPickTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    private func items(_ count: Int) -> [Manga] {
        (0..<count).map { Manga(id: $0, title: "T\($0)", author: "", genres: [], summary: "") }
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    func testSameDayGivesSameTitle() {
        let all = items(500)
        XCTAssertEqual(DailyPick.pick(from: all, on: date(17, hour: 0), calendar: calendar)?.id,
                       DailyPick.pick(from: all, on: date(17, hour: 23), calendar: calendar)?.id)
        XCTAssertNotEqual(DailyPick.pick(from: all, on: date(17), calendar: calendar)?.id,
                          DailyPick.pick(from: all, on: date(18), calendar: calendar)?.id)
    }

    func testCyclesThroughAllTitles() {
        for count in [1, 7, 500, 7919, 7919 * 2] {
            let all = items(count)
            let start = date(1)
            let ids = Set((0..<count).compactMap { offset in
                DailyPick.pick(from: all, on: calendar.date(byAdding: .day, value: offset, to: start)!,
                               calendar: calendar)?.id
            })
            XCTAssertEqual(ids.count, count, "\(count)作品なら\(count)日で一巡する")
        }
    }

    func testEmptyAndNextChange() {
        XCTAssertNil(DailyPick.pick(from: [], on: date(17), calendar: calendar))
        XCTAssertEqual(DailyPick.nextChange(after: date(17, hour: 15), calendar: calendar), date(18, hour: 0))
    }
}
