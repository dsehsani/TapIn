//
//  LeaderboardViewModel.swift
//  TapInApp
//
//  MARK: - Leaderboard ViewModel
//  Manages leaderboard state for displaying scores across all games.
//  Supports game type filtering, date selection, and score ranking.
//

import Foundation
import SwiftUI

// MARK: - Leaderboard ViewModel

@Observable
class LeaderboardViewModel {

    // MARK: - Selection State

    /// Currently selected game type for filtering
    var selectedGameType: GameType = .wordle

    /// Selected date for viewing scores
    var selectedDate: Date = Date()

    /// Whether the date picker is showing
    var showingDatePicker: Bool = false

    // MARK: - Data State

    /// Scores for the selected game and date
    var scores: [LocalScore] = []

    /// User's personal score for today (if exists)
    var userTodayScore: LocalScore?

    /// User stats for selected game
    var userStats: GameStats = GameStats()

    /// All-time best score for selected game
    var bestScore: LocalScore?

    // MARK: - Loading State

    var isLoading: Bool = false

    // MARK: - Computed Properties

    /// Available game types that have leaderboards
    var availableGameTypes: [GameType] {
        [.wordle, .echo, .crossword]
    }

    /// Formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: selectedDate)
        }
    }

    /// Whether viewing today's scores
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// Number of scores for the current selection
    var scoreCount: Int {
        scores.count
    }

    /// Whether there are any scores to display
    var hasScores: Bool {
        !scores.isEmpty
    }

    /// Display name for selected game
    var selectedGameDisplayName: String {
        selectedGameType.displayName
    }

    // MARK: - Initialization

    init() {
        loadData()
    }

    // MARK: - Data Loading

    /// Loads all data for current selection
    func loadData() {
        isLoading = true

        // Load scores for selected game and date
        loadScores()

        // Load user stats
        userStats = LocalLeaderboardService.shared.getUserStats(for: selectedGameType)

        // Load best score
        bestScore = LocalLeaderboardService.shared.getBestScore(for: selectedGameType)

        // Load user's today score
        userTodayScore = LocalLeaderboardService.shared.getUserScore(for: selectedGameType, date: Date())

        isLoading = false
    }

    /// Loads and sorts scores for the selected game type and date
    private func loadScores() {
        let allScores = LocalLeaderboardService.shared.getScores(for: selectedGameType, date: selectedDate)

        // Sort by ranking (best first)
        scores = allScores.sorted { $0.ranksHigherThan($1) }
    }

    // MARK: - Selection Actions

    /// Selects a game type and reloads data
    func selectGameType(_ gameType: GameType) {
        guard gameType != selectedGameType else { return }
        selectedGameType = gameType
        loadData()
    }

    /// Selects a date and reloads data
    func selectDate(_ date: Date) {
        guard !Calendar.current.isDate(date, inSameDayAs: selectedDate) else { return }
        selectedDate = date
        showingDatePicker = false
        loadData()
    }

    /// Goes to previous day
    func previousDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectDate(newDate)
        }
    }

    /// Goes to next day (but not beyond today)
    func nextDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate),
           newDate <= Date() {
            selectDate(newDate)
        }
    }

    /// Jumps to today
    func goToToday() {
        selectDate(Date())
    }

    /// Whether we can go to next day
    var canGoForward: Bool {
        !isToday
    }

    // MARK: - Helpers

    /// Returns rank for a score (1-indexed)
    func rank(for score: LocalScore) -> Int {
        if let index = scores.firstIndex(where: { $0.id == score.id }) {
            return index + 1
        }
        return 0
    }

    /// Whether a score is the user's score
    func isUserScore(_ score: LocalScore) -> Bool {
        // For now, all local scores are the user's scores
        // When remote sync is added, check against user ID
        return true
    }

    /// Returns medal emoji for top 3 ranks
    func medalEmoji(for rank: Int) -> String? {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }

    // MARK: - Refresh

    /// Refreshes data (for pull-to-refresh)
    func refresh() {
        loadData()
    }
}
