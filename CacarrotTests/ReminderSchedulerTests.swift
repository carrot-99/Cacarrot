//  ReminderSchedulerTests.swift

import XCTest
import UserNotifications
@testable import Cacarrot

/// 通知センターの偽物（登録内容を記録する）
final class FakeNotificationCenter: NotificationCentering, @unchecked Sendable {
    var granted = true
    private(set) var added: [UNNotificationRequest] = []
    private(set) var removed: [[String]] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { granted }
    func add(_ request: UNNotificationRequest) async throws { added.append(request) }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) { removed.append(identifiers) }
}

final class ReminderSchedulerTests: XCTestCase {
    func testScheduleRegistersDailyTriggerAtGivenTime() async throws {
        let center = FakeNotificationCenter()
        try await ReminderScheduler(center: center).schedule(minutes: 21 * 60 + 30)

        XCTAssertEqual(center.removed, [[ReminderScheduler.identifier]], "古い登録を消してから登録し直す")
        let request = try XCTUnwrap(center.added.first)
        XCTAssertEqual(request.identifier, ReminderScheduler.identifier)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 21)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
        XCTAssertFalse(request.content.title.isEmpty)
    }

    func testScheduleThrowsWhenDenied() async {
        let center = FakeNotificationCenter()
        center.granted = false
        do {
            try await ReminderScheduler(center: center).schedule(minutes: 0)
            XCTFail("許可されなければエラー")
        } catch {
            XCTAssertTrue(error is ReminderScheduler.ScheduleError)
        }
        XCTAssertTrue(center.added.isEmpty)
    }

    func testCancelRemovesPending() {
        let center = FakeNotificationCenter()
        ReminderScheduler(center: center).cancel()
        XCTAssertEqual(center.removed, [[ReminderScheduler.identifier]])
    }

    func testMinutesConversionRoundTripsAndClamps() {
        XCTAssertEqual(ReminderScheduler.dateComponents(minutes: -5).hour, 0)
        let late = ReminderScheduler.dateComponents(minutes: 9999)
        XCTAssertEqual(late.hour, 23)
        XCTAssertEqual(late.minute, 59)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let date = ReminderScheduler.date(fromMinutes: 7 * 60 + 5, calendar: calendar)
        XCTAssertEqual(ReminderScheduler.minutes(from: date, calendar: calendar), 7 * 60 + 5)
    }
}
