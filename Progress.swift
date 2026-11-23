import Foundation

public enum XPEvent: Sendable {
    case cardCompleted, quizAnswered(correct: Bool), reviewSessionCompleted, eventAttended

    public var points: Int {
        switch self {
        case .cardCompleted: 5
        case .quizAnswered(let correct): correct ? 10 : 2
        case .reviewSessionCompleted: 15
        case .eventAttended: 30
        }
    }
}

/// Topic mastery levels: Initié → Connaisseur → Érudit.
public enum MasteryLevel: String, Codable, CaseIterable, Sendable, Comparable {
    case initie, connaisseur, erudit

    public var localizationKey: String { "mastery.\(rawValue)" }

    /// Mastery is derived from quiz accuracy on a topic, weighted by volume so that
    /// a single lucky answer cannot jump a level.
    public static func level(correct: Int, answered: Int) -> MasteryLevel {
        let score = MasteryScore(correct: correct, answered: answered).value
        switch score {
        case ..<0.45: return .initie
        case ..<0.75: return .connaisseur
        default: return .erudit
        }
    }

    public static func < (lhs: MasteryLevel, rhs: MasteryLevel) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

/// A 0–1 mastery score: accuracy shrunk towards zero until enough answers exist.
public struct MasteryScore: Sendable, Equatable {
    public static let confidenceAnswers = 20.0
    public let value: Double

    public init(correct: Int, answered: Int) {
        guard answered > 0 else { value = 0; return }
        let accuracy = Double(correct) / Double(answered)
        let confidence = min(1, Double(answered) / Self.confidenceAnswers)
        value = accuracy * confidence
    }
}
