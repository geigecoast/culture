import Foundation

public enum Register: String, Codable, CaseIterable, Sendable {
    case courant, soutenu, litteraire, vieilli, familier
    public var localizationKey: String { "register.\(rawValue)" }
    /// Familier entries are shown as "to avoid" in elevated contexts.
    public var isWarning: Bool { self == .familier }
}

public struct Nuance: Codable, Hashable, Sendable {
    public var word: String
    public var note: LocalizedText
}

public struct ProductionExercise: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// Complete a sentence with the target word.
        case complete
        /// Rewrite a casual sentence in a soutenu register.
        case rewrite
    }
    public var kind: Kind
    public var prompt: String
    /// Accepted answers (normalized comparison for `complete`, model answer for `rewrite`).
    public var answers: [String]
}

public struct VocabEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var term: String
    public var partOfSpeech: String
    public var register: Register
    public var definition: String
    public var gloss: String
    public var example: String
    public var nuances: [Nuance]
    public var pitfalls: [String]
    public var etymology: String?
    public var sets: [String]
    public var exercise: ProductionExercise?
    public var editorial: EditorialInfo
    public var nativeReviewer: String?
}

public struct VocabSet: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: LocalizedText
}
