import XCTest
@testable import CultureCore

final class StreakCalculatorTests: XCTestCase {
    var calc: StreakCalculator!
    var cal: Calendar!

    override func setUp() {
        cal = StreakCalculator.isoCalendar(timeZone: TimeZone(identifier: "Europe/Paris")!)
        calc = StreakCalculator(calendar: cal)
    }

    /// Sunday 22 November 2026 at noon in Paris.
    var today: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 12))! }
    func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)! }

    func testConsecutiveDays() {
        let r = calc.compute(activeDays: [daysAgo(0), daysAgo(1), daysAgo(2)], today: today)
        XCTAssertEqual(r.length, 3)
        XCTAssertTrue(r.activeToday)
        XCTAssertTrue(r.forgivenDays.isEmpty)
    }

    func testTodayNotYetActiveKeepsStreak() {
        let r = calc.compute(activeDays: [daysAgo(1), daysAgo(2)], today: today)
        XCTAssertEqual(r.length, 2)
        XCTAssertFalse(r.activeToday)
    }

    func testOneMissedDayInAWeekIsForgiven() {
        // Missed Friday 20 Nov; Sat, Sun and Wed/Thu active.
        let r = calc.compute(activeDays: [daysAgo(0), daysAgo(1), daysAgo(3), daysAgo(4)], today: today)
        XCTAssertEqual(r.length, 4)
        XCTAssertEqual(r.forgivenDays, [cal.startOfDay(for: daysAgo(2))])
        XCTAssertFalse(r.forgivenessAvailableThisWeek)
    }

    func testTwoMissedDaysInSameWeekBreakStreak() {
        // Missed Fri 20 and Wed 18 (same ISO week).
        let r = calc.compute(activeDays: [daysAgo(0), daysAgo(1), daysAgo(3), daysAgo(5)], today: today)
        XCTAssertEqual(r.length, 3)
    }

    func testMissedDaysInDifferentWeeksAreBothForgiven() {
        // Missed Sat 21 Nov (ISO week 47) and Sun 15 Nov (ISO week 46).
        var days: Set<Date> = [daysAgo(0)]
        for n in 2...6 { days.insert(daysAgo(n)) }
        for n in 8...9 { days.insert(daysAgo(n)) }
        let r = calc.compute(activeDays: days, today: today)
        XCTAssertEqual(r.length, 8)
        XCTAssertEqual(r.forgivenDays.count, 2)
    }

    func testForgivenDayWithoutActivityBehindItIsNotCounted() {
        // Active today only; yesterday and the day before missed.
        let r = calc.compute(activeDays: [daysAgo(0), daysAgo(10)], today: today)
        XCTAssertEqual(r.length, 1)
        XCTAssertTrue(r.forgivenDays.isEmpty)
        XCTAssertTrue(r.forgivenessAvailableThisWeek)
    }

    func testNoActivity() {
        let r = calc.compute(activeDays: [], today: today)
        XCTAssertEqual(r.length, 0)
    }
}
