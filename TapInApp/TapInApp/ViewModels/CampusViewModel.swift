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
    private var allEvents: [CampusEvent] = []

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
            allEvents = fetched
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

    // MARK: - AI Content Accessors
    // These read directly from the model — no extra fetching needed.

    func summary(for event: CampusEvent) -> String? {
        event.aiSummary
    }

    func bulletPoints(for event: CampusEvent) -> [String] {
        event.aiBulletPoints
    }
}
