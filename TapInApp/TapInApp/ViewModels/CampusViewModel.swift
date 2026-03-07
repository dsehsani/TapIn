//
//  CampusViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - Campus/Events ViewModel
//  Fetches AI-processed events from the TapIn backend.
//  Falls back to client-side AI summarization when backend
//  summaries are missing.
//

import Foundation
import SwiftUI
import Combine

class CampusViewModel: ObservableObject {
    @Published var events: [CampusEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var filterType: EventFilterType = .forYou
    @Published var timeFilter: EventTimeFilter = .thisWeek

    private let service = EventsAPIService.shared
    @Published private(set) var allEvents: [CampusEvent] = []

    /// Client-generated summaries for events missing backend AI content
    private var localSummaries: [UUID: String] = [:]

    init() {
        Task { await fetchEvents() }
    }

    // MARK: - Fetch from Backend

    @MainActor
    func fetchEvents() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await service.fetchEvents()
            allEvents = fetched.map { resolveLocation($0) }
            applyFilter()
            generateMissingSummaries()
        } catch {
            errorMessage = error.localizedDescription
            // Fall back to sample data if network fails
            allEvents = CampusEvent.sampleData
            applyFilter()
        }

        isLoading = false
    }

    // MARK: - Preference Engine

    /// Rebuilds the "For You" preference profile from the user's saved events.
    func setProfileEvents(_ events: [CampusEvent]) {
        EventPreferenceEngine.shared.rebuildProfile(from: events)
    }

    // MARK: - Filtering

    func filterEvents(by type: EventFilterType) {
        filterType = type
        applyFilter()
    }

    func filterByTime(_ filter: EventTimeFilter) {
        timeFilter = filter
        applyFilter()
    }

    func refreshEvents() async {
        await fetchEvents()
    }

    private func applyFilter() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        // Apply time window based on timeFilter
        let upcoming: [CampusEvent]
        switch timeFilter {
        case .today:
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            upcoming = allEvents.filter { $0.date >= startOfToday && $0.date < endOfToday }
                .sorted { $0.date < $1.date }
        case .thisWeek:
            let endDate = calendar.date(byAdding: .day, value: 7, to: startOfToday)!
            upcoming = allEvents.filter { $0.date >= startOfToday && $0.date <= endDate }
                .sorted { $0.date < $1.date }
        case .thisMonth:
            let endDate = calendar.date(byAdding: .day, value: 30, to: startOfToday)!
            upcoming = allEvents.filter { $0.date >= startOfToday && $0.date <= endDate }
                .sorted { $0.date < $1.date }
        case .allUpcoming:
            upcoming = allEvents.filter { $0.date >= startOfToday }
                .sorted { $0.date < $1.date }
        }

        // Apply category filter
        // Events without an organizerName are official UC Davis events;
        // events with one are from student clubs/orgs.
        switch filterType {
        case .all:
            events = upcoming
        case .forYou:
            events = EventPreferenceEngine.shared.recommend(from: upcoming)
        case .official:
            events = upcoming.filter { $0.organizerName == nil }
        case .studentPosted:
            events = upcoming.filter { $0.organizerName != nil }
        }
    }

    // MARK: - Location Resolution

    /// If an event's location is "TBD" or empty, try to extract it from the description.
    /// Falls back to "N/A" if nothing is found.
    private func resolveLocation(_ event: CampusEvent) -> CampusEvent {
        let loc = event.location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard loc.isEmpty || loc == "TBD" else { return event }

        let extracted = extractLocation(from: event.description)

        return CampusEvent(
            id: event.id,
            title: event.title,
            description: event.description,
            date: event.date,
            endDate: event.endDate,
            location: extracted ?? "N/A",
            isOfficial: event.isOfficial,
            imageURL: event.imageURL,
            organizerName: event.organizerName,
            clubAcronym: event.clubAcronym,
            eventType: event.eventType,
            tags: event.tags,
            eventURL: event.eventURL,
            organizerURL: event.organizerURL,
            aiSummary: event.aiSummary,
            aiBulletPoints: event.aiBulletPoints
        )
    }

    // Pre-compiled regex instances — compiling NSRegularExpression is expensive,
    // so these are shared across all extractLocation calls.
    private static let roomTrailingRegex = try? NSRegularExpression(
        pattern: #"^\s*,?\s*(?:Room|Rm\.?)\s*\d+[A-Za-z]?"#, options: .caseInsensitive)
    private static let labelRegex = try? NSRegularExpression(
        pattern: #"(?i)(?:location|where|place|venue)\s*[:：]\s*(.+)"#)
    private static let roomNumberRegex = try? NSRegularExpression(
        pattern: #"(?i)(?:room|rm\.?)\s*\d+[A-Za-z]?"#)

    /// Attempts to extract a location from event description text.
    private func extractLocation(from text: String) -> String? {
        // 1. Check for known UC Davis buildings/locations first (most reliable)
        let knownLocations = [
            "Memorial Union", "MU ", "ARC Pavilion", "ARC ",
            "Shields Library", "Wellman Hall", "Hutchison Hall",
            "Olson Hall", "Mondavi Center", "Freeborn Hall",
            "Young Hall", "Kemper Hall", "Cruess Hall",
            "Sciences Lecture Hall", "Giedt Hall", "Haring Hall",
            "Hunt Hall", "Walker Hall", "Rock Hall",
            "Student Community Center", "SCC ", "CoHo",
            "Coffee House", "Quad", "The Silo",
            "Activities and Recreation Center",
            "International Center", "Genome Center",
            "Conference Center", "Alumni Center",
            "Putah Creek Lodge", "Walter A. Buehler",
        ]

        for location in knownLocations {
            if let range = text.range(of: location, options: .caseInsensitive) {
                var result = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                // Grab a trailing room number if present (e.g., "Walker Hall 101")
                let after = String(text[range.upperBound...])
                if let roomRegex = CampusViewModel.roomTrailingRegex,
                   let roomMatch = roomRegex.firstMatch(in: after, range: NSRange(location: 0, length: (after as NSString).length)),
                   let roomRange = Range(roomMatch.range, in: after) {
                    let room = after[roomRange]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: ","))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    result += " \(room)"
                }
                return result
            }
        }

        // 2. Look for explicit labels: "Location: ...", "Where: ...", "Venue: ..."
        if let regex = CampusViewModel.labelRegex,
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            let candidate = String(text[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n").first ?? ""
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count <= 80 {
                return trimmed
            }
        }

        // 3. Look for room number patterns (e.g., "Room 101", "Rm 204")
        if let regex = CampusViewModel.roomNumberRegex,
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            return String(text[range])
        }

        return nil
    }

    // MARK: - AI Summaries

    /// Returns the AI summary for an event: backend-provided first, then local fallback.
    func summary(for event: CampusEvent) -> String? {
        if let backend = event.aiSummary { return backend }
        if let local = localSummaries[event.id] { return local }
        return nil
    }

    func bulletPoints(for event: CampusEvent) -> [String] {
        event.aiBulletPoints
    }

    /// Generates local summaries instantly for events missing backend AI content.
    private func generateMissingSummaries() {
        for event in allEvents where event.aiSummary == nil && localSummaries[event.id] == nil {
            localSummaries[event.id] = generateLocalSummary(from: event.description)
        }
    }

    /// Extracts the first sentence or truncates the description as a summary.
    private func generateLocalSummary(from description: String) -> String {
        let cleaned = description
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return "Campus event" }

        // Take first sentence
        if let dotRange = cleaned.range(of: ". ") ?? cleaned.range(of: ".") {
            let sentence = String(cleaned[cleaned.startIndex..<dotRange.upperBound]).trimmingCharacters(in: .whitespaces)
            if sentence.count > 10 && sentence.count <= 100 {
                return sentence
            }
        }

        // Truncate at word boundary
        if cleaned.count > 80 {
            let truncated = String(cleaned.prefix(80))
            if let lastSpace = truncated.lastIndex(of: " ") {
                return String(truncated[truncated.startIndex..<lastSpace]) + "..."
            }
            return truncated + "..."
        }

        return cleaned
    }
}
