import Foundation
import SwiftData
import CultureCore

/// Main-actor facade over SwiftData for user progress, saves, likes and RSVPs.
@Observable
@MainActor
final class UserDataStore {
    let context: ModelContext
    private let scheduler = SM2Scheduler()
    private let streakCalculator = StreakCalculator()
    /// Bumped on every write so observing views refresh derived values.
    private(set) var revision = 0

    init(context: ModelContext) {
        self.context = context
    }

    private func save() {
        try? context.save()
        revision += 1
    }

    // MARK: Activity, XP, streak

    func record(_ event: XPEvent) {
        let day = Calendar.current.startOfDay(for: .now)
        let activity = fetchOne(FetchDescriptor<ActivityDay>(predicate: #Predicate { $0.day == day })) ?? {
            let new = ActivityDay(day: day)
            context.insert(new)
            return new
        }()
        activity.xp += event.points
        switch event {
        case .cardCompleted: activity.cardsCompleted += 1
        case .quizAnswered: activity.quizzesAnswered += 1
        case .reviewSessionCompleted: activity.reviewSessions += 1
        case .eventAttended: break
        }
        save()
    }

    var totalXP: Int {
        _ = revision
        return ((try? context.fetch(FetchDescriptor<ActivityDay>())) ?? []).reduce(0) { $0 + $1.xp }
    }

    var streak: StreakCalculator.Result {
        _ = revision
        let days = (try? context.fetch(FetchDescriptor<ActivityDay>())) ?? []
        return streakCalculator.compute(activeDays: Set(days.map(\.day)), today: .now)
    }

    var level: Int { 1 + Int((Double(totalXP) / 100).squareRoot()) }

    // MARK: Quizzes & mastery

    func recordQuiz(topic: Topic, itemID: String, correct: Bool) {
        context.insert(QuizAnswerRecord(topic: topic, itemID: itemID, correct: correct))
        record(.quizAnswered(correct: correct))
    }

    func masteryScores() -> [Topic: Double] {
        _ = revision
        let answers = (try? context.fetch(FetchDescriptor<QuizAnswerRecord>())) ?? []
        return Dictionary(grouping: answers, by: \.topicRaw).reduce(into: [:]) { result, pair in
            guard let topic = Topic(rawValue: pair.key) else { return }
            result[topic] = MasteryScore(correct: pair.value.filter(\.correct).count, answered: pair.value.count).value
        }
    }

    func masteryLevel(for topic: Topic) -> MasteryLevel {
        _ = revision
        let raw = topic.rawValue
        let answers = (try? context.fetch(FetchDescriptor<QuizAnswerRecord>(predicate: #Predicate { $0.topicRaw == raw }))) ?? []
        return MasteryLevel.level(correct: answers.filter(\.correct).count, answered: answers.count)
    }

    func markSeen(_ cardID: String) {
        guard fetchOne(FetchDescriptor<SeenCard>(predicate: #Predicate { $0.cardID == cardID })) == nil else { return }
        context.insert(SeenCard(cardID: cardID))
        record(.cardCompleted)
    }

    var seenCardIDs: Set<String> {
        _ = revision
        return Set(((try? context.fetch(FetchDescriptor<SeenCard>())) ?? []).map(\.cardID))
    }

    // MARK: Vocabulary SRS

    func reviewState(for vocabID: String) -> ReviewState? {
        _ = revision
        return fetchOne(FetchDescriptor<ReviewRecord>(predicate: #Predicate { $0.vocabID == vocabID }))?.state
    }

    @discardableResult
    func grade(_ vocabID: String, _ grade: ReviewGrade, now: Date = .now) -> ReviewState {
        let record = fetchOne(FetchDescriptor<ReviewRecord>(predicate: #Predicate { $0.vocabID == vocabID })) ?? {
            let new = ReviewRecord(vocabID: vocabID, state: .new(now: now))
            context.insert(new)
            return new
        }()
        record.state = scheduler.schedule(record.state, grade: grade, now: now)
        record.lastGradeRaw = grade.rawValue
        save()
        return record.state
    }

    /// Due words first, then new words, capped to the session size.
    func reviewQueue(from vocab: [VocabEntry], newPerSession: Int = 10, limit: Int = 20, now: Date = .now) -> [VocabEntry] {
        _ = revision
        let records = (try? context.fetch(FetchDescriptor<ReviewRecord>())) ?? []
        let states = Dictionary(uniqueKeysWithValues: records.map { ($0.vocabID, $0.state) })
        let dueIDs = scheduler.dueQueue(states, now: now, limit: limit)
        let byID = Dictionary(uniqueKeysWithValues: vocab.map { ($0.id, $0) })
        let due = dueIDs.compactMap { byID[$0] }
        let fresh = vocab.filter { states[$0.id] == nil }.prefix(max(0, min(newPerSession, limit - due.count)))
        return due + fresh
    }

    var learnedWordCount: Int {
        _ = revision
        return ((try? context.fetch(FetchDescriptor<ReviewRecord>())) ?? []).filter { $0.repetitions >= 2 }.count
    }

    // MARK: Likes & saves

    func isLiked(_ cardID: String) -> Bool {
        _ = revision
        return fetchOne(FetchDescriptor<LikeRecord>(predicate: #Predicate { $0.cardID == cardID })) != nil
    }

    func toggleLike(_ cardID: String) {
        if let existing = fetchOne(FetchDescriptor<LikeRecord>(predicate: #Predicate { $0.cardID == cardID })) {
            context.delete(existing)
        } else {
            context.insert(LikeRecord(cardID: cardID))
        }
        save()
    }

    func isSaved(_ itemID: String, kind: SavedItem.Kind) -> Bool {
        _ = revision
        let raw = kind.rawValue
        return fetchOne(FetchDescriptor<SavedItem>(predicate: #Predicate { $0.itemID == itemID && $0.kindRaw == raw })) != nil
    }

    func toggleSave(_ itemID: String, kind: SavedItem.Kind, in collection: UserCollection? = nil) {
        let raw = kind.rawValue
        let existing = (try? context.fetch(FetchDescriptor<SavedItem>(predicate: #Predicate { $0.itemID == itemID && $0.kindRaw == raw }))) ?? []
        if collection == nil, !existing.isEmpty {
            for item in existing { context.delete(item) }
        } else {
            context.insert(SavedItem(itemID: itemID, kind: kind, collection: collection))
        }
        save()
    }

    func savedItems(kind: SavedItem.Kind) -> [SavedItem] {
        _ = revision
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<SavedItem>(predicate: #Predicate { $0.kindRaw == raw }, sortBy: [SortDescriptor(\.savedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func collections() -> [UserCollection] {
        _ = revision
        return (try? context.fetch(FetchDescriptor<UserCollection>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    func createCollection(named name: String) {
        context.insert(UserCollection(name: name))
        save()
    }

    func delete(_ collection: UserCollection) {
        context.delete(collection)
        save()
    }

    // MARK: RSVP

    func rsvp(for eventID: String) -> RSVPState? {
        _ = revision
        return fetchOne(FetchDescriptor<RSVPRecord>(predicate: #Predicate { $0.eventID == eventID }))?.state
    }

    func setRSVP(_ state: RSVPState?, for eventID: String) {
        let existing = fetchOne(FetchDescriptor<RSVPRecord>(predicate: #Predicate { $0.eventID == eventID }))
        switch (existing, state) {
        case let (record?, state?):
            record.stateRaw = state.rawValue
            record.updatedAt = .now
            record.synced = false
        case let (record?, nil):
            // Kept as a tombstone until synced, so other devices learn about the removal.
            record.stateRaw = RSVPRecord.removed
            record.updatedAt = .now
            record.synced = false
        case let (nil, state?):
            context.insert(RSVPRecord(eventID: eventID, state: state))
        case (nil, nil):
            break
        }
        save()
    }

    func applyRemoteRSVP(eventID: String, state: RSVPState?, updatedAt: Date) {
        let existing = fetchOne(FetchDescriptor<RSVPRecord>(predicate: #Predicate { $0.eventID == eventID }))
        // Last writer wins; never overwrite a newer local change that has not synced yet.
        if let existing, existing.updatedAt > updatedAt { return }
        if let state {
            let record = existing ?? { let r = RSVPRecord(eventID: eventID, state: state); context.insert(r); return r }()
            record.stateRaw = state.rawValue
            record.updatedAt = updatedAt
            record.synced = true
        } else if let existing {
            existing.stateRaw = RSVPRecord.removed
            existing.updatedAt = updatedAt
            existing.synced = true
        }
        save()
    }

    func unsyncedRSVPs() -> [RSVPRecord] {
        (try? context.fetch(FetchDescriptor<RSVPRecord>(predicate: #Predicate { !$0.synced }))) ?? []
    }

    func markSynced(_ eventID: String) {
        fetchOne(FetchDescriptor<RSVPRecord>(predicate: #Predicate { $0.eventID == eventID }))?.synced = true
        save()
    }

    var attendingEventIDs: [String] {
        _ = revision
        let going = RSVPState.going.rawValue
        return ((try? context.fetch(FetchDescriptor<RSVPRecord>(predicate: #Predicate { $0.stateRaw == going }))) ?? []).map(\.eventID)
    }

    // MARK: Account deletion

    func deleteAllLocalData() {
        try? context.delete(model: SavedItem.self)
        try? context.delete(model: UserCollection.self)
        try? context.delete(model: ReviewRecord.self)
        try? context.delete(model: LikeRecord.self)
        try? context.delete(model: RSVPRecord.self)
        try? context.delete(model: ActivityDay.self)
        try? context.delete(model: QuizAnswerRecord.self)
        try? context.delete(model: SeenCard.self)
        save()
    }

    private func fetchOne<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> T? {
        var d = descriptor
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }
}
