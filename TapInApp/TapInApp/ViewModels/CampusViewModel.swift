//
//  CampusViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - Campus/Events ViewModel
//  Manages campus events and activities
//  TODO: ADD YOUR EVENTS DATA SOURCE HERE
//

import Foundation
import SwiftUI
import Combine

class CampusViewModel: ObservableObject {
    @Published var events: [CampusEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var filterType: EventFilterType = .all

    init() {
        loadEvents()
    }

    // TODO: REPLACE WITH YOUR EVENTS DATA SOURCE
    func fetchEvents() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.loadEvents()
            self.isLoading = false
        }
    }

    func fetchEventsAsync() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        await MainActor.run {
            loadEvents()
            isLoading = false
        }
    }

    func filterEvents(by type: EventFilterType) {
        filterType = type
        switch type {
        case .all:
            events = CampusEvent.sampleData
        case .official:
            events = CampusEvent.sampleData.filter { $0.isOfficial }
        case .studentPosted:
            events = CampusEvent.sampleData.filter { !$0.isOfficial }
        case .today:
            events = CampusEvent.sampleData.filter { Calendar.current.isDateInToday($0.date) }
        case .thisWeek:
            let weekFromNow = Date().addingTimeInterval(7 * 86400)
            events = CampusEvent.sampleData.filter { $0.date <= weekFromNow }
        }
    }

    func refreshEvents() async {
        await fetchEventsAsync()
    }

    private func loadEvents() {
        events = CampusEvent.sampleData
    }
}
