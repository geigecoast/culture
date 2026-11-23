import Foundation
import SwiftData
import CultureCore

// SwiftData stores user state only. Editorial content lives in the versioned JSON bundle.

@Model
final class ReviewRecord {
    @Attribute(.unique) var vocabID: String
    var easeFactor: Double
    var repetitions: Int
    var intervalDays: Int
    var due: Date
    var lapses: Int
    var lastReviewed: Date?
    var lastGradeRaw: String?

    init(vocabID: String, state: ReviewState) {
        self.vocabID = vocabID
        easeFactor = state.easeFactor
        repetitions = state.repetitions
        intervalDays = state.intervalDays
        due = state.due
        lapses = state.lapses
        lastReviewed = state.lastReviewed
    }

    var state: ReviewState {
        get { ReviewState(easeFactor: easeFactor, repetitions: repetitions, intervalDays: intervalDays, due: due, lapses: lapses, lastReviewed: lastReviewed) }
        set {
            easeFactor = newValue.easeFactor; repetitions = newValue.repetitions; intervalDays = newValue.intervalDays
            due = newValue.due; lapses = newValue.lapses; lastReviewed = newValue.lastReviewed
        }
    }
}

@Model
final class SavedItem {
    @Attribute(.unique) var key: String
    var itemID: String
    var kindRaw: String
    var savedAt: Date
    var collection: UserCollection?

    enum Kind: String { case card, vocab, event }

    init(itemID: String, kind: Kind, collection: UserCollection? = nil) {
        key = "\(kind.rawValue):\(itemID):\(collection?.id.uuidString ?? "all")"
        self.itemID = itemID
        kindRaw = kind.rawValue
        savedAt = .now
        self.collection = collection
    }
}

@Model
final class UserCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \SavedItem.collection) var items: [SavedItem] = []

    init(name: String) {
        id = UUID()
        self.name = name
        createdAt = .now
    }
}

@Model
final class LikeRecord {
    @Attribute(.unique) var cardID: String
    var likedAt: Date
    init(cardID: String) { self.cardID = cardID; likedAt = .now }
}

@Model
final class RSVPRecord {
    @Attribute(.unique) var eventID: String
    var stateRaw: String
    var updatedAt: Date
    /// False until the change has been pushed to the backend (offline outbox).
    var synced: Bool
    var reminderScheduled: Bool

    init(eventID: String, state: RSVPState) {
        self.eventID = eventID
        stateRaw = state.rawValue
        updatedAt = .now
        synced = false
        reminderScheduled = false
    }

    static let removed = "none"
    /// nil when the user removed their RSVP (tombstone).
    var state: RSVPState? { RSVPState(rawValue: stateRaw) }
}

/// One row per local day with activity, used for the streak.
@Model
final class ActivityDay {
    @Attribute(.unique) var day: Date
    var xp: Int
    var cardsCompleted: Int
    var quizzesAnswered: Int
    var reviewSessions: Int

    init(day: Date) {
        self.day = day
        xp = 0; cardsCompleted = 0; quizzesAnswered = 0; reviewSessions = 0
    }
}

@Model
final class QuizAnswerRecord {
    var topicRaw: String
    var itemID: String
    var correct: Bool
    var answeredAt: Date

    init(topic: Topic, itemID: String, correct: Bool) {
        topicRaw = topic.rawValue
        self.itemID = itemID
        self.correct = correct
        answeredAt = .now
    }
}

@Model
final class SeenCard {
    @Attribute(.unique) var cardID: String
    var seenAt: Date
    init(cardID: String) { self.cardID = cardID; seenAt = .now }
}

enum PersistenceSchema {
    static let models: [any PersistentModel.Type] = [
        ReviewRecord.self, SavedItem.self, UserCollection.self, LikeRecord.self, RSVPRecord.self,
        ActivityDay.self, QuizAnswerRecord.self, SeenCard.self
    ]
}
