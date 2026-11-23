import Foundation

/// Mirrors admin/validate.mjs so the app can refuse to display invalid published content.
public struct ContentValidator: Sendable {
    public struct Issue: Hashable, Sendable, CustomStringConvertible {
        public var itemID: String
        public var message: String
        public var description: String { "\(itemID): \(message)" }
    }

    public init() {}

    public func validate(_ bundle: ContentBundle) -> [Issue] {
        var issues: [Issue] = []
        for card in bundle.cards {
            issues += validateEditorial(card.editorial, id: card.id)
            if !card.title.isComplete || !card.body.isComplete || !card.takeaway.isComplete {
                issues.append(Issue(itemID: card.id, message: "missing FR or EN text"))
            }
            if card.topic == .books && card.book == nil {
                issues.append(Issue(itemID: card.id, message: "book card without author and year"))
            }
            if card.topic == .geopolitics && card.factsAsOf == nil {
                issues.append(Issue(itemID: card.id, message: "geopolitics card without factsAsOf date"))
            }
            if let quiz = card.quiz, !quiz.options.indices.contains(quiz.answerIndex) {
                issues.append(Issue(itemID: card.id, message: "quiz answerIndex out of range"))
            }
            for image in card.images where image.license.isEmpty || image.credit.isEmpty {
                issues.append(Issue(itemID: card.id, message: "image without licence or credit"))
            }
        }
        for entry in bundle.vocab {
            issues += validateEditorial(entry.editorial, id: entry.id)
            if entry.editorial.status == .published && (entry.nativeReviewer ?? "").isEmpty {
                issues.append(Issue(itemID: entry.id, message: "published vocabulary needs a native-speaker reviewer"))
            }
        }
        let venueIDs = Set(bundle.venues.map(\.id))
        let cityIDs = Set(bundle.cities.map(\.id))
        for event in bundle.events {
            if !venueIDs.contains(event.venueID) { issues.append(Issue(itemID: event.id, message: "unknown venue")) }
            if !cityIDs.contains(event.cityID) { issues.append(Issue(itemID: event.id, message: "unknown city")) }
            if TimeZone(identifier: event.timeZoneID) == nil { issues.append(Issue(itemID: event.id, message: "invalid time zone")) }
            if let image = event.image, image.license.isEmpty || image.credit.isEmpty {
                issues.append(Issue(itemID: event.id, message: "image without licence or credit"))
            }
            if let end = event.end, end < event.start { issues.append(Issue(itemID: event.id, message: "ends before it starts")) }
        }
        return issues
    }

    private func validateEditorial(_ info: EditorialInfo, id: String) -> [Issue] {
        guard info.status == .published else { return [] }
        var issues: [Issue] = []
        if info.sources.isEmpty { issues.append(Issue(itemID: id, message: "published without a source")) }
        if (info.lastReviewed ?? "").isEmpty { issues.append(Issue(itemID: id, message: "published without a last-reviewed date")) }
        if (info.reviewer ?? "").isEmpty { issues.append(Issue(itemID: id, message: "published without a reviewer")) }
        return issues
    }
}
