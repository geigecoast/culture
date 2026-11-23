import XCTest
@testable import CultureCore

final class EventScheduleTests: XCTestCase {
    let schedule = EventSchedule()

    /// Acceptance criterion: an event at 23:30 in Paris shows the correct local date
    /// in Frankfurt and München, with no off-by-one error.
    func testLateParisEventKeepsLocalDate() {
        // 31 Dec 2026, 23:30 Paris (UTC+1) = 22:30 UTC.
        let event = Fixtures.event(start: "2026-12-31T23:30:00+01:00")
        XCTAssertEqual(schedule.dayKey(of: event), "2026-12-31")

        let fr = schedule.formattedStart(event, language: .fr, dateStyle: .long)
        XCTAssertTrue(fr.contains("31"), fr)
        XCTAssertTrue(fr.contains("décembre"), fr)
        XCTAssertTrue(fr.contains("23:30"), fr)
    }

    func testDateDoesNotDependOnDeviceTimeZone() {
        let event = Fixtures.event(start: "2026-12-31T23:30:00+01:00")
        for deviceZone in ["Europe/Berlin", "America/New_York", "Asia/Tokyo", "UTC"] {
            NSTimeZone.default = TimeZone(identifier: deviceZone)!
            XCTAssertEqual(schedule.dayKey(of: event), "2026-12-31", deviceZone)
            XCTAssertTrue(schedule.formattedStart(event, language: .en).contains("Dec 31"), deviceZone)
        }
        NSTimeZone.default = .current
    }

    func testMunichEventShownInBerlinTime() {
        let event = Fixtures.event(start: "2026-07-15T19:00:00+02:00", city: "munich", tz: "Europe/Berlin")
        XCTAssertEqual(schedule.formattedTime(event.start, in: event.timeZone, language: .fr), "19:00")
    }

    func testDSTTransitionDay() {
        // Clocks go back on 25 Oct 2026 in Europe. 23:30 local is still the 25th.
        let event = Fixtures.event(start: "2026-10-25T23:30:00+01:00")
        XCTAssertEqual(schedule.dayKey(of: event), "2026-10-25")
    }

    func testGroupingUsesVenueDay() {
        let a = Fixtures.event(id: "a", start: "2026-12-31T23:30:00+01:00")
        let b = Fixtures.event(id: "b", start: "2027-01-01T00:15:00+01:00")
        let c = Fixtures.event(id: "c", start: "2026-12-31T19:00:00+01:00")
        let groups = schedule.groupedByDay([a, b, c])
        XCTAssertEqual(groups.map(\.dayKey), ["2026-12-31", "2027-01-01"])
        XCTAssertEqual(groups[0].events.map(\.id), ["c", "a"])
    }

    func testReminderIsOneDayBeforeAtSameWallClockAcrossDST() {
        // Event Sunday 29 March 2026 20:00 CEST (DST started that morning).
        let event = Fixtures.event(start: "2026-03-29T20:00:00+02:00")
        let reminder = schedule.reminderDate(for: event)!
        XCTAssertEqual(reminder, Fixtures.date("2026-03-28T20:00:00+01:00"))
    }

    func testPriceFormatting() {
        let range = PriceRange(minEUR: 15, maxEUR: 210, isFree: false)
        let fr = PriceFormatter.string(for: range, language: .fr, freeLabel: "Gratuit")
        XCTAssertTrue(fr.contains("€"), fr)
        XCTAssertEqual(PriceFormatter.string(for: .free, language: .fr, freeLabel: "Gratuit"), "Gratuit")
    }
}

final class EventFilterTests: XCTestCase {
    let now = Fixtures.date("2026-11-22T10:00:00+01:00")

    func testFiltersByCityCategoryFreeAndWindow() {
        let events = [
            Fixtures.event(id: "paris-opera", start: "2026-11-25T19:30:00+01:00"),
            Fixtures.event(id: "ffm-free", start: "2026-11-26T18:00:00+01:00", city: "frankfurt", tz: "Europe/Berlin", category: .science, price: .free),
            Fixtures.event(id: "ffm-late", start: "2026-12-20T18:00:00+01:00", city: "frankfurt", tz: "Europe/Berlin"),
            Fixtures.event(id: "past", start: "2026-11-21T18:00:00+01:00", city: "frankfurt", tz: "Europe/Berlin")
        ]
        XCTAssertEqual(EventFilter(cityIDs: ["frankfurt"]).apply(to: events, now: now).map(\.id), ["ffm-free"])
        XCTAssertEqual(EventFilter(cityIDs: ["frankfurt", "paris"], days: 30).apply(to: events, now: now).map(\.id),
                       ["paris-opera", "ffm-free", "ffm-late"])
        XCTAssertEqual(EventFilter(cityIDs: ["frankfurt", "paris"], freeOnly: true).apply(to: events, now: now).map(\.id), ["ffm-free"])
        XCTAssertEqual(EventFilter(cityIDs: ["paris", "frankfurt"], categories: [.operaBallet]).apply(to: events, now: now).map(\.id), ["paris-opera"])
    }

    func testOngoingExhibitionStillListed() {
        let expo = Fixtures.event(id: "expo", start: "2026-10-01T10:00:00+02:00", end: "2027-01-31T18:00:00+01:00", category: .exhibitions)
        XCTAssertEqual(EventFilter(cityIDs: ["paris"]).apply(to: [expo], now: now).map(\.id), ["expo"])
    }

    func testWideningSuggestions() {
        let filter = EventFilter(cityIDs: ["paris"], categories: [.science])
        XCTAssertEqual(filter.wideningSuggestions(allCityIDs: ["paris", "frankfurt", "munich"]),
                       [.extendDays(to: 30), .clearCategories, .addCity])
    }

    /// Acceptance criterion: a new user in Frankfurt sees Frankfurt by default.
    func testDefaultCityFromLocationOrRegion() {
        let cities = [Fixtures.paris, Fixtures.frankfurt, Fixtures.munich]
        let nearest = City.nearest(to: 50.10, 8.67, in: cities)
        XCTAssertEqual(nearest?.id, "frankfurt")
        XCTAssertEqual(DefaultCityResolver.resolve(cities: cities, nearestCityID: nearest?.id, regionCode: "FR"), ["frankfurt"])
        XCTAssertEqual(DefaultCityResolver.resolve(cities: cities, nearestCityID: nil, regionCode: "DE"), ["frankfurt"])
        XCTAssertEqual(DefaultCityResolver.resolve(cities: cities, nearestCityID: nil, regionCode: "FR"), ["paris"])
        XCTAssertEqual(City.nearest(to: 48.14, 11.58, in: cities)?.id, "munich")
    }
}
