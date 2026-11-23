import Foundation
import UserNotifications
import CultureCore

/// Local and push notifications. Permission is requested in context (when the user
/// sets a reminder or enables "Mot du jour"), never on first launch.
/// At most one non-explicit notification per day, never during quiet hours.
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private let schedule = EventSchedule()

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    /// "Rappel": explicit reminder one day before (exempt from the daily cap).
    func scheduleReminder(for event: CulturalEvent, venueName: String, settings: AppSettings) async -> Bool {
        guard await requestAuthorizationIfNeeded(), let fireDate = schedule.reminderDate(for: event), fireDate > .now else { return false }
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = settings.t("notification.reminder.body", venueName, schedule.formattedStart(event, language: settings.language))
        content.sound = .default
        content.userInfo = ["deeplink": "culture://event/\(event.id)"]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(identifier: "reminder.\(event.id)", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        do { try await center.add(request); return true } catch { return false }
    }

    func cancelReminder(eventID: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["reminder.\(eventID)"])
    }

    /// Daily "Mot du jour" at a time outside quiet hours.
    func scheduleDailyWord(_ entry: VocabEntry?, settings: AppSettings) async {
        center.removePendingNotificationRequests(withIdentifiers: ["daily.word"])
        guard settings.dailyWordNotification, let entry, await requestAuthorizationIfNeeded() else { return }
        let content = UNMutableNotificationContent()
        content.title = settings.t("notification.wordOfDay.title")
        content.body = "\(entry.term) — \(entry.definition)"
        content.userInfo = ["deeplink": "culture://vocab/\(entry.id)"]
        var components = DateComponents()
        components.hour = Self.deliveryHour(quietStart: settings.quietHoursStart, quietEnd: settings.quietHoursEnd)
        components.minute = 0
        let request = UNNotificationRequest(identifier: "daily.word", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
        try? await center.add(request)
    }

    /// First full hour after quiet hours end (default 09:00 when quiet hours end at 08:00).
    static func deliveryHour(quietStart: Int, quietEnd: Int) -> Int {
        let candidate = (quietEnd + 1) % 24
        let inQuiet = quietStart > quietEnd
            ? (candidate >= quietStart || candidate < quietEnd)
            : (candidate >= quietStart && candidate < quietEnd)
        return inQuiet ? quietEnd : candidate
    }

    func removeAll() {
        center.removeAllPendingNotificationRequests()
    }
}
