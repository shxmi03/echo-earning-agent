import Foundation
import UserNotifications

/// A daily practice reminder (features.csv: practice reminders). Local notification only:
/// nothing about it goes to a server. Off until the learner turns it on in Settings, and
/// the wording never guilts (brand voice: no streak shaming).
enum PracticeReminder {
    static let identifier = "practice-reminder"
    private static let onKey = "practiceReminder.on"
    private static let minuteKey = "practiceReminder.minuteOfDay"

    static var isOn: Bool { UserDefaults.standard.bool(forKey: onKey) }

    /// Minutes after midnight, local time. 18:30 until the learner picks a time.
    static var minuteOfDay: Int {
        UserDefaults.standard.object(forKey: minuteKey) as? Int ?? 18 * 60 + 30
    }

    static var time: Date {
        Calendar.current.date(bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: .now) ?? .now
    }

    /// Turns the reminder on at `time`. Returns false when notifications aren't allowed.
    @discardableResult
    static func turnOn(at time: Date) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else {
            UserDefaults.standard.set(false, forKey: onKey)
            return false
        }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let minute = (parts.hour ?? 18) * 60 + (parts.minute ?? 30)
        UserDefaults.standard.set(minute, forKey: minuteKey)
        UserDefaults.standard.set(true, forKey: onKey)

        let content = UNMutableNotificationContent()
        content.title = "Time at the piano?"
        content.body = "Pick up where you left off. A few minutes is plenty."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: minute / 60, minute: minute % 60), repeats: true)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        return true
    }

    static func turnOff() {
        UserDefaults.standard.set(false, forKey: onKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
