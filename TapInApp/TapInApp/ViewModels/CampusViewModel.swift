//
//  CampusViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - Campus/Events ViewModel
//  Fetches AI-processed events from the TapIn backend.
//  Events arrive with aiSummary and aiBulletPoints already populated —
//  no client-side Claude calls needed.
//

import Foundation
import SwiftUI
import Combine

class CampusViewModel: ObservableObject {
    @Published var events: [CampusEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var filterType: EventFilterType = .all

    private let service = EventsAPIService.shared
    @Published private(set) var allEvents: [CampusEvent] = []

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
        } catch {
            errorMessage = error.localizedDescription
            // Fall back to sample data if network fails
            allEvents = CampusEvent.sampleData
            applyFilter()
        }

        isLoading = false
    }

    // MARK: - Filtering

    func filterEvents(by type: EventFilterType) {
        filterType = type
        applyFilter()
    }

    func refreshEvents() async {
        await fetchEvents()
    }

    private func applyFilter() {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let oneWeekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: startOfToday)!

        // Only show events from today through the next 7 days
        let upcoming = allEvents.filter { $0.date >= startOfToday && $0.date <= oneWeekFromNow }
            .sorted { $0.date < $1.date }

        switch filterType {
        case .all:
            events = upcoming
        case .official:
            events = upcoming.filter { $0.isOfficial }
        case .studentPosted:
            events = upcoming.filter { !$0.isOfficial }
        case .today:
            events = upcoming.filter { Calendar.current.isDateInToday($0.date) }
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
                let after = text[range.upperBound...]
                let roomPattern = #"^\s*,?\s*(?:Room|Rm\.?)\s*\d+[A-Za-z]?"#
                if let roomRegex = try? NSRegularExpression(pattern: roomPattern, options: .caseInsensitive),
                   let roomMatch = roomRegex.firstMatch(in: String(after), range: NSRange(location: 0, length: (after as NSString).length)),
                   let roomRange = Range(roomMatch.range, in: String(after)) {
                    let room = String(after)[roomRange]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: ","))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    result += " \(room)"
                }
                return result
            }
        }

        // 2. Look for explicit labels: "Location: ...", "Where: ...", "Venue: ..."
        let labelPattern = #"(?i)(?:location|where|place|venue)\s*[:：]\s*(.+)"#
        if let regex = try? NSRegularExpression(pattern: labelPattern),
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
        let roomPattern = #"(?i)(?:room|rm\.?)\s*\d+[A-Za-z]?"#
        if let regex = try? NSRegularExpression(pattern: roomPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            return String(text[range])
        }

        return nil
    }

    // MARK: - AI Content Accessors
    // These read directly from the model — no extra fetching needed.

    func summary(for event: CampusEvent) -> String? {
        event.aiSummary
    }

    func bulletPoints(for event: CampusEvent) -> [String] {
        event.aiBulletPoints
    }
}
