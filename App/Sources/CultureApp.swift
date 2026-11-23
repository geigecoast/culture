import SwiftUI
import SwiftData

@main
struct CultureApp: App {
    private let container: ModelContainer
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isUITest)
        do {
            container = try ModelContainer(for: Schema(PersistenceSchema.models), configurations: configuration)
        } catch {
            fatalError("Could not open the local store: \(error)")
        }
        let settings = AppSettings(defaults: isUITest ? UserDefaults(suiteName: "ui-tests-\(UUID())")! : UserDefaults(suiteName: AppSettings.appGroupID) ?? .standard)
        if ProcessInfo.processInfo.arguments.contains("-skip-onboarding") {
            settings.hasCompletedOnboarding = true
            settings.interests = [.art, .music, .history, .politics, .geopolitics]
        }
        if let lang = ProcessInfo.processInfo.arguments.firstIndex(of: "-app-language").map({ ProcessInfo.processInfo.arguments[$0 + 1] }) {
            settings.setLanguage(.init(rawValue: lang) ?? .fr)
        }
        _model = State(initialValue: AppModel(container: container, settings: settings))
        Theme.configureUIKitAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.settings)
                .environment(model.store)
                .environment(\.locale, model.settings.language.locale)
                .preferredColorScheme(model.settings.followsSystemAppearance ? nil : .dark)
                .tint(Theme.gold)
                .task { await model.loadContent() }
                .onOpenURL { model.handle($0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { model.handle(url) }
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.didBecomeActive()
            case .background: model.didEnterBackground()
            default: break
            }
        }
        .commands { AppCommands(model: model) }
    }
}

/// iPad hardware-keyboard shortcuts: ⌘F search, ⌘1–5 sections.
struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu(model.settings.t("menu.navigate")) {
            Button(model.settings.t("menu.search")) { model.isSearchPresented = true }
                .keyboardShortcut("f", modifiers: .command)
            Divider()
            ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { index, section in
                Button(model.settings.t(section.titleKey)) { model.selectedSection = section }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
    }
}
