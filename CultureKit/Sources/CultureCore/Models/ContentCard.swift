import Foundation

public enum Topic: String, Codable, CaseIterable, Sendable, Identifiable {
    case art, music, history, politics, geopolitics, books, philosophy, vocabulary
    public var id: String { rawValue }

    /// Topics that have cards in the feed (vocabulary has its own deck).
    public static let feedTopics: [Topic] = [.art, .music, .history, .politics, .geopolitics, .books, .philosophy]

    public var localizationKey: String { "topic.\(rawValue)" }
    public var symbolName: String {
        switch self {
        case .art: "paintpalette"
        case .music: "music.note"
        case .history: "hourglass"
        case .politics: "building.columns"
        case .geopolitics: "globe.europe.africa"
        case .books: "books.vertical"
        case .philosophy: "lightbulb.max"
        case .vocabulary: "text.book.closed"
        }
    }
}

public struct MicroQuiz: Codable, Hashable, Sendable {
    public var question: LocalizedText
    public var options: [LocalizedText]
    public var answerIndex: Int
    public var explanation: LocalizedText

    public init(question: LocalizedText, options: [LocalizedText], answerIndex: Int, explanation: LocalizedText) {
        self.question = question
        self.options = options
        self.answerIndex = answerIndex
        self.explanation = explanation
    }

    public func isCorrect(_ index: Int) -> Bool { index == answerIndex }
}

public struct TimelineItem: Codable, Hashable, Sendable {
    public var date: String
    public var label: LocalizedText
}

/// Bibliographic details for cards in the "Livres" topic.
public struct BookInfo: Codable, Hashable, Sendable {
    public var author: String
    /// Date of writing or first publication, as displayed ("1513, publié en 1532").
    public var year: String
    /// Title in the original language (never translated).
    public var originalTitle: String
    /// A short quotation in the original language, from a public-domain text.
    public var quote: String?
    /// Translation of the quotation.
    public var quoteTranslation: LocalizedText?
    /// Where the quotation comes from ("chap. XVII").
    public var quoteSource: String?

    public init(author: String, year: String, originalTitle: String, quote: String? = nil,
                quoteTranslation: LocalizedText? = nil, quoteSource: String? = nil) {
        self.author = author
        self.year = year
        self.originalTitle = originalTitle
        self.quote = quote
        self.quoteTranslation = quoteTranslation
        self.quoteSource = quoteSource
    }
}

public struct ContentCard: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case standard, timeline, map }

    public var id: String
    public var topic: Topic
    public var kind: Kind
    public var title: LocalizedText
    public var body: LocalizedText
    public var takeaway: LocalizedText
    public var quiz: MicroQuiz?
    public var timeline: [TimelineItem]?
    public var image: LicensedImage?
    /// Extra images shown as a swipeable carousel after `image`.
    public var gallery: [LicensedImage]?
    /// Free-text suggestion for editors when no licensed image has been attached yet.
    public var imageSuggestion: String?
    /// Date the facts are valid for (mandatory on geopolitics cards).
    public var factsAsOf: String?
    public var tags: [String]
    public var editorial: EditorialInfo
    public var premium: Bool?
    /// Present on "Livres" cards.
    public var book: BookInfo?

    /// Main image first, then the gallery.
    public var images: [LicensedImage] { (image.map { [$0] } ?? []) + (gallery ?? []) }
}
