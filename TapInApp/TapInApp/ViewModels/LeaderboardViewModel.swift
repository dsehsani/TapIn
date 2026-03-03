//
//  LeaderboardViewModel.swift
//  TapInApp
//
//  Created by Claude on 2/21/26.
//

import Foundation

@Observable
class LeaderboardViewModel {

    // MARK: - State

    var selectedDate: Date = Date()
    var showingDatePicker: Bool = false
    var entries: [LeaderboardEntryResponse] = []
    var isLoading: Bool = false
    var errorMessage: String?

    /// Tracks the current load task so we can cancel it on re-entry
    private var loadTask: Task<Void, Never>?

    // MARK: - Date Helpers

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var formattedDate: String {
        displayFormatter.string(from: selectedDate)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var canGoForward: Bool {
        !isToday
    }

    var hasEntries: Bool {
        !entries.isEmpty
    }

    // MARK: - Data Loading

    @MainActor
    func loadData() async {
        // Cancel any in-flight load to avoid race conditions
        loadTask?.cancel()

        let task = Task { @MainActor in
            isLoading = true
            errorMessage = nil

            let dateKey = dateFormatter.string(from: selectedDate)

            do {
                let result = try await LeaderboardService.shared.fetchLeaderboard(for: dateKey, limit: 10)
                guard !Task.isCancelled else { return }
                entries = result
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = "Unable to load leaderboard"
                entries = []
            }

            isLoading = false
        }

        loadTask = task
        await task.value
    }

    // MARK: - Date Navigation

    func previousDay() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = newDate
        Task { await loadData() }
    }

    func nextDay() {
        guard canGoForward else { return }
        guard let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = newDate
        Task { await loadData() }
    }

    func goToToday() {
        selectedDate = Date()
        Task { await loadData() }
    }

    func selectDate(_ date: Date) {
        selectedDate = min(date, Date())
        showingDatePicker = false
        Task { await loadData() }
    }

    // MARK: - Current User Check

    func isCurrentUserEntry(_ entry: LeaderboardEntryResponse) -> Bool {
        let name = AppState.shared.userName
        guard name != "Guest" else { return false }
        return entry.username == name
    }

    // MARK: - Refresh

    @MainActor
    func refresh() async {
        await loadData()
    }
}
