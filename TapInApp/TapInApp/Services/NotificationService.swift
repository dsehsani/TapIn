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
}
