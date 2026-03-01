//
//  EventPreferenceEngine.swift
//  TapInApp
//
//  Created by Claude on 3/1/26.
//
//  MARK: - Event Preference Engine
//  Builds a preference profile from the user's saved/attended events,
//  then scores upcoming events by affinity to organizers, event types, and tags.
//  Entirely client-side — no backend dependency.
//

import Foundation

// MARK: - Preference Profile

struct EventPreferenceProfile: Codable {
    var organizerAffinities: [String: Int] = [:]
    var eventTypeAffinities: [String: Int] = [:]
    var tagAffinities: [String: Int] = [:]
    var totalEventsAnalyzed: Int = 0

    var hasHistory: Bool { totalEventsAnalyzed > 0 }
}

// MARK: - Preference Engine

class EventPreferenceEngine {

    static let shared = EventPreferenceEngine()

    private let profileKey = "eventPreferenceProfile"
    private(set) var profile = EventPreferenceProfile()

    var hasHistory: Bool { profile.hasHistory }

    private init() {
        loadProfile()
    }

    // MARK: - Profile Building

    /// Rebuilds the preference profile from scratch using the user's saved events.
    func rebuildProfile(from events: [CampusEvent]) {
        var newProfile = EventPreferenceProfile()

        for event in events {
            if let organizer = event.organizerName, !organizer.isEmpty {
                let key = organizer.lowercased()
                newProfile.organizerAffinities[key, default: 0] += 1
            }

            if let eventType = event.eventType, !eventType.isEmpty {
                let key = eventType.lowercased()
                newProfile.eventTypeAffinities[key, default: 0] += 1
            }

            for tag in event.tags where !tag.isEmpty {
                let key = tag.lowercased()
                newProfile.tagAffinities[key, default: 0] += 1
            }

            newProfile.totalEventsAnalyzed += 1
        }

        profile = newProfile
        saveProfile()
    }

    // MARK: - Scoring

    /// Scores a single event based on the current preference profile.
    /// Returns 0.0 if no history exists.
    func score(event: CampusEvent) -> Double {
        guard profile.hasHistory else { return 0.0 }

        let orgScore = organizerScore(for: event)
        let typeScore = eventTypeScore(for: event)
        let tagScore = tagScore(for: event)

        // Weighted sum: organizer 40%, event type 30%, tags 30%
        return orgScore * 0.4 + typeScore * 0.3 + tagScore * 0.3
    }

    /// Returns recommended events sorted by descending score.
    /// Preserves chronological order for events with equal scores.
    func recommend(from events: [CampusEvent]) -> [CampusEvent] {
        guard profile.hasHistory else { return events }

        let scored = events.map { (event: $0, score: score(event: $0)) }

        // Stable sort: descending by score, preserving original order for ties
        let sorted = scored.sorted { a, b in
            if a.score != b.score {
                return a.score > b.score
            }
            return false // preserve original order for equal scores
        }

        return sorted.map { $0.event }
    }

    // MARK: - Sub-scores

    private func organizerScore(for event: CampusEvent) -> Double {
        guard let organizer = event.organizerName, !organizer.isEmpty else { return 0.0 }
        let key = organizer.lowercased()
        guard let count = profile.organizerAffinities[key] else { return 0.0 }
        let maxCount = profile.organizerAffinities.values.max() ?? 1
        return Double(count) / Double(maxCount)
    }

    private func eventTypeScore(for event: CampusEvent) -> Double {
        guard let eventType = event.eventType, !eventType.isEmpty else { return 0.0 }
        let key = eventType.lowercased()
        guard let count = profile.eventTypeAffinities[key] else { return 0.0 }
        let maxCount = profile.eventTypeAffinities.values.max() ?? 1
        return Double(count) / Double(maxCount)
    }

    private func tagScore(for event: CampusEvent) -> Double {
        guard !event.tags.isEmpty else { return 0.0 }
        let maxCount = profile.tagAffinities.values.max() ?? 1
        guard maxCount > 0 else { return 0.0 }

        var totalAffinity = 0.0
        var matchCount = 0

        for tag in event.tags where !tag.isEmpty {
            let key = tag.lowercased()
            if let count = profile.tagAffinities[key] {
                totalAffinity += Double(count) / Double(maxCount)
                matchCount += 1
            }
        }

        guard matchCount > 0 else { return 0.0 }
        return totalAffinity / Double(matchCount)
    }

    // MARK: - Persistence

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    private func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(EventPreferenceProfile.self, from: data) {
            profile = decoded
        }
    }
}
