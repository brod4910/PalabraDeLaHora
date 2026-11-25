import Foundation
import UserNotifications

/// Schedules a local notification for each upcoming word change, skipping quiet hours.
///
/// If a slot starts during quiet hours (e.g. the daily word at midnight), the notification is moved
/// to the end of quiet time when that still falls inside the slot; otherwise that word is skipped.
enum NotificationScheduler {
    static let idPrefix = "palabra.word."
    static let categoryID = "PALABRA_WORD"
    static let hearActionID = "PALABRA_HEAR"
    static let maxPending = 60 // iOS keeps at most 64 per app

    static var category: UNNotificationCategory {
        let hear = UNNotificationAction(identifier: hearActionID, title: "🔊 Hear it",
                                        options: [.foreground])
        return UNNotificationCategory(identifier: categoryID, actions: [hear], intentIdentifiers: [])
    }

    /// Asks for permission. Returns whether notifications are allowed.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) })

        guard AppSettings.notificationsEnabled else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let schedule = WordSchedule.current
        let calendar = Calendar.current
        var scheduled = 0
        var slot = schedule.slot(for: .now)

        // Look far enough ahead to fill the queue even with long quiet hours or daily cadence.
        var lookahead = maxPending * 4
        while scheduled < maxPending, lookahead > 0 {
            lookahead -= 1
            slot += 1
            let start = schedule.startOfSlot(slot)
            let end = schedule.startOfSlot(slot + 1)
            guard let fireDate = deliveryDate(slotStart: start, slotEnd: end, calendar: calendar) else { continue }

            let word = schedule.word(atPosition: slot + schedule.offset)
            let content = UNMutableNotificationContent()
            content.title = "\(word.spanish) — \(word.allMeanings)"
            content.subtitle = word.phonetic
            content.body = "\(word.example)\n\(word.exampleTranslation)"
            content.sound = .default
            content.threadIdentifier = "palabra"
            content.categoryIdentifier = categoryID
            content.userInfo = ["wordID": word.id]

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "\(idPrefix)\(slot)", content: content, trigger: trigger)
            try? await center.add(request)
            scheduled += 1
        }
    }

    private static func deliveryDate(slotStart: Date, slotEnd: Date, calendar: Calendar) -> Date? {
        let hour = calendar.component(.hour, from: slotStart)
        guard AppSettings.isQuiet(hour: hour) else { return slotStart }
        // Next time quiet hours end, after the slot starts.
        guard let wake = calendar.nextDate(after: slotStart,
                                           matching: DateComponents(hour: AppSettings.quietEnd, minute: 0),
                                           matchingPolicy: .nextTime) else { return nil }
        return wake < slotEnd ? wake : nil
    }
}
