import Foundation

/// Time-zone-correct date logic for events.
///
/// Rule: an event's date and time are always shown in the **venue's** time zone,
/// whatever zone the device is in. A 23:30 performance in Paris is "31 décembre, 23:30"
/// for a user in Paris, Frankfurt, München or New York.
public struct EventSchedule: Sendable {
    public init() {}

    /// Calendar pinned to the event's own time zone.
    public func venueCalendar(for event: CulturalEvent) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = event.timeZone
        return calendar
    }

    /// Year/month/day of the event start, in the venue's time zone.
    public func localDay(of event: CulturalEvent) -> DateComponents {
        venueCalendar(for: event).dateComponents([.year, .month, .day], from: event.start)
    }

    /// A stable key ("2026-12-31") used to group agenda rows by local day.
    public func dayKey(of event: CulturalEvent) -> String {
        let c = localDay(of: event)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Groups events by their local day (venue time zone), sorted chronologically.
    public func groupedByDay(_ events: [CulturalEvent]) -> [(dayKey: String, events: [CulturalEvent])] {
        let groups = Dictionary(grouping: events, by: dayKey(of:))
        return groups.keys.sorted().map { key in
            (key, groups[key]!.sorted { $0.start < $1.start })
        }
    }

    /// Formats the start date in the venue's time zone and the user's UI language.
    public func formattedStart(_ event: CulturalEvent, language: AppLanguage,
                               dateStyle: Date.FormatStyle.DateStyle = .abbreviated) -> String {
        var style = Date.FormatStyle(date: dateStyle, time: .shortened)
        style.timeZone = event.timeZone
        style.locale = language.locale
        return event.start.formatted(style)
    }

    public func formattedTime(_ date: Date, in timeZone: TimeZone, language: AppLanguage) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        style.locale = language.locale
        return date.formatted(style)
    }

    /// Fire date for a "Rappel" one day before the start (same local wall-clock time).
    public func reminderDate(for event: CulturalEvent, daysBefore: Int = 1) -> Date? {
        venueCalendar(for: event).date(byAdding: .day, value: -daysBefore, to: event.start)
    }

    /// Whether the event starts within [from, from + days) measured in local days of the venue.
    public func isWithin(_ event: CulturalEvent, days: Int, from now: Date) -> Bool {
        let calendar = venueCalendar(for: event)
        let startOfToday = calendar.startOfDay(for: now)
        guard let limit = calendar.date(byAdding: .day, value: days, to: startOfToday) else { return false }
        let ends = event.end ?? event.start
        return ends >= now && event.start < limit
    }
}

/// Formats prices in euros using the user's locale.
public enum PriceFormatter {
    public static func string(for price: PriceRange, language: AppLanguage, freeLabel: String) -> String {
        if price.isFree { return freeLabel }
        let style = Decimal.FormatStyle.Currency(code: "EUR", locale: language.locale).precision(.fractionLength(0...2))
        switch (price.minEUR, price.maxEUR) {
        case let (min?, max?) where min != max: return "\(min.formatted(style)) – \(max.formatted(style))"
        case let (min?, _): return min.formatted(style)
        case let (nil, max?): return max.formatted(style)
        default: return "—"
        }
    }
}
