import XCTest
@testable import CultureCore

final class SM2SchedulerTests: XCTestCase {
    let scheduler = SM2Scheduler(calendar: Fixtures.utcCalendar)
    let now = Fixtures.date("2026-11-22T10:00:00Z")

    func testKnownProgressesOneThenSixThenEase() {
        var s = ReviewState.new(now: now)
        s = scheduler.schedule(s, grade: .known, now: now)
        XCTAssertEqual(s.intervalDays, 1)
        XCTAssertEqual(s.due, Fixtures.date("2026-11-23T00:00:00Z"))
        s = scheduler.schedule(s, grade: .known, now: now)
        XCTAssertEqual(s.intervalDays, 6)
        let ease = s.easeFactor
        s = scheduler.schedule(s, grade: .known, now: now)
        XCTAssertEqual(s.intervalDays, Int((6 * ease).rounded()))
    }

    func testHardResetsToTomorrowAndCountsLapse() {
        var s = ReviewState.new(now: now)
        s = scheduler.schedule(s, grade: .known, now: now)
        s = scheduler.schedule(s, grade: .known, now: now)
        s = scheduler.schedule(s, grade: .hard, now: now)
        XCTAssertEqual(s.intervalDays, 1)
        XCTAssertEqual(s.repetitions, 0)
        XCTAssertEqual(s.lapses, 1)
        XCTAssertEqual(s.due, Fixtures.date("2026-11-23T00:00:00Z"))
    }

    func testReviewComesBackSoonerThanKnown() {
        var base = ReviewState.new(now: now)
        base = scheduler.schedule(base, grade: .known, now: now)
        base = scheduler.schedule(base, grade: .known, now: now) // interval 6
        let known = scheduler.schedule(base, grade: .known, now: now)
        let review = scheduler.schedule(base, grade: .review, now: now)
        XCTAssertLessThan(review.intervalDays, known.intervalDays)
        XCTAssertEqual(review.intervalDays, 7) // 6 × 1.2 rounded
        XCTAssertLessThan(review.easeFactor, known.easeFactor)
    }

    func testEaseNeverDropsBelowMinimum() {
        var s = ReviewState.new(now: now)
        for _ in 0..<20 { s = scheduler.schedule(s, grade: .hard, now: now) }
        XCTAssertEqual(s.easeFactor, SM2Scheduler.minimumEase, accuracy: 0.0001)
    }

    func testEveryGradeChangesTheNextReviewDate() {
        // Acceptance criterion: marking a card updates its next review date.
        let initial = ReviewState.new(now: now)
        for grade in ReviewGrade.allCases {
            let next = scheduler.schedule(initial, grade: grade, now: now)
            XCTAssertGreaterThan(next.due, initial.due, "\(grade)")
        }
    }

    func testDueQueueOrdersOverdueAndHardestFirst() {
        let early = ReviewState(easeFactor: 2.5, repetitions: 2, intervalDays: 6, due: Fixtures.date("2026-11-01T00:00:00Z"), lapses: 0, lastReviewed: nil)
        let hard = ReviewState(easeFactor: 1.3, repetitions: 1, intervalDays: 1, due: Fixtures.date("2026-11-20T00:00:00Z"), lapses: 0, lastReviewed: nil)
        let easy = ReviewState(easeFactor: 2.8, repetitions: 1, intervalDays: 1, due: Fixtures.date("2026-11-20T00:00:00Z"), lapses: 0, lastReviewed: nil)
        let future = ReviewState(easeFactor: 2.5, repetitions: 1, intervalDays: 1, due: Fixtures.date("2026-12-20T00:00:00Z"), lapses: 0, lastReviewed: nil)
        let queue = scheduler.dueQueue(["a": easy, "b": hard, "c": early, "d": future], now: now)
        XCTAssertEqual(queue, ["c", "b", "a"])
    }
}
