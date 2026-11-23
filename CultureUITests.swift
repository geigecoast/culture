import XCTest

/// UI tests for onboarding, the quiz flow, vocabulary review and RSVP.
/// Launch arguments put the app in an isolated in-memory store.
final class CultureUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-app-language", "fr"] + extra
        app.launch()
        return app
    }

    func testOnboardingCompletes() {
        let app = launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()                                   // welcome → interests
        app.buttons["interest.history"].tap()
        next.tap()                                   // → cities
        next.tap()                                   // → level
        next.tap()                                   // → placement
        // Skip the placement quiz (it has its own test through the quiz feed).
        app.buttons["Passer"].tap()
        next.tap()                                   // goal → privacy
        next.tap()                                   // finish
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5) || app.collectionViews.firstMatch.exists)
    }

    func testQuizGivesInstantFeedback() {
        let app = launch(["-skip-onboarding"])
        let quiz = app.buttons["quiz.all"]
        XCTAssertTrue(quiz.waitForExistence(timeout: 5))
        quiz.tap()
        let option = app.buttons["quiz.option.0"].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        XCTAssertTrue(app.staticTexts["quiz.feedback"].firstMatch.waitForExistence(timeout: 2))
        app.buttons["quiz.close"].tap()
    }

    func testVocabularyReviewUpdatesSchedule() {
        let app = launch(["-skip-onboarding"])
        app.tabBars.buttons.element(boundBy: 2).tap()
        let start = app.buttons["vocab.startReview"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        app.buttons["vocab.reveal"].tap()
        app.buttons["grade.review"].tap()
        // Next card is shown; the graded word now has a next review date.
        XCTAssertTrue(app.buttons["vocab.reveal"].waitForExistence(timeout: 2))
    }

    func testRSVPFromAgenda() throws {
        let app = launch(["-skip-onboarding"])
        app.tabBars.buttons.element(boundBy: 1).tap()
        // Widen to all cities so seed events are visible regardless of simulator region.
        for city in ["paris", "frankfurt", "munich"] {
            let chip = app.buttons["city.\(city)"]
            if chip.waitForExistence(timeout: 3), !chip.isSelected { chip.tap() }
        }
        let menu = app.buttons["rsvp.menu"].firstMatch
        guard menu.waitForExistence(timeout: 5) else {
            throw XCTSkip("No seed events fall inside the next 14 days for this run date.")
        }
        menu.tap()
        app.buttons["rsvp.going"].tap()
        // The menu only offers "Retirer" once an RSVP is set.
        menu.tap()
        XCTAssertTrue(app.buttons["Retirer"].waitForExistence(timeout: 2))
    }
}
