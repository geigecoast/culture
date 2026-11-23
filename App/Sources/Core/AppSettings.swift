import Foundation
import Observation
import CultureCore

/// User preferences, persisted in UserDefaults (shared with widgets through the App Group).
/// Reading any property from a view registers an Observation dependency, so changing
/// `language` re-renders the UI in place, without restarting and without losing scroll position.
@Observable
@MainActor
final class AppSettings {
    static let appGroupID = "group.com.geigecoast.culture"
    private let defaults: UserDefaults

    var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: Keys.language) } }
    /// When true, the language follows the device until the user picks one in-app.
    var followsDeviceLanguage: Bool { didSet { defaults.set(followsDeviceLanguage, forKey: Keys.followsDevice) } }
    var cityIDs: Set<String> { didSet { defaults.set(Array(cityIDs), forKey: Keys.cities) } }
    var interests: Set<Topic> { didSet { defaults.set(interests.map(\.rawValue), forKey: Keys.interests) } }
    var dailyGoalMinutes: Int { didSet { defaults.set(dailyGoalMinutes, forKey: Keys.dailyGoal) } }
    var frenchSelfAssessment: Int { didSet { defaults.set(frenchSelfAssessment, forKey: Keys.frenchLevel) } }
    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) } }
    var screenTimeReminderEnabled: Bool { didSet { defaults.set(screenTimeReminderEnabled, forKey: Keys.screenTime) } }
    var screenTimeReminderMinutes: Int { didSet { defaults.set(screenTimeReminderMinutes, forKey: Keys.screenTimeMinutes) } }
    var dailyWordNotification: Bool { didSet { defaults.set(dailyWordNotification, forKey: Keys.dailyWord) } }
    var quietHoursStart: Int { didSet { defaults.set(quietHoursStart, forKey: Keys.quietStart) } }
    var quietHoursEnd: Int { didSet { defaults.set(quietHoursEnd, forKey: Keys.quietEnd) } }
    /// GDPR: analytics stay off until the user explicitly opts in.
    var analyticsConsent: Bool? {
        didSet {
            if let analyticsConsent { defaults.set(analyticsConsent, forKey: Keys.analytics) }
            else { defaults.removeObject(forKey: Keys.analytics) }
        }
    }
    var attendanceVisibility: AttendanceVisibility { didSet { defaults.set(attendanceVisibility.rawValue, forKey: Keys.attendance) } }
    var showBothLanguagesOnIPad: Bool { didSet { defaults.set(showBothLanguagesOnIPad, forKey: Keys.sideBySide) } }

    init(defaults: UserDefaults = UserDefaults(suiteName: AppSettings.appGroupID) ?? .standard) {
        self.defaults = defaults
        let follows = defaults.object(forKey: Keys.followsDevice) as? Bool ?? true
        followsDeviceLanguage = follows
        language = follows ? AppLanguage.fromPreferred()
            : AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? AppLanguage.fromPreferred()
        cityIDs = Set(defaults.stringArray(forKey: Keys.cities) ?? [])
        interests = Set((defaults.stringArray(forKey: Keys.interests) ?? []).compactMap(Topic.init(rawValue:)))
        dailyGoalMinutes = defaults.object(forKey: Keys.dailyGoal) as? Int ?? 10
        frenchSelfAssessment = defaults.object(forKey: Keys.frenchLevel) as? Int ?? 2
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        screenTimeReminderEnabled = defaults.object(forKey: Keys.screenTime) as? Bool ?? true
        screenTimeReminderMinutes = defaults.object(forKey: Keys.screenTimeMinutes) as? Int ?? 30
        dailyWordNotification = defaults.bool(forKey: Keys.dailyWord)
        quietHoursStart = defaults.object(forKey: Keys.quietStart) as? Int ?? 22
        quietHoursEnd = defaults.object(forKey: Keys.quietEnd) as? Int ?? 8
        analyticsConsent = defaults.object(forKey: Keys.analytics) as? Bool
        attendanceVisibility = AttendanceVisibility(rawValue: defaults.string(forKey: Keys.attendance) ?? "") ?? .private
        showBothLanguagesOnIPad = defaults.bool(forKey: Keys.sideBySide)
    }

    func setLanguage(_ newValue: AppLanguage) {
        followsDeviceLanguage = false
        language = newValue
    }

    /// Localized UI string in the in-app language. See `L10n`.
    func t(_ key: String, _ args: CVarArg...) -> String {
        L10n.string(key, language: language, args: args)
    }

    func resetForAccountDeletion() {
        for key in Keys.all { defaults.removeObject(forKey: key) }
    }

    private enum Keys {
        static let language = "language", followsDevice = "followsDeviceLanguage", cities = "cityIDs"
        static let interests = "interests", dailyGoal = "dailyGoalMinutes", frenchLevel = "frenchSelfAssessment"
        static let onboarding = "hasCompletedOnboarding", screenTime = "screenTimeReminderEnabled"
        static let screenTimeMinutes = "screenTimeReminderMinutes", dailyWord = "dailyWordNotification"
        static let quietStart = "quietHoursStart", quietEnd = "quietHoursEnd", analytics = "analyticsConsent"
        static let attendance = "attendanceVisibility", sideBySide = "showBothLanguagesOnIPad"
        static let all = [language, followsDevice, cities, interests, dailyGoal, frenchLevel, onboarding, screenTime,
                          screenTimeMinutes, dailyWord, quietStart, quietEnd, analytics, attendance, sideBySide]
    }
}
