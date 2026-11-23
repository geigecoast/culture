import Foundation

/// Editorial workflow state, shared by cards, vocabulary entries and events.
public enum EditorialStatus: String, Codable, Sendable {
    case draft
    case inReview = "in_review"
    case published
}

public struct SourceReference: Codable, Hashable, Sendable {
    public var title: String
    public var publisher: String?
    public var url: URL?

    public init(title: String, publisher: String? = nil, url: URL? = nil) {
        self.title = title
        self.publisher = publisher
        self.url = url
    }
}

/// Licensed or public-domain image. Every image must carry licence information.
public struct LicensedImage: Codable, Hashable, Sendable {
    public var url: URL
    public var license: String
    public var credit: String
    public var sourcePage: URL?
    public var altText: LocalizedText

    public init(url: URL, license: String, credit: String, sourcePage: URL? = nil, altText: LocalizedText) {
        self.url = url
        self.license = license
        self.credit = credit
        self.sourcePage = sourcePage
        self.altText = altText
    }
}

/// Shared editorial metadata.
public struct EditorialInfo: Codable, Hashable, Sendable {
    public var status: EditorialStatus
    public var sources: [SourceReference]
    /// ISO date (yyyy-MM-dd) of the last human review, nil until reviewed.
    public var lastReviewed: String?
    public var reviewer: String?

    public init(status: EditorialStatus, sources: [SourceReference], lastReviewed: String? = nil, reviewer: String? = nil) {
        self.status = status
        self.sources = sources
        self.lastReviewed = lastReviewed
        self.reviewer = reviewer
    }
}

/// Which editorial states a build is allowed to display.
public enum ContentVisibility: Sendable {
    /// App Store builds: only published content.
    case publishedOnly
    /// Debug / internal TestFlight builds: also show content that is in review, with a banner.
    case includeInReview

    public func allows(_ status: EditorialStatus) -> Bool {
        switch (self, status) {
        case (_, .published): true
        case (.includeInReview, .inReview): true
        default: false
        }
    }
}
