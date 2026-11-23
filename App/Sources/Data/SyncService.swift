import Foundation
import CultureCore

/// Pushes local RSVP changes (offline outbox) and pulls changes made on the user's
/// other devices. Uses Supabase PostgREST over HTTPS.
///
/// MVP behaviour: pull every few seconds while the app is in the foreground and the user
/// is signed in, which meets the "visible on the other device within 5 seconds" target.
/// Swapping the poll for Supabase Realtime is listed in the README as a follow-up.
@MainActor
final class SyncService {
    private let auth: AuthService
    private let store: UserDataStore
    private let api: APIClient?
    private var pollTask: Task<Void, Never>?
    private var lastPull: Date = .distantPast

    static let pollInterval: Duration = .seconds(3)

    init(auth: AuthService, store: UserDataStore,
         baseURL: URL? = BuildConfiguration.backendURL, anonKey: String? = BuildConfiguration.backendAnonKey) {
        self.auth = auth
        self.store = store
        if let baseURL, let anonKey {
            api = APIClient(baseURL: baseURL, defaultHeaders: ["apikey": anonKey])
        } else {
            api = nil
        }
    }

    func startForegroundSync() {
        guard api != nil, pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.syncOnce()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private struct RemoteRSVP: Codable, Sendable {
        let event_id: String
        let state: String?
        let updated_at: Date
    }

    nonisolated private static func rowDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let raw = try d.singleValueContainer().decode(String.self)
            return ContentDecoder.parseISO8601(raw) ?? .distantPast
        }
        return decoder
    }

    func syncOnce() async {
        guard let api, let token = await auth.validAccessToken(), let userID = auth.session?.userID else { return }
        let headers = ["Authorization": "Bearer \(token)"]
        let encoder = JSONEncoder.content

        // Push the outbox. A nil state is stored as a soft delete so other devices see it.
        for record in store.unsyncedRSVPs() {
            let row: [String: String?] = ["user_id": userID, "event_id": record.eventID, "state": record.state?.rawValue,
                                          "updated_at": ISO8601DateFormatter().string(from: record.updatedAt)]
            let endpoint = Endpoint<AuthService.EmptyResponse>(
                path: "rest/v1/rsvps", method: "POST", body: try? encoder.encode(row),
                headers: headers.merging(["Prefer": "resolution=merge-duplicates"]) { $1 },
                decode: { _ in .init() })
            if (try? await api.send(endpoint)) != nil { store.markSynced(record.eventID) }
        }

        // Pull rows changed since the last pull.
        let since = ISO8601DateFormatter().string(from: lastPull)
        let pull = Endpoint<[RemoteRSVP]>(
            path: "rest/v1/rsvps",
            query: [URLQueryItem(name: "select", value: "event_id,state,updated_at"),
                    // RLS also returns friends' shared RSVPs; only pull our own here.
                    URLQueryItem(name: "user_id", value: "eq.\(userID)"),
                    URLQueryItem(name: "updated_at", value: "gt.\(since)")],
            headers: headers, decode: { try Self.rowDecoder().decode([RemoteRSVP].self, from: $0) })
        if let rows = try? await api.send(pull) {
            for row in rows {
                store.applyRemoteRSVP(eventID: row.event_id, state: row.state.flatMap(RSVPState.init(rawValue:)), updatedAt: row.updated_at)
                lastPull = max(lastPull, row.updated_at)
            }
        }
    }

    /// Calls the `delete_my_account` RPC, which removes progress, attendance, plans and reviews.
    func deleteAccountOnServer() async -> Bool {
        guard let api, let token = await auth.validAccessToken() else { return api == nil }
        let endpoint = Endpoint<AuthService.EmptyResponse>(path: "rest/v1/rpc/delete_my_account", method: "POST",
                                                           body: Data("{}".utf8), headers: ["Authorization": "Bearer \(token)"],
                                                           decode: { _ in .init() })
        return (try? await api.send(endpoint)) != nil
    }

    /// GDPR data export: returns the JSON produced by the `export_my_data` RPC.
    func exportData() async -> Data? {
        guard let api, let token = await auth.validAccessToken() else { return nil }
        let endpoint = Endpoint<Data>(path: "rest/v1/rpc/export_my_data", method: "POST", body: Data("{}".utf8),
                                      headers: ["Authorization": "Bearer \(token)"], decode: { $0 })
        return try? await api.send(endpoint)
    }
}
