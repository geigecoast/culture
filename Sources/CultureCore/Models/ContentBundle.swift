import Foundation

/// Versioned content delivered by the backend (or bundled as seed) and cached locally.
public struct ContentBundle: Codable, Sendable {
    public var version: Int
    public var generatedAt: Date
    public var cards: [ContentCard]
    public var vocab: [VocabEntry]
    public var vocabSets: [VocabSet]
    public var cities: [City]
    public var venues: [Venue]
    public var events: [CulturalEvent]
    public var placementQuiz: [PlacementQuestion]

    public static let empty = ContentBundle(
        version: 0, generatedAt: .distantPast, cards: [], vocab: [], vocabSets: [],
        cities: [], venues: [], events: [], placementQuiz: []
    )

    public init(version: Int, generatedAt: Date, cards: [ContentCard], vocab: [VocabEntry], vocabSets: [VocabSet],
                cities: [City], venues: [Venue], events: [CulturalEvent], placementQuiz: [PlacementQuestion]) {
        self.version = version
        self.generatedAt = generatedAt
        self.cards = cards
        self.vocab = vocab
        self.vocabSets = vocabSets
        self.cities = cities
        self.venues = venues
        self.events = events
        self.placementQuiz = placementQuiz
    }

    /// Returns a copy keeping only what this build may display.
    public func filtered(for visibility: ContentVisibility) -> ContentBundle {
        var copy = self
        copy.cards = cards.filter { visibility.allows($0.editorial.status) }
        copy.vocab = vocab.filter { visibility.allows($0.editorial.status) }
        copy.events = events.filter { visibility.allows($0.editorialStatus) }
        return copy
    }

    public func city(_ id: String) -> City? { cities.first { $0.id == id } }
    public func venue(_ id: String) -> Venue? { venues.first { $0.id == id } }
}

public struct PlacementQuestion: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var topic: Topic
    public var quiz: MicroQuiz
}

public enum ContentDecoder {
    /// Decoder matching the JSON produced by the editor (ISO-8601 dates with offsets).
    public static func make() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parseISO8601(raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(raw)")
        }
        return decoder
    }

    public static func parseISO8601(_ raw: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return withFraction.date(from: raw) ?? plain.date(from: raw)
    }

    public static func bundle(from data: Data) throws -> ContentBundle {
        try make().decode(ContentBundle.self, from: data)
    }
}
