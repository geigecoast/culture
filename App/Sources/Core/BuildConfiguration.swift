import Foundation
import CultureCore

enum BuildConfiguration {
    /// Debug and internal TestFlight builds set `CultureShowUnreviewedContent = YES` in Info.plist
    /// (see project.yml) so editors can check seed content before it is published.
    /// App Store builds only ever show published content.
    static var contentVisibility: ContentVisibility {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CultureShowUnreviewedContent")
        let flag = (raw as? Bool) ?? ["YES", "true", "1"].contains(raw as? String ?? "")
        return flag ? .includeInReview : .publishedOnly
    }

    static var contentBaseURL: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "CultureContentBaseURL") as? String)
            .flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    static var backendURL: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "CultureBackendURL") as? String)
            .flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    static var backendAnonKey: String? {
        (Bundle.main.object(forInfoDictionaryKey: "CultureBackendAnonKey") as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    static let universalLinkHost = "culture.app"
}
