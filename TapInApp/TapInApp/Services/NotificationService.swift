//
//  NotificationService.swift
//  TapInApp
//
//  Singleton wrapping UNUserNotificationCenter for scheduling
//  local push notifications for saved campus events.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    /// Requests notification permission the first time it's called; returns current status on subsequent calls.
    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        default:
            return false
        }
    }

    // MARK: - Schedule

    /// Schedules two reminders for a saved event: 1 day before and 1 hour before.
    /// Skips if the fire date is already in the past or notifications are disabled.
    func scheduleReminders(for event: CampusEvent) async {
        guard AppState.shared.notificationsEnabled else { return }
        let granted = await requestPermissionIfNeeded()
        guard granted else { return }

        let stableId = event.stableNotificationId
        let now = Date()

        // 1-day reminder
        if let fireDate = Calendar.current.date(byAdding: .day, value: -1, to: event.date),
           fireDate > now {
            let content = UNMutableNotificationContent()
            content.title = "Tomorrow: \(event.title)"
            content.body = "\(event.location) · \(event.date.formatted(date: .omitted, time: .shortened))"
            content.sound = .default

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "\(stableId)_1day", content: content, trigger: trigger)
            try? await center.add(request)
        }

        // 1-hour reminder
        if let fireDate = Calendar.current.date(byAdding: .hour, value: -1, to: event.date),
           fireDate > now {
            let content = UNMutableNotificationContent()
            content.title = "Starting Soon: \(event.title)"
            content.body = "\(event.location) · \(event.date.formatted(date: .omitted, time: .shortened))"
            content.sound = .default

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "\(stableId)_1hour", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    // MARK: - Cancel

    /// Cancels both reminders for a specific event.
    func cancelReminders(for event: CampusEvent) {
        let stableId = event.stableNotificationId
        center.removePendingNotificationRequests(withIdentifiers: [
            "\(stableId)_1day",
            "\(stableId)_1hour"
        ])
    }

    /// Cancels all pending notifications (used on sign-out or notifications toggle-off).
    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - DailyFive Reminders

    private let dailyFiveMessages: [(title: String, body: String)] = [
        ("Your DailyFive is waiting! 🧩", "Solve today's word and climb the leaderboard."),
        ("Can you crack today's word?", "DailyFive is live — see if you can top the leaderboard."),
        ("Today's puzzle is unsolved.", "Jump in and see where you rank on today's leaderboard."),
        ("The leaderboard is filling up!", "Don't miss your shot at today's DailyFive."),
        ("Word of the day — solved yet?", "Your DailyFive streak is waiting. Keep it going!"),
        ("Quick challenge for you 🎯", "Today's DailyFive word is live. How fast can you get it?"),
    ]

    /// Schedules one reminder per day for the next 7 days at a random time between 10am–8pm.
    /// Safe to call repeatedly — cancels any existing DailyFive reminders before rescheduling.
    func scheduleDailyFiveReminders() async {
        guard AppState.shared.notificationsEnabled else { return }
        let granted = await requestPermissionIfNeeded()
        guard granted else { return }

        // Remove stale DailyFive reminders before rescheduling
        let pending = await center.pendingNotificationRequests()
        let staleIds = pending
            .map { $0.identifier }
            .filter { $0.hasPrefix("dailyfive_reminder_") }
        center.removePendingNotificationRequests(withIdentifiers: staleIds)

        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for dayOffset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }

            // Random hour between 10 and 19 (10am–7pm), random minute
            let hour = Int.random(in: 10...19)
            let minute = Int.random(in: 0...59)

            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = hour
            comps.minute = minute

            let message = dailyFiveMessages[dayOffset % dailyFiveMessages.count]
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "dailyfive_reminder_\(df.string(from: day))"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Cancels today's DailyFive reminder (call when the user completes or loses the puzzle).
    func cancelTodaysDailyFiveReminder() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let todayId = "dailyfive_reminder_\(df.string(from: Date()))"
        center.removePendingNotificationRequests(withIdentifiers: [todayId])
    }
}
