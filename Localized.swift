import Foundation

/// The two content/UI languages supported at launch.
public enum AppLanguage: String, Codable, CaseIterable, Sendable, Identifiable {
    case fr, en
    public var id: String { rawValue }
    public var locale: Locale { Locale(identifier: rawValue) }

    /// Resolves the device's preferred language, falling back to French.
    public static func fromPreferred(_ preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        for identifier in preferred {
            let code = Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
            if let match = AppLanguage(rawValue: String(code.prefix(2))) { return match }
        }
        return .fr
    }
}

/// A piece of text that exists in both French and English.
public struct LocalizedText: Codable, Hashable, Sendable {
    public var fr: String
    public var en: String

    public init(fr: String, en: String) {
        self.fr = fr
        self.en = en
    }

    public subscript(_ language: AppLanguage) -> String {
        switch language {
        case .fr: fr
        case .en: en.isEmpty ? fr : en
        }
    }

    public var isComplete: Bool {
        !fr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
