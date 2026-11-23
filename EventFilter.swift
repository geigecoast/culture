import Foundation

public struct EventFilter: Equatable, Sendable {
    public var cityIDs: Set<String>
    public var categories: Set<EventCategory>
    public var freeOnly: Bool
    public var days: Int

    public static let defaultDays = 14

    public init(cityIDs: Set<String>, categories: Set<EventCategory> = [], freeOnly: Bool = false, days: Int = EventFilter.defaultDays) {
        self.cityIDs = cityIDs
        self.categories = categories
        self.freeOnly = freeOnly
        self.days = days
    }

    /// Empty `categories` means "all categories".
    public func apply(to events: [CulturalEvent], now: Date, schedule: EventSchedule = .init()) -> [CulturalEvent] {
        events
            .filter { cityIDs.contains($0.cityID) }
            .filter { categories.isEmpty || categories.contains($0.category) }
            .filter { !freeOnly || $0.price.isFree }
            .filter { schedule.isWithin($0, days: days, from: now) }
            .sorted { $0.start < $1.start }
    }

    /// Suggestions offered by the empty state.
    public enum Widening: Hashable, Sendable { case extendDays(to: Int), addCity, clearCategories }

    public func wideningSuggestions(allCityIDs: Set<String>) -> [Widening] {
        var result: [Widening] = []
        if days < 60 { result.append(.extendDays(to: days < 30 ? 30 : 60)) }
        if !categories.isEmpty || freeOnly { result.append(.clearCategories) }
        if !allCityIDs.subtracting(cityIDs).isEmpty { result.append(.addCity) }
        return result
    }
}

/// Picks the default cities for a new user: the nearest city if location was granted,
/// otherwise a city matching the device region, otherwise Paris.
public enum DefaultCityResolver {
    public static func resolve(cities: [City], nearestCityID: String?, regionCode: String?) -> Set<String> {
        if let nearestCityID, cities.contains(where: { $0.id == nearestCityID }) { return [nearestCityID] }
        if regionCode == "DE", let frankfurt = cities.first(where: { $0.id == "frankfurt" }) { return [frankfurt.id] }
        return [cities.first(where: { $0.id == "paris" })?.id ?? cities.first?.id ?? "paris"]
    }
}
