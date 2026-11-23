import Foundation

public enum Topic: String, Codable, CaseIterable, Sendable, Identifiable {
    case art, music, history, politics, geopolitics, vocabulary
    public var id: String { rawValue }

    /// Topics that have cards in the feed (vocabulary has its own deck).
    public static let feedTopics: [Topic] = [.art, .music, .history, .politics, .geopolitics]

    public var localizationKey: String { "topic.\(rawValue)" }
    public var symbolName: String {
        switch self {
        case .art: "paintpalette"
        case .music: "music.note"
        case .history: "hourglass"
        case .politics: "building.columns"
        case .geopolitics: "globe.europe.africa"
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

    /// Main image first, then the gallery.
    public var images: [LicensedImage] { (image.map { [$0] } ?? []) + (gallery ?? []) }
}
