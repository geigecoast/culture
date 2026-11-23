import SwiftUI
import AuthenticationServices
import CultureCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var email = ""
    @State private var magicLinkSent = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteFailed = false
    @State private var exportURL: URL?

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section(settings.t("settings.language")) {
                Picker(settings.t("settings.language"), selection: Binding(get: { settings.language }, set: { settings.setLanguage($0) })) {
                    Text("Français").tag(AppLanguage.fr)
                    Text("English").tag(AppLanguage.en)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.language")
                Toggle(settings.t("settings.followDevice"), isOn: Binding(get: { settings.followsDeviceLanguage }, set: { follow in
                    settings.followsDeviceLanguage = follow
                    if follow { settings.language = AppLanguage.fromPreferred() }
                }))
            }

            // One tap per city: acceptance criterion "add Paris or München in under two taps".
            Section(settings.t("settings.cities")) {
                ForEach(model.content.cities) { city in
                    Toggle(city.name[settings.language], isOn: Binding(
                        get: { settings.cityIDs.contains(city.id) },
                        set: { on in
                            if on { settings.cityIDs.insert(city.id) }
                            else if settings.cityIDs.count > 1 { settings.cityIDs.remove(city.id) }
                        }))
                    .accessibilityIdentifier("settings.city.\(city.id)")
                }
            }

            Section(settings.t("settings.notifications")) {
                Toggle(settings.t("settings.dailyWord"), isOn: $settings.dailyWordNotification)
                    .onChange(of: settings.dailyWordNotification) { _, _ in
                        Task { await model.notifications.scheduleDailyWord(model.wordOfTheDay, settings: settings) }
                    }
                Stepper(settings.t("settings.quietStart", settings.quietHoursStart), value: $settings.quietHoursStart, in: 0...23)
                Stepper(settings.t("settings.quietEnd", settings.quietHoursEnd), value: $settings.quietHoursEnd, in: 0...23)
                Text(settings.t("settings.notificationsNote")).font(.footnote).foregroundStyle(.secondary)
            }

            Section(settings.t("settings.wellbeing")) {
                Toggle(settings.t("settings.screenTime"), isOn: $settings.screenTimeReminderEnabled)
                if settings.screenTimeReminderEnabled {
                    Picker(settings.t("settings.screenTimeAfter"), selection: $settings.screenTimeReminderMinutes) {
                        ForEach([15, 30, 45, 60], id: \.self) { Text(settings.t("onboarding.goal.minutes", $0)).tag($0) }
                    }
                }
                Picker(settings.t("onboarding.goal.title"), selection: $settings.dailyGoalMinutes) {
                    ForEach([5, 10, 20], id: \.self) { Text(settings.t("onboarding.goal.minutes", $0)).tag($0) }
                }
            }

            Section(settings.t("settings.privacy")) {
                Picker(settings.t("settings.attendance"), selection: $settings.attendanceVisibility) {
                    Text(settings.t("visibility.private")).tag(AttendanceVisibility.private)
                    Text(settings.t("visibility.friends")).tag(AttendanceVisibility.friends)
                    Text(settings.t("visibility.public")).tag(AttendanceVisibility.public)
                }
                Toggle(settings.t("settings.analytics"), isOn: Binding(get: { settings.analyticsConsent ?? false }, set: { settings.analyticsConsent = $0 }))
                Text(settings.t("settings.analyticsNote")).font(.footnote).foregroundStyle(.secondary)
            }

            Section(settings.t("settings.account")) {
                if let session = model.auth.session {
                    Text(session.email ?? session.userID).foregroundStyle(.secondary)
                    Button(settings.t("settings.export")) {
                        Task {
                            if let data = await model.exportData() {
                                let url = FileManager.default.temporaryDirectory.appending(path: "culture-export.json")
                                try? data.write(to: url)
                                exportURL = url
                            }
                        }
                    }
                    if let exportURL { ShareLink(settings.t("settings.exportShare"), item: exportURL) }
                    Button(settings.t("settings.signOut")) { model.auth.signOut() }
                } else {
                    Text(settings.t("settings.anonymousNote")).font(.footnote).foregroundStyle(.secondary)
                    SignInWithAppleButton(.signIn) { request in
                        model.auth.prepare(request)
                    } onCompletion: { result in
                        Task { await model.auth.handle(result) }
                    }
                    .frame(height: 44)
                    TextField(settings.t("settings.email"), text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    Button(settings.t(magicLinkSent ? "settings.magicLinkSent" : "settings.magicLink")) {
                        Task { magicLinkSent = await model.auth.sendMagicLink(to: email) }
                    }
                    .disabled(!email.contains("@") || magicLinkSent)
                }
                Button(settings.t("settings.deleteAccount"), role: .destructive) { confirmDelete = true }
                    .disabled(deleting)
                    .accessibilityIdentifier("settings.deleteAccount")
            }

            Section {
                Text(settings.t("settings.contentNote")).font(.footnote).foregroundStyle(.secondary)
                Text("Content v\(model.content.version)").font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(settings.t("settings.title"))
        .confirmationDialog(settings.t("settings.deleteConfirmTitle"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(settings.t("settings.deleteConfirm"), role: .destructive) {
                deleting = true
                Task {
                    deleteFailed = !(await model.deleteAccount())
                    deleting = false
                }
            }
        } message: {
            Text(settings.t("settings.deleteConfirmMessage"))
        }
        .alert(settings.t("settings.deleteFailed"), isPresented: $deleteFailed) { Button("OK", role: .cancel) {} }
    }
}
