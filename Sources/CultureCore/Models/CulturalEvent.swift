import Foundation

/// A supported city. The time zone is stored per city; code must never assume
/// two cities share a zone just because Frankfurt and München do today.
public struct City: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: LocalizedText
    public var timeZoneID: String
    public var latitude: Double
    public var longitude: Double

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .gmt }

    public init(id: String, name: LocalizedText, timeZoneID: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.timeZoneID = timeZoneID
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Returns the city closest to a coordinate (used once, on demand, when location is granted).
    public static func nearest(to latitude: Double, _ longitude: Double, in cities: [City]) -> City? {
        cities.min { lhs, rhs in
            lhs.squaredDistance(latitude, longitude) < rhs.squaredDistance(latitude, longitude)
        }
    }

    private func squaredDistance(_ lat: Double, _ lon: Double) -> Double {
        // Equirectangular approximation: fine for picking among a handful of cities.
        let x = (lon - longitude) * cos((lat + latitude) / 2 * .pi / 180)
        let y = lat - latitude
        return x * x + y * y
    }
}

public enum EventCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case operaBallet = "opera_ballet"
    case classical
    case jazzWorld = "jazz_world"
    case theatreDance = "theatre_dance"
    case exhibitions
    case science
    case literatureCinema = "literature_cinema"

    public var id: String { rawValue }
    public var localizationKey: String { "category.\(rawValue)" }
}

public struct Venue: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    /// Venue names are never translated.
    public var name: String
    public var cityID: String
    public var address: String
    public var latitude: Double
    public var longitude: Double
    public var website: URL?
    /// Editorial note, e.g. closures for renovation.
    public var note: LocalizedText?
}

public struct PriceRange: Codable, Hashable, Sendable {
    public var minEUR: Decimal?
    public var maxEUR: Decimal?
    public var isFree: Bool

    public static let free = PriceRange(minEUR: 0, maxEUR: 0, isFree: true)
}

public enum EventStatus: String, Codable, Sendable {
    case scheduled, cancelled, moved
    case soldOut = "sold_out"
}

public struct CulturalEvent: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    /// Title in its original language.
    public var title: String
    public var description: LocalizedText?
    public var category: EventCategory
    public var cityID: String
    public var venueID: String
    public var start: Date
    public var end: Date?
    /// IANA time zone of the venue. Always stored explicitly with the event.
    public var timeZoneID: String
    public var price: PriceRange
    public var officialURL: URL
    public var sourceName: String
    public var lastChecked: Date
    public var status: EventStatus
    public var statusNote: LocalizedText?
    /// Licensed image (venue photo or a public-domain artwork matching the programme).
    public var image: LicensedImage?
    public var editorialStatus: EditorialStatus
    /// True for seed examples that do not correspond to a verified listing.
    public var isSample: Bool?

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .gmt }
    public var isCancelled: Bool { status == .cancelled }
}

public enum RSVPState: String, Codable, CaseIterable, Sendable {
    case interested, going, maybe
    public var localizationKey: String { "rsvp.\(rawValue)" }
}

/// Who can see a user's attendance. Private is the default.
public enum AttendanceVisibility: String, Codable, CaseIterable, Sendable {
    case `private`, friends, `public`
}
