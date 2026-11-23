import Foundation
@testable import CultureCore

enum Fixtures {
    static let paris = City(id: "paris", name: .init(fr: "Paris", en: "Paris"), timeZoneID: "Europe/Paris", latitude: 48.8566, longitude: 2.3522)
    static let frankfurt = City(id: "frankfurt", name: .init(fr: "Francfort", en: "Frankfurt"), timeZoneID: "Europe/Berlin", latitude: 50.1109, longitude: 8.6821)
    static let munich = City(id: "munich", name: .init(fr: "Munich", en: "Munich"), timeZoneID: "Europe/Berlin", latitude: 48.1351, longitude: 11.5820)

    static func date(_ iso: String) -> Date { ContentDecoder.parseISO8601(iso)! }

    static func event(id: String = "e1", start: String, end: String? = nil, city: String = "paris",
                      tz: String = "Europe/Paris", category: EventCategory = .operaBallet,
                      price: PriceRange = PriceRange(minEUR: 15, maxEUR: 210, isFree: false)) -> CulturalEvent {
        CulturalEvent(id: id, title: "Test", description: nil, category: category, cityID: city, venueID: "v",
                      start: date(start), end: end.map(date), timeZoneID: tz, price: price,
                      officialURL: URL(string: "https://example.org")!, sourceName: "Test",
                      lastChecked: date("2026-11-20T08:00:00Z"), status: .scheduled, statusNote: nil,
                      image: nil, editorialStatus: .published, isSample: true)
    }

    static func card(_ id: String, _ topic: Topic) -> ContentCard {
        ContentCard(id: id, topic: topic, kind: .standard, title: .init(fr: "t", en: "t"), body: .init(fr: "b", en: "b"),
                    takeaway: .init(fr: "k", en: "k"), quiz: nil, timeline: nil, image: nil, gallery: nil, imageSuggestion: nil,
                    factsAsOf: topic == .geopolitics ? "2026-11-01" : nil, tags: [],
                    editorial: .init(status: .published, sources: [.init(title: "S")], lastReviewed: "2026-11-01", reviewer: "R"),
                    premium: nil, book: nil)
    }

    static var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
}
