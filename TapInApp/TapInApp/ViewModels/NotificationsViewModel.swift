//
//  NotificationsViewModel.swift
//  TapInApp
//
//  Manages notification bell state: unseen event tracking,
//  mark-as-seen, and "For You" event suggestions.
//

import Foundation
import Combine

@MainActor
class NotificationsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var hasUnseenNotifications: Bool = false

    // MARK: - Unseen Tracking

    private let unseenKey = "unseenNotificationEventIds"

    private var unseenEventIds: Set<String> {
        didSet {
            hasUnseenNotifications = !unseenEventIds.isEmpty
            persistUnseen()
        }
    }

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: "unseenNotificationEventIds") ?? []
        self.unseenEventIds = Set(stored)
        self.hasUnseenNotifications = !stored.isEmpty
    }

    // MARK: - Public API

    /// Called when an event is saved — adds it to the unseen set so the red dot appears.
    func markEventAsUnseen(_ event: CampusEvent) {
        unseenEventIds.insert(event.stableNotificationId)
    }

    /// Called when the bell sheet opens — clears the red dot.
    func markAllAsSeen() {
        unseenEventIds.removeAll()
    }

    /// Called when an event is unsaved — remove from unseen if present.
    func removeFromUnseen(_ event: CampusEvent) {
        unseenEventIds.remove(event.stableNotificationId)
    }

    /// Returns 1-2 upcoming unsaved events ranked by EventPreferenceEngine.
    func suggestedEvents(allEvents: [CampusEvent], savedEvents: [CampusEvent]) -> [CampusEvent] {
        let now = Date()
        let savedIds = Set(savedEvents.map { $0.stableNotificationId })

        let candidates = allEvents.filter { event in
            event.date > now && !savedIds.contains(event.stableNotificationId)
        }

        let ranked = EventPreferenceEngine.shared.recommend(from: candidates)
        return Array(ranked.prefix(2))
    }

    // MARK: - Persistence

    private func persistUnseen() {
        UserDefaults.standard.set(Array(unseenEventIds), forKey: unseenKey)
    }
}
