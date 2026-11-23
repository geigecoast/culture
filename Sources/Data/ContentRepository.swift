import Foundation
import CultureCore

/// Loads the versioned content bundle: cached copy first (offline), then bundled seed,
/// then refreshes from the backend when a content URL is configured.
actor ContentRepository {
    private let fileManager = FileManager.default
    private let api: APIClient?

    init(baseURL: URL? = BuildConfiguration.contentBaseURL) {
        api = baseURL.map { APIClient(baseURL: $0) }
    }

    private var cacheURL: URL {
        let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Content", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "content-bundle.json")
    }

    /// Returns the newest bundle available locally (cache or seed).
    func loadLocal() -> ContentBundle {
        let cached = (try? Data(contentsOf: cacheURL)).flatMap { try? ContentDecoder.bundle(from: $0) }
        let seed = Bundle.main.url(forResource: "content-bundle", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? ContentDecoder.bundle(from: $0) }
        switch (cached, seed) {
        case let (c?, s?): return c.version >= s.version ? c : s
        case let (c?, nil): return c
        case let (nil, s?): return s
        default: return .empty
        }
    }

    /// Fetches a newer bundle if the server has one. Returns nil when offline or up to date.
    func refresh(currentVersion: Int) async -> ContentBundle? {
        guard let api else { return nil }
        let endpoint = Endpoint<ContentBundle>(
            path: "content/bundle.json",
            query: [URLQueryItem(name: "since", value: String(currentVersion))],
            decode: { try ContentDecoder.bundle(from: $0) }
        )
        do {
            let bundle = try await api.send(endpoint)
            guard bundle.version > currentVersion else { return nil }
            let issues = ContentValidator().validate(bundle)
            guard issues.isEmpty else {
                // Refuse a bundle that would show unsourced or unreviewed content as published.
                print("Content bundle v\(bundle.version) rejected: \(issues.prefix(5))")
                return nil
            }
            let data = try JSONEncoder.content.encode(bundle)
            try data.write(to: cacheURL, options: .atomic)
            return bundle
        } catch {
            return nil
        }
    }

    func clearCache() {
        try? fileManager.removeItem(at: cacheURL)
    }
}

extension JSONEncoder {
    static var content: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
