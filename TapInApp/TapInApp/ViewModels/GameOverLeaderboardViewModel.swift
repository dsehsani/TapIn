//
//  GameOverLeaderboardViewModel.swift
//  TapInApp
//
//  MARK: - Game Over Leaderboard ViewModel
//  Manages state for the leaderboard shown after game completion.
//

import Foundation
import SwiftUI

/// ViewModel for the game over leaderboard overlay.
///
/// Displays:
/// - Top 5 scores for today
/// - User's display name
/// - User's rank (shown as 6th entry if not in top 5)
///
@Observable
class GameOverLeaderboardViewModel {

    // MARK: - Properties

    /// The game type being displayed
    let gameType: GameType

    /// The date of the game
    let gameDate: Date

    /// The user's score from this game
    let userScore: LocalScore?

    /// Top 5 scores for display
    var topScores: [LocalScore] = []

    /// User's score if not in top 5 (for 6th row display)
    var userScoreIfNotInTop: LocalScore? = nil

    /// User's rank (1-based)
    var userRank: Int? = nil

    /// User's display name
    var displayName: String = ""

    /// Total number of players
    var totalPlayers: Int = 0

    /// Whether data is loading
    var isLoading: Bool = true

    // MARK: - Computed Properties

    /// Whether the user is in the top 5
    var isUserInTop5: Bool {
        guard let rank = userRank else { return false }
        return rank <= 5
    }

    /// Display string for user's rank
    var userRankDisplay: String {
        guard let rank = userRank else { return "" }
        return "#\(rank)"
    }

    /// Game type display name
    var gameDisplayName: String {
        switch gameType {
        case .wordle: return "Aggie Wordle"
        case .echo: return "Echo"
        case .crossword: return "Mini Crossword"
        case .trivia: return "Trivia"
        }
    }

    // MARK: - Initialization

    init(gameType: GameType, gameDate: Date = Date(), userScore: LocalScore? = nil) {
        self.gameType = gameType
        self.gameDate = gameDate
        self.userScore = userScore
        loadData()
    }

    // MARK: - Methods

    /// Loads leaderboard data from local storage
    func loadData() {
        isLoading = true

        // Get display name
        displayName = UsernameGenerator.shared.getDisplayName(for: gameDate)

        // Get leaderboard data
        let data = LocalLeaderboardService.shared.getLeaderboardData(
            for: gameType,
            date: gameDate,
            limit: 5
        )

        topScores = data.topScores
        userScoreIfNotInTop = data.userScoreIfNotInTop
        userRank = data.userRank
        totalPlayers = LocalLeaderboardService.shared.getScores(for: gameType, date: gameDate).count

        isLoading = false
    }

    /// Returns the rank for a given score in the top scores list
    func rank(for score: LocalScore) -> Int {
        if let index = topScores.firstIndex(where: { $0.id == score.id }) {
            return index + 1
        }
        return userRank ?? 0
    }

    /// Checks if a score belongs to the current user
    func isUserScore(_ score: LocalScore) -> Bool {
        return score.id == userScore?.id
    }
}
