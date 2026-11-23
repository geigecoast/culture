import Foundation

/// Builds the "Pour toi" feed: mixes topics according to interests, gives more room
/// to topics the user is weaker in, and never shows the same topic more than twice in a row.
public struct FeedRanker: Sendable {
    public struct Profile: Sendable {
        public var interests: Set<Topic>
        /// 0–1 mastery per topic (see `MasteryScore`).
        public var mastery: [Topic: Double]
        public var seenCardIDs: Set<String>

        public init(interests: Set<Topic>, mastery: [Topic: Double] = [:], seenCardIDs: Set<String> = []) {
            self.interests = interests
            self.mastery = mastery
            self.seenCardIDs = seenCardIDs
        }
    }

    public init() {}

    /// Weight of a topic: interests count double; weak topics get up to +100 %.
    public func weight(for topic: Topic, profile: Profile) -> Double {
        let interest = profile.interests.isEmpty || profile.interests.contains(topic) ? 2.0 : 0.5
        let weakness = 1.0 + (1.0 - (profile.mastery[topic] ?? 0))
        return interest * weakness
    }

    public func rank(_ cards: [ContentCard], profile: Profile) -> [ContentCard] {
        // Unseen cards first within each topic, keeping editorial order otherwise.
        var queues: [Topic: [ContentCard]] = Dictionary(grouping: cards, by: \.topic).mapValues { list in
            list.filter { !profile.seenCardIDs.contains($0.id) } + list.filter { profile.seenCardIDs.contains($0.id) }
        }
        var credit: [Topic: Double] = [:]
        var result: [ContentCard] = []
        var lastTopics: [Topic] = []

        // Deterministic weighted round-robin ("smooth weighted round robin").
        while queues.values.contains(where: { !$0.isEmpty }) {
            let available = queues.filter { !$0.value.isEmpty }.map(\.key).sorted { $0.rawValue < $1.rawValue }
            let total = available.reduce(0) { $0 + weight(for: $1, profile: profile) }
            for topic in available { credit[topic, default: 0] += weight(for: topic, profile: profile) }

            let blocked = lastTopics.count >= 2 && lastTopics.suffix(2).allSatisfy { $0 == lastTopics.last } ? lastTopics.last : nil
            let candidates = available.count > 1 ? available.filter { $0 != blocked } : available
            guard let pick = candidates.max(by: { credit[$0, default: 0] < credit[$1, default: 0] }) else { break }

            credit[pick, default: 0] -= total
            result.append(queues[pick]!.removeFirst())
            lastTopics.append(pick)
        }
        return result
    }
}
