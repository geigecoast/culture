import Foundation
import CultureCore

/// Looks strings up in the language-specific bundle compiled from Localizable.xcstrings,
/// so the UI language can change in-app without restarting.
enum L10n {
    private static var bundles: [AppLanguage: Bundle] = [:]
    private static let lock = NSLock()

    static func bundle(for language: AppLanguage) -> Bundle {
        lock.lock(); defer { lock.unlock() }
        if let cached = bundles[language] { return cached }
        let bundle = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        bundles[language] = bundle
        return bundle
    }

    static func string(_ key: String, language: AppLanguage, args: [CVarArg] = []) -> String {
        let format = bundle(for: language).localizedString(forKey: key, value: key, table: nil)
        return args.isEmpty ? format : String(format: format, locale: language.locale, arguments: args)
    }
}
