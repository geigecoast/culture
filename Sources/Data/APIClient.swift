import Foundation

/// Typed endpoint description.
struct Endpoint<Response: Decodable & Sendable>: Sendable {
    var path: String
    var method: String = "GET"
    var query: [URLQueryItem] = []
    var body: Data?
    var headers: [String: String] = [:]
    var decode: @Sendable (Data) throws -> Response
}

enum APIError: Error, Equatable {
    case notConfigured
    case http(status: Int)
    case notModified
    case transport(String)
}

/// Thin URLSession wrapper. All network access goes through here.
actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let defaultHeaders: [String: String]

    init(baseURL: URL, defaultHeaders: [String: String] = [:], session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.defaultHeaders = defaultHeaders
    }

    func send<R>(_ endpoint: Endpoint<R>) async throws -> R {
        var components = URLComponents(url: baseURL.appending(path: endpoint.path), resolvingAgainstBaseURL: false)!
        if !endpoint.query.isEmpty { components.queryItems = endpoint.query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = endpoint.method
        request.httpBody = endpoint.body
        request.timeoutInterval = 20
        for (k, v) in defaultHeaders.merging(endpoint.headers, uniquingKeysWith: { $1 }) {
            request.setValue(v, forHTTPHeaderField: k)
        }
        if endpoint.body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 304 { throw APIError.notModified }
        guard (200..<300).contains(status) else { throw APIError.http(status: status) }
        return try endpoint.decode(data)
    }
}
