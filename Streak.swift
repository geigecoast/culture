import Foundation

/// Daily streak with one forgiveness ("joker") day per ISO week.
///
/// A day counts as active when the user completed at least one card, quiz,
/// review session or attended event. One missed day per ISO week is forgiven;
/// a second missed day in the same week breaks the streak.
public struct StreakCalculator: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = StreakCalculator.isoCalendar()) {
        self.calendar = calendar
    }

    public static func isoCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        return calendar
    }

    public struct Result: Equatable, Sendable {
        /// Number of active days in the current streak (forgiven days are not counted).
        public var length: Int
        /// Days that were forgiven inside the current streak.
        public var forgivenDays: [Date]
        /// Whether the user has already been active today.
        public var activeToday: Bool
        /// Whether this week's forgiveness day is still available.
        public var forgivenessAvailableThisWeek: Bool
    }

    public func compute(activeDays: Set<Date>, today: Date) -> Result {
        let active = Set(activeDays.map { calendar.startOfDay(for: $0) })
        let todayStart = calendar.startOfDay(for: today)
        let activeToday = active.contains(todayStart)

        // Today not being active yet does not break the streak: start counting from yesterday.
        var cursor = activeToday ? todayStart : day(before: todayStart)
        var length = 0
        var forgiven: [Date] = []
        var forgivenWeeks: Set<WeekKey> = []
        var earliestCounted: Date?

        if let earliest = active.min() {
            while cursor >= earliest {
                if active.contains(cursor) {
                    length += 1
                    earliestCounted = cursor
                } else {
                    let week = weekKey(cursor)
                    if forgivenWeeks.contains(week) { break }
                    forgivenWeeks.insert(week)
                    forgiven.append(cursor)
                }
                cursor = day(before: cursor)
            }
        }
        // Forgiveness only bridges gaps between counted active days.
        if let earliestCounted {
            forgiven.removeAll { $0 < earliestCounted }
        } else {
            forgiven = []
        }

        let thisWeek = weekKey(todayStart)
        let usedThisWeek = forgiven.contains { weekKey($0) == thisWeek }
        return Result(length: length, forgivenDays: forgiven.sorted(), activeToday: activeToday,
                      forgivenessAvailableThisWeek: !usedThisWeek)
    }

    private struct WeekKey: Hashable { let year: Int; let week: Int }

    private func weekKey(_ date: Date) -> WeekKey {
        let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return WeekKey(year: c.yearForWeekOfYear ?? 0, week: c.weekOfYear ?? 0)
    }

    private func day(before date: Date) -> Date {
        calendar.date(byAdding: .day, value: -1, to: date) ?? date
    }
}
