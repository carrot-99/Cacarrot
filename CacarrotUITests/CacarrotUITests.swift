//  CacarrotUITests.swift

import XCTest

/// 主要な操作の流れを、実際の画面で確認する
///
/// アプリは `-uiTesting` で起動し、メモリ上のデータとサンプル6作品（おすすめ順オフ）を使う。
/// 端末に保存された履歴や設定には影響しない。
final class CacarrotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    private var remaining: XCUIElement { app.staticTexts["deck.remaining"] }

    private func closeGuide() {
        let close = app.buttons["guide.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), "初回起動では使い方が表示される")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 3))
    }

    private func waitForRemaining(_ count: Int, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label == %@", "残り \(count) 作品")
        expectation(for: predicate, evaluatedWith: remaining)
        waitForExpectations(timeout: 5)
    }

    func testLikeFromButtonThenUndo() {
        closeGuide()
        waitForRemaining(6)

        app.buttons["action.like"].tap()
        waitForRemaining(5)

        // お気に入りに入っている（おすすめ順オフなので先頭は ONE PIECE）
        app.tabBars.buttons["お気に入り"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["ONE PIECE"].waitForExistence(timeout: 3))

        // 取り消すとデッキに戻る
        app.tabBars.buttons["さがす"].firstMatch.tap()
        app.buttons["action.undo"].tap()
        waitForRemaining(6)
    }

    func testSwipeGesture() {
        closeGuide()
        waitForRemaining(6)
        let card = app.otherElements["deck.topCard"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.swipeLeft(velocity: .fast)
        waitForRemaining(5)
    }

    func testGenreFilter() {
        closeGuide()
        app.buttons["deck.filter"].tap()
        let gag = app.buttons.containing(.staticText, identifier: "ギャグ").firstMatch
        XCTAssertTrue(gag.waitForExistence(timeout: 3))
        gag.tap()
        app.buttons["完了"].tap()
        waitForRemaining(1)
        XCTAssertTrue(app.staticTexts["ボボボーボ・ボーボボ"].exists || app.otherElements["deck.topCard"].label.contains("ボボボーボ"))
    }

    func testJudgeFromDetailSheet() {
        closeGuide()
        let card = app.otherElements["deck.topCard"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.tap()
        let superLike = app.buttons["detail.superLike"]
        XCTAssertTrue(superLike.waitForExistence(timeout: 3), "デッキから開いた詳細には判定ボタンがある")
        superLike.tap()
        waitForRemaining(5)
    }
}
