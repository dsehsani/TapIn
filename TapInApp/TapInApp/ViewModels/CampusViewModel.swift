//
//  CampusViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - Campus/Events ViewModel
//  Manages campus events fetched from Aggie Life iCal feed.
//

import Foundation
import SwiftUI
import Combine

class CampusViewModel: ObservableObject {
    @Published var events: [CampusEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var filterType: EventFilterType = .all
    @Published var eventSummaries: [String: String] = [:]  // [event title+date hash : summary]

    private let service = AggieLifeService()
    private let claudeService = ClaudeAPIService.shared
    private var allEvents: [CampusEvent] = []

    init() {
        Task { await fetchEvents() }
    }

    // MARK: - Fetch from Aggie Life

    @MainActor
    func fetchEvents() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await service.fetchEvents()
            allEvents = cleanEvents(fetched)
            applyFilter()
        } catch {
            errorMessage = error.localizedDescription
            // Fall back to sample data if network fails
            allEvents = CampusEvent.sampleData
            applyFilter()
        }

        isLoading = false

        // Fetch AI summaries in the background (non-blocking)
        Task { await fetchSummaries() }
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
        switch filterType {
        case .all:
            events = allEvents
        case .official:
            events = allEvents.filter { $0.isOfficial }
        case .studentPosted:
            events = allEvents.filter { !$0.isOfficial }
        case .today:
            events = allEvents.filter { Calendar.current.isDateInToday($0.date) }
        }
    }

    // MARK: - AI Summaries

    /// Fetches AI summaries for all events with long descriptions.
    /// Summaries are cached in UserDefaults so subsequent loads are instant.
    @MainActor
    func fetchSummaries() async {
        for event in allEvents {
            let key = summaryKey(for: event)

            // Skip if already loaded
            guard eventSummaries[key] == nil else {
                continue
            }

            if let summary = await claudeService.summarizeEvent(description: event.description) {
                eventSummaries[key] = summary
            }
        }
    }

    /// Returns the summary for a given event, or nil if not available.
    func summary(for event: CampusEvent) -> String? {
        eventSummaries[summaryKey(for: event)]
    }

    /// Creates a stable key for an event (title + date, since UUIDs regenerate).
    private func summaryKey(for event: CampusEvent) -> String {
        "\(event.title)_\(event.date.timeIntervalSince1970)"
    }

    // MARK: - Event Cleaning

    /// Removes irrelevant events before they reach the UI.
    /// - Filters out events with "meeting" in the title (club-internal meetings)
    /// - Only keeps events within the current week
    private func cleanEvents(_ events: [CampusEvent]) -> [CampusEvent] {
        let now = Date()
        let calendar = Calendar.current
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)) else {
            return events
        }

        return events.filter { event in
            // Remove events with "meeting" in the title
            let hasMeeting = event.title.localizedCaseInsensitiveContains("meeting")
            if hasMeeting { return false }

            // Only keep events within the current week
            return event.date >= now && event.date <= endOfWeek
        }
    }
}
