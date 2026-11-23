import Foundation
import AuthenticationServices
import CryptoKit
import Observation

struct AuthSession: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var userID: String
    var email: String?
    var expiresAt: Date
}

/// Accounts are optional: anonymous use is allowed on the free tier.
/// Sign in with Apple is always offered (App Store Review Guideline 4.8),
/// plus email magic link. Talks to Supabase Auth (GoTrue) over plain HTTPS.
@Observable
@MainActor
final class AuthService {
    private(set) var session: AuthSession?
    private(set) var lastError: String?
    private var currentNonce: String?
    private let api: APIClient?
    private static let keychainKey = "culture.auth.session"

    var isSignedIn: Bool { session != nil }

    init(baseURL: URL? = BuildConfiguration.backendURL, anonKey: String? = BuildConfiguration.backendAnonKey) {
        if let baseURL, let anonKey {
            api = APIClient(baseURL: baseURL, defaultHeaders: ["apikey": anonKey])
        } else {
            api = nil
        }
        session = Keychain.get(Self.keychainKey).flatMap { try? JSONDecoder().decode(AuthSession.self, from: $0) }
    }

    // MARK: Sign in with Apple

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func handle(_ result: Result<ASAuthorization, Error>) async {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken, let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            if case .failure(let error) = result { lastError = error.localizedDescription }
            return
        }
        await exchange(body: ["provider": "apple", "id_token": idToken, "nonce": nonce], grantType: "id_token")
    }

    // MARK: Email magic link

    func sendMagicLink(to email: String) async -> Bool {
        guard let api else { lastError = "backend-not-configured"; return false }
        let body = try? JSONSerialization.data(withJSONObject: ["email": email, "create_user": true])
        do {
            _ = try await api.send(Endpoint<EmptyResponse>(path: "auth/v1/otp", method: "POST", body: body, decode: { _ in EmptyResponse() }))
            return true
        } catch {
            lastError = "\(error)"
            return false
        }
    }

    /// Called from the deep link in the magic-link email (culture://auth#access_token=...).
    func handleAuthCallback(_ url: URL) async {
        guard let fragment = url.fragment else { return }
        let items = Dictionary(uniqueKeysWithValues: fragment.split(separator: "&").compactMap { pair -> (String, String)? in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            return parts.count == 2 ? (parts[0], parts[1].removingPercentEncoding ?? parts[1]) : nil
        })
        guard let refresh = items["refresh_token"] else { return }
        await exchange(body: ["refresh_token": refresh], grantType: "refresh_token")
    }

    func validAccessToken() async -> String? {
        guard let session else { return nil }
        if session.expiresAt > .now.addingTimeInterval(60) { return session.accessToken }
        await exchange(body: ["refresh_token": session.refreshToken], grantType: "refresh_token")
        return self.session?.accessToken
    }

    func signOut() {
        session = nil
        Keychain.set(nil, for: Self.keychainKey)
    }

    // MARK: Private

    private struct TokenResponse: Decodable, Sendable {
        struct User: Decodable, Sendable { let id: String; let email: String? }
        let access_token: String
        let refresh_token: String
        let expires_in: Double
        let user: User
    }

    struct EmptyResponse: Decodable, Sendable {}

    private func exchange(body: [String: String], grantType: String) async {
        guard let api else { lastError = "backend-not-configured"; return }
        let data = try? JSONSerialization.data(withJSONObject: body)
        let endpoint = Endpoint<TokenResponse>(path: "auth/v1/token", method: "POST",
                                               query: [URLQueryItem(name: "grant_type", value: grantType)], body: data,
                                               decode: { try JSONDecoder().decode(TokenResponse.self, from: $0) })
        do {
            let token = try await api.send(endpoint)
            let newSession = AuthSession(accessToken: token.access_token, refreshToken: token.refresh_token,
                                         userID: token.user.id, email: token.user.email,
                                         expiresAt: .now.addingTimeInterval(token.expires_in))
            session = newSession
            Keychain.set(try? JSONEncoder().encode(newSession), for: Self.keychainKey)
            lastError = nil
        } catch {
            lastError = "\(error)"
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }
}
