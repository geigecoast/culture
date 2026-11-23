import SwiftUI
import CultureCore

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if !settings.hasCompletedOnboarding {
                OnboardingView()
            } else if sizeClass == .regular {
                SplitRootView()
            } else {
                TabRootView()
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: Binding(get: { model.presentedEventID.map(IdentifiedString.init) },
                             set: { model.presentedEventID = $0?.id })) { item in
            NavigationStack {
                if let event = model.event(item.id) { EventDetailView(event: event) }
                else { ContentUnavailableView(settings.t("agenda.eventNotFound"), systemImage: "calendar.badge.exclamationmark") }
            }
        }
        .sheet(item: Binding(get: { model.presentedCardID.map(IdentifiedString.init) },
                             set: { model.presentedCardID = $0?.id })) { item in
            NavigationStack {
                if let card = model.card(item.id) { CardDetailView(card: card) }
            }
        }
        .sheet(isPresented: Binding(get: { model.isSearchPresented }, set: { model.isSearchPresented = $0 })) {
            SearchView()
        }
        .alert(settings.t("screenTime.title"), isPresented: Binding(get: { model.screenTime.shouldShowReminder },
                                                                    set: { model.screenTime.shouldShowReminder = $0 })) {
            Button(settings.t("screenTime.continue"), role: .cancel) {
                model.screenTime.start(minutes: settings.screenTimeReminderMinutes, enabled: settings.screenTimeReminderEnabled)
            }
            Button(settings.t("screenTime.disable")) { settings.screenTimeReminderEnabled = false }
        } message: {
            Text(settings.t("screenTime.message", settings.screenTimeReminderMinutes))
        }
    }
}

struct IdentifiedString: Identifiable { let id: String }

/// iPhone (and compact iPad windows): five tabs. Quiz lives inside Home.
struct TabRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedSection) {
            ForEach(AppSection.allCases) { section in
                NavigationStack { section.rootView }
                    .tabItem { Label(settings.t(section.titleKey), systemImage: section.symbol) }
                    .tag(section)
                    .accessibilityIdentifier("tab.\(section.rawValue)")
            }
        }
    }
}

/// iPad regular width: sidebar with sections, topics and vocabulary sets.
struct SplitRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var topicFilter: Topic?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: Binding<AppSection?>(get: { model.selectedSection }, set: { if let s = $0 { model.selectedSection = s } })) {
                Section {
                    ForEach(AppSection.allCases) { section in
                        Label(settings.t(section.titleKey), systemImage: section.symbol).tag(section)
                    }
                }
                Section(settings.t("sidebar.topics")) {
                    ForEach(Topic.feedTopics) { topic in
                        Button {
                            topicFilter = topicFilter == topic ? nil : topic
                            model.selectedSection = .home
                        } label: {
                            Label(settings.t(topic.localizationKey), systemImage: topic.symbolName)
                                .foregroundStyle(topicFilter == topic ? topic.tint : .primary)
                        }
                    }
                }
                Section(settings.t("sidebar.vocabSets")) {
                    ForEach(model.content.vocabSets) { set in
                        NavigationLink(set.title[settings.language]) { VocabSetView(set: set) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.surface)
            .navigationTitle("Culture")
        } detail: {
            switch model.selectedSection {
            case .home: NavigationStack { HomeView(topicFilter: $topicFilter) }
            case .agenda: AgendaSplitView()
            default: NavigationStack { model.selectedSection.rootView }
            }
        }
    }
}

extension AppSection {
    @MainActor @ViewBuilder var rootView: some View {
        switch self {
        case .home: HomeView(topicFilter: .constant(nil))
        case .agenda: AgendaView()
        case .vocabulary: VocabHomeView()
        case .collections: CollectionsView()
        case .profile: ProfileView()
        }
    }
}

/// ⌘F search across cards, vocabulary and events.
struct SearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if !query.isEmpty {
                    let q = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: settings.language.locale)
                    let match: (String) -> Bool = { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: settings.language.locale).contains(q) }
                    Section(settings.t("search.cards")) {
                        ForEach(model.content.cards.filter { match($0.title.fr) || match($0.title.en) || $0.tags.contains(where: match) }) { card in
                            NavigationLink(card.title[settings.language]) { CardDetailView(card: card) }
                        }
                    }
                    Section(settings.t("search.vocab")) {
                        ForEach(model.content.vocab.filter { match($0.term) || match($0.gloss) }) { entry in
                            NavigationLink(entry.term) { ScrollView { VocabCardView(entry: entry, revealed: true).padding() } }
                        }
                    }
                    Section(settings.t("search.events")) {
                        ForEach(model.content.events.filter { match($0.title) }) { event in
                            NavigationLink(event.title) { EventDetailView(event: event) }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: settings.t("search.prompt"))
            .navigationTitle(settings.t("menu.search"))
            .toolbar { Button(settings.t("common.close")) { dismiss() } }
        }
    }
}
