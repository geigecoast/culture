import Foundation
import Observation
import SwiftData
import CultureCore

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case home, agenda, vocabulary, collections, profile
    var id: String { rawValue }
    var titleKey: String { "tab.\(rawValue)" }
    var symbol: String {
        switch self {
        case .home: "house"
        case .agenda: "calendar"
        case .vocabulary: "text.book.closed"
        case .collections: "bookmark"
        case .profile: "person.crop.circle"
        }
    }
}

enum DeepLink: Equatable {
    case event(String), card(String), vocab(String), auth(URL)

    /// culture://event/<id> or https://culture.app/event/<id>
    init?(url: URL) {
        if url.host() == "auth" { self = .auth(url); return }
        var parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme == "culture", let host = url.host() { parts.insert(host, at: 0) }
        guard parts.count >= 2 else { return nil }
        switch parts[0] {
        case "event": self = .event(parts[1])
        case "card": self = .card(parts[1])
        case "vocab": self = .vocab(parts[1])
        default: return nil
        }
    }

    static func shareURL(forEvent id: String) -> URL {
        URL(string: "https://\(BuildConfiguration.universalLinkHost)/event/\(id)")!
    }
}

@Observable
@MainActor
final class AppModel {
    let settings: AppSettings
    let store: UserDataStore
    let auth: AuthService
    let notifications = NotificationService()
    let screenTime = ScreenTimeMonitor()
    private let repository = ContentRepository()
    @ObservationIgnored private let sync: SyncService

    private(set) var content: ContentBundle = .empty
    private(set) var isRefreshing = false
    var selectedSection: AppSection = .home
    var presentedEventID: String?
    var presentedCardID: String?
    var presentedVocabID: String?
    var isSearchPresented = false

    let visibility = BuildConfiguration.contentVisibility

    init(container: ModelContainer, settings: AppSettings) {
        self.settings = settings
        store = UserDataStore(context: container.mainContext)
        auth = AuthService()
        sync = SyncService(auth: auth, store: store)
    }

    // MARK: Content

    func loadContent() async {
        let local = await repository.loadLocal()
        content = local.filtered(for: visibility)
        if settings.cityIDs.isEmpty {
            settings.cityIDs = DefaultCityResolver.resolve(cities: content.cities, nearestCityID: nil,
                                                           regionCode: Locale.current.region?.identifier)
        }
        updateWidgetSnapshot()
        await refreshContent()
    }

    func refreshContent() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = await repository.refresh(currentVersion: content.version) {
            content = fresh.filtered(for: visibility)
            updateWidgetSnapshot()
        }
    }

    var feedCards: [ContentCard] {
        FeedRanker().rank(content.cards, profile: .init(interests: settings.interests,
                                                       mastery: store.masteryScores(),
                                                       seenCardIDs: store.seenCardIDs))
    }

    func card(_ id: String) -> ContentCard? { content.cards.first { $0.id == id } }
    func event(_ id: String) -> CulturalEvent? { content.events.first { $0.id == id } }
    func vocab(_ id: String) -> VocabEntry? { content.vocab.first { $0.id == id } }

    /// Same word for everyone on a given day, cycling through the deck.
    var wordOfTheDay: VocabEntry? {
        guard !content.vocab.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return content.vocab[day % content.vocab.count]
    }

    var quizCards: [ContentCard] { feedCards.filter { $0.quiz != nil } }

    // MARK: Lifecycle

    func didBecomeActive() {
        sync.startForegroundSync()
        screenTime.start(minutes: settings.screenTimeReminderMinutes, enabled: settings.screenTimeReminderEnabled)
    }

    func didEnterBackground() {
        sync.stop()
        screenTime.stop()
        updateWidgetSnapshot()
    }

    func handle(_ url: URL) {
        guard let link = DeepLink(url: url) else { return }
        switch link {
        case .event(let id): selectedSection = .agenda; presentedEventID = id
        case .card(let id): selectedSection = .home; presentedCardID = id
        case .vocab(let id): selectedSection = .vocabulary; presentedVocabID = id
        case .auth(let url): Task { await auth.handleAuthCallback(url) }
        }
    }

    // MARK: RSVP

    func setRSVP(_ state: RSVPState?, for event: CulturalEvent) {
        store.setRSVP(state, for: event.id)
        Haptics.selection()
        Task { await sync.syncOnce() }
        updateWidgetSnapshot()
    }

    // MARK: Account

    func deleteAccount() async -> Bool {
        let serverOK = await sync.deleteAccountOnServer()
        guard serverOK else { return false }
        auth.signOut()
        store.deleteAllLocalData()
        notifications.removeAll()
        await repository.clearCache()
        settings.resetForAccountDeletion()
        settings.hasCompletedOnboarding = false
        return true
    }

    func exportData() async -> Data? { await sync.exportData() }

    // MARK: Widgets

    func updateWidgetSnapshot() {
        let word = wordOfTheDay.map { WidgetSnapshot.Word(term: $0.term, definition: $0.definition, register: $0.register.rawValue) }
        let upcoming = store.attendingEventIDs.compactMap(event).filter { $0.start > .now }.min { $0.start < $1.start }
        let next = upcoming.map {
            WidgetSnapshot.NextEvent(title: $0.title, venue: content.venue($0.venueID)?.name ?? "", start: $0.start,
                                     timeZoneID: $0.timeZoneID, cancelled: $0.isCancelled)
        }
        WidgetSnapshot(word: word, streak: store.streak.length, nextEvent: next, language: settings.language.rawValue).save()
    }
}
