//
//  AnalyticsTracker.swift
//  TapInApp
//
//  Lightweight fire-and-forget DAU tracker.
//  Sends one event per (user, action, day) to the backend.
//  Silent on failure — never blocks the UI.
//

import Foundation

// MARK: - Trackable Actions

enum AnalyticsAction: String {
    case articleRead   = "article_read"
    case eventViewed   = "event_viewed"
    case wordlePlayed  = "wordle_played"
    case echoPlayed    = "echo_played"
    case pipesPlayed   = "pipes_played"
}

// MARK: - Analytics Tracker

final class AnalyticsTracker: Sendable {

    static let shared = AnalyticsTracker()

    private static let dauKey = "dau_tracked_actions"

    // Pacific timezone for day boundary (UC Davis)
    private static let pacificZone = TimeZone(identifier: "America/Los_Angeles")!

    private init() {}

    // MARK: - Public API

    /// Track a user action for DAU reporting.
    /// Deduplicates per (user, action, day) on the client side and
    /// fires a non-blocking POST to the backend.
    func track(_ action: AnalyticsAction) {
        // Skip guest users
        guard !AppState.shared.isGuest else { return }

        let today = Self.todayString()
        let dedupKey = "\(today)_\(action.rawValue)"

        // Client-side daily dedup
        var tracked = UserDefaults.standard.stringArray(forKey: Self.dauKey) ?? []
        guard !tracked.contains(dedupKey) else { return }

        // Record locally before sending
        tracked = tracked.filter { $0.hasPrefix(today) } // prune old days
        tracked.append(dedupKey)
        UserDefaults.standard.set(tracked, forKey: Self.dauKey)

        // Fire-and-forget network call
        Task { try? await sendEvent(action: action, date: today) }
    }

    // MARK: - Private

    private func sendEvent(action: AnalyticsAction, date: String) async throws {
        guard let url = URL(string: APIConfig.analyticsTrackURL) else { return }

        // Build user identifier from backend token or SMS user ID
        let userId: String? = await MainActor.run {
            AppState.shared.backendToken ?? AppState.shared.smsUserId
        }
        guard let userId else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: String] = [
            "user_id": userId,
            "action": action.rawValue,
            "date": date
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        _ = try await URLSession.shared.data(for: request)
    }

    /// Returns today's date string in `yyyy-MM-dd` using Pacific time.
    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = pacificZone
        return formatter.string(from: Date())
    }
}
