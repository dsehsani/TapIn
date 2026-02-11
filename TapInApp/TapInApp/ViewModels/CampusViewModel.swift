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

    private let service = AggieLifeService()
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
