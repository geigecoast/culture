import Foundation

/// The three self-assessments offered on a vocabulary card.
public enum ReviewGrade: String, Codable, CaseIterable, Sendable {
    /// "Je connais"
    case known
    /// "À revoir"
    case review
    /// "Difficile"
    case hard

    /// SM-2 quality score (0–5).
    public var quality: Int {
        switch self {
        case .known: 5
        case .review: 3
        case .hard: 1
        }
    }

    public var localizationKey: String { "grade.\(rawValue)" }
}

/// Persistent scheduling state for one card.
public struct ReviewState: Codable, Hashable, Sendable {
    public var easeFactor: Double
    public var repetitions: Int
    public var intervalDays: Int
    public var due: Date
    public var lapses: Int
    public var lastReviewed: Date?

    public static func new(now: Date) -> ReviewState {
        ReviewState(easeFactor: 2.5, repetitions: 0, intervalDays: 0, due: now, lapses: 0, lastReviewed: nil)
    }

    public init(easeFactor: Double, repetitions: Int, intervalDays: Int, due: Date, lapses: Int, lastReviewed: Date?) {
        self.easeFactor = easeFactor
        self.repetitions = repetitions
        self.intervalDays = intervalDays
        self.due = due
        self.lapses = lapses
        self.lastReviewed = lastReviewed
    }

    public func isDue(at date: Date) -> Bool { due <= date }
}

/// SM-2 scheduler with one documented change: "à revoir" (quality 3) grows the
/// interval by a fixed 1.2× instead of the ease factor, so words the user is unsure
/// about come back sooner than words they know. "Difficile" resets the card to tomorrow.
public struct SM2Scheduler: Sendable {
    public static let minimumEase = 1.3
    public static let reviewMultiplier = 1.2
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func schedule(_ state: ReviewState, grade: ReviewGrade, now: Date) -> ReviewState {
        let q = Double(grade.quality)
        var next = state
        next.lastReviewed = now
        next.easeFactor = max(Self.minimumEase, state.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))

        switch grade {
        case .hard:
            next.repetitions = 0
            next.intervalDays = 1
            if state.repetitions > 0 { next.lapses += 1 }
        case .review:
            next.repetitions = state.repetitions + 1
            next.intervalDays = max(1, Int((Double(max(state.intervalDays, 1)) * Self.reviewMultiplier).rounded()))
            // Never longer than what "je connais" would have given.
            next.intervalDays = min(next.intervalDays, knownInterval(for: state))
        case .known:
            next.repetitions = state.repetitions + 1
            next.intervalDays = knownInterval(for: state)
        }

        let today = calendar.startOfDay(for: now)
        next.due = calendar.date(byAdding: .day, value: next.intervalDays, to: today) ?? now
        return next
    }

    private func knownInterval(for state: ReviewState) -> Int {
        switch state.repetitions {
        case 0: 1
        case 1: 6
        default: max(1, Int((Double(state.intervalDays) * state.easeFactor).rounded()))
        }
    }

    /// Orders due items: overdue first, then the ones with the lowest ease (hardest).
    public func dueQueue<ID: Hashable>(_ states: [ID: ReviewState], now: Date, limit: Int = 20) -> [ID] {
        states
            .filter { $0.value.isDue(at: now) }
            .sorted { lhs, rhs in
                if lhs.value.due != rhs.value.due { return lhs.value.due < rhs.value.due }
                return lhs.value.easeFactor < rhs.value.easeFactor
            }
            .prefix(limit)
            .map(\.key)
    }
}
