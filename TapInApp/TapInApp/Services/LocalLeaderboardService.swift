//
//  LocalLeaderboardService.swift
//  TapInApp
//
//  MARK: - Local Leaderboard Service
//  Manages local storage of game scores for offline-first leaderboard functionality.
//
//  Architecture:
//  - Singleton pattern (LocalLeaderboardService.shared)
//  - UserDefaults-based persistence with JSON encoding
//  - Organized by game type and date for efficient querying
//
//  Integration Notes:
//  - Call saveScore() from game ViewModels when a game ends
//  - Call getScores() to retrieve scores for display
//  - Call getPendingScores() to get scores that need syncing
//

import Foundation

// MARK: - Local Leaderboard Service

/// Service for managing local storage of game scores.
///
/// Provides functionality for:
/// - Saving scores locally after game completion
/// - Retrieving scores by game type and date
/// - Tracking sync status for offline/online sync
/// - Managing user's score history
///
class LocalLeaderboardService {

    // MARK: - Singleton

    static let shared = LocalLeaderboardService()

    // MARK: - Storage Keys

    private let scoresStorageKey = "localLeaderboardScores"
    private let userStatsStorageKey = "localUserGameStats"

    // MARK: - Properties

    private let defaults = UserDefaults.standard

    // MARK: - Initialization

    private init() {}

    // MARK: - Save Score

    /// Saves a score locally.
    ///
    /// The score is stored with a pending sync status by default.
    /// Call this immediately when a game ends to ensure no data is lost.
    ///
    /// - Parameter score: The LocalScore to save
    /// - Returns: True if saved successfully, false if duplicate exists
    ///
    /// Example:
    /// ```swift
    /// let score = LocalScore(
    ///     gameType: .echo,
    ///     score: 1200,
    ///     date: Date(),
    ///     metadata: .echo(totalScore: 1200, roundScores: [300, 300, 300, 200, 100], ...)
    /// )
    /// LocalLeaderboardService.shared.saveScore(score)
    /// ```
    @discardableResult
    func saveScore(_ score: LocalScore) -> Bool {
        var allScores = loadAllScores()

        // Check if a score already exists for this game/date combination
        let isDuplicate = allScores.contains { existing in
            existing.gameType == score.gameType &&
            existing.dateKey == score.dateKey
        }

        if isDuplicate {
            print("LocalLeaderboardService: Score already exists for \(score.gameType.rawValue) on \(score.dateKey)")
            return false
        }

        allScores.append(score)
        saveAllScores(allScores)

        // Update user stats
        updateUserStats(for: score)

        print("LocalLeaderboardService: Saved \(score.gameType.rawValue) score: \(score.score) for \(score.dateKey)")
        return true
    }

    // MARK: - Update Score

    /// Updates an existing score (e.g., after sync completes).
    ///
    /// - Parameter score: The updated LocalScore
    func updateScore(_ score: LocalScore) {
        var allScores = loadAllScores()

        if let index = allScores.firstIndex(where: { $0.id == score.id }) {
            allScores[index] = score
            saveAllScores(allScores)
            print("LocalLeaderboardService: Updated score \(score.id)")
        }
    }

    /// Marks a score as synced with the remote server.
    ///
    /// - Parameters:
    ///   - scoreId: The local score ID
    ///   - remoteId: The ID assigned by the server
    ///   - username: The username assigned by the server
    func markAsSynced(_ scoreId: UUID, remoteId: String, username: String? = nil) {
        var allScores = loadAllScores()

        if let index = allScores.firstIndex(where: { $0.id == scoreId }) {
            allScores[index].syncStatus = .synced
            allScores[index].remoteId = remoteId
            if let username = username {
                allScores[index].username = username
            }
            saveAllScores(allScores)
            print("LocalLeaderboardService: Marked score \(scoreId) as synced")
        }
    }

    /// Marks a score sync as failed.
    ///
    /// - Parameter scoreId: The local score ID
    func markAsFailed(_ scoreId: UUID) {
        var allScores = loadAllScores()

        if let index = allScores.firstIndex(where: { $0.id == scoreId }) {
            allScores[index].syncStatus = .failed
            saveAllScores(allScores)
            print("LocalLeaderboardService: Marked score \(scoreId) as failed")
        }
    }

    // MARK: - Retrieve Scores

    /// Gets all scores for a specific game type.
    ///
    /// - Parameter gameType: The type of game
    /// - Returns: Array of LocalScore, sorted by date (most recent first)
    func getScores(for gameType: GameType) -> [LocalScore] {
        return loadAllScores()
            .filter { $0.gameType == gameType }
            .sorted { $0.date > $1.date }
    }

    /// Gets scores for a specific game type and date.
    ///
    /// - Parameters:
    ///   - gameType: The type of game
    ///   - date: The date to filter by
    /// - Returns: Array of LocalScore for that game/date
    func getScores(for gameType: GameType, date: Date) -> [LocalScore] {
        let dateKey = LocalScore.formatDateKey(date)
        return loadAllScores()
            .filter { $0.gameType == gameType && $0.dateKey == dateKey }
    }

    /// Gets the user's score for a specific game and date.
    ///
    /// - Parameters:
    ///   - gameType: The type of game
    ///   - date: The date
    /// - Returns: The user's LocalScore if it exists
    func getUserScore(for gameType: GameType, date: Date) -> LocalScore? {
        return getScores(for: gameType, date: date).first
    }

    /// Checks if the user has a score for a specific game and date.
    ///
    /// - Parameters:
    ///   - gameType: The type of game
    ///   - date: The date
    /// - Returns: True if a score exists
    func hasScore(for gameType: GameType, date: Date) -> Bool {
        return getUserScore(for: gameType, date: date) != nil
    }

    /// Gets all scores across all game types.
    ///
    /// - Returns: Array of all LocalScore, sorted by date (most recent first)
    func getAllScores() -> [LocalScore] {
        return loadAllScores().sorted { $0.date > $1.date }
    }

    /// Gets the best score for a specific game type.
    ///
    /// - Parameter gameType: The type of game
    /// - Returns: The highest-ranking LocalScore if any exist
    func getBestScore(for gameType: GameType) -> LocalScore? {
        let scores = getScores(for: gameType)
        guard !scores.isEmpty else { return nil }
        return scores.sorted { $0.ranksHigherThan($1) }.first
    }

    // MARK: - Sync Management

    /// Gets all scores that need to be synced to the server.
    ///
    /// - Returns: Array of LocalScore with pending or failed sync status
    func getPendingScores() -> [LocalScore] {
        return loadAllScores()
            .filter { $0.syncStatus == .pending || $0.syncStatus == .failed }
            .sorted { $0.createdAt < $1.createdAt }  // Oldest first
    }

    /// Checks if there are any scores pending sync.
    ///
    /// - Returns: True if there are pending scores
    var hasPendingScores: Bool {
        return !getPendingScores().isEmpty
    }

    /// Gets the count of pending scores.
    var pendingScoreCount: Int {
        return getPendingScores().count
    }

    // MARK: - User Stats

    /// Gets the user's stats for a specific game type.
    ///
    /// - Parameter gameType: The type of game
    /// - Returns: GameStats for that game type
    func getUserStats(for gameType: GameType) -> GameStats {
        let allStats = loadAllUserStats()
        return allStats[gameType.rawValue] ?? GameStats()
    }

    /// Gets stats for all game types.
    ///
    /// - Returns: Dictionary mapping GameType to GameStats
    func getAllUserStats() -> [GameType: GameStats] {
        let allStats = loadAllUserStats()
        var result: [GameType: GameStats] = [:]
        for gameType in GameType.allCases {
            result[gameType] = allStats[gameType.rawValue] ?? GameStats()
        }
        return result
    }

    // MARK: - Recent Activity

    /// Gets the most recent scores across all games.
    ///
    /// - Parameter limit: Maximum number of scores to return
    /// - Returns: Array of recent LocalScore
    func getRecentScores(limit: Int = 10) -> [LocalScore] {
        return Array(loadAllScores()
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit))
    }

    /// Gets scores from the last N days.
    ///
    /// - Parameters:
    ///   - days: Number of days to look back
    ///   - gameType: Optional filter by game type
    /// - Returns: Array of LocalScore
    func getScoresFromLastDays(_ days: Int, gameType: GameType? = nil) -> [LocalScore] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var scores = loadAllScores().filter { $0.date >= cutoffDate }
        if let gameType = gameType {
            scores = scores.filter { $0.gameType == gameType }
        }
        return scores.sorted { $0.date > $1.date }
    }

    // MARK: - Private Helpers

    private func loadAllScores() -> [LocalScore] {
        guard let data = defaults.data(forKey: scoresStorageKey),
              let scores = try? JSONDecoder().decode([LocalScore].self, from: data) else {
            return []
        }
        return scores
    }

    private func saveAllScores(_ scores: [LocalScore]) {
        if let data = try? JSONEncoder().encode(scores) {
            defaults.set(data, forKey: scoresStorageKey)
        }
    }

    private func loadAllUserStats() -> [String: GameStats] {
        guard let data = defaults.data(forKey: userStatsStorageKey),
              let stats = try? JSONDecoder().decode([String: GameStats].self, from: data) else {
            return [:]
        }
        return stats
    }

    private func saveAllUserStats(_ stats: [String: GameStats]) {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: userStatsStorageKey)
        }
    }

    private func updateUserStats(for score: LocalScore) {
        var allStats = loadAllUserStats()
        var stats = allStats[score.gameType.rawValue] ?? GameStats()

        stats.gamesPlayed += 1
        stats.lastPlayedDate = score.date

        // Calculate streak
        updateStreak(for: &stats, newDate: score.date, gameType: score.gameType)

        // Game-specific win tracking
        switch score.gameType {
        case .wordle:
            if score.score > 0 {  // Won
                stats.wins += 1
            }
        case .echo:
            if let roundsSolved = score.metadata.roundsSolved, roundsSolved == 5 {
                stats.wins += 1
            }
        case .crossword:
            stats.wins += 1  // Completing is a win
        case .trivia:
            if let correct = score.metadata.correctAnswers,
               let total = score.metadata.totalQuestions,
               correct > total / 2 {
                stats.wins += 1
            }
        }

        allStats[score.gameType.rawValue] = stats
        saveAllUserStats(allStats)
    }

    private func updateStreak(for stats: inout GameStats, newDate: Date, gameType: GameType) {
        let calendar = Calendar.current

        if let lastPlayed = stats.lastPlayedDate {
            let daysSinceLastPlay = calendar.dateComponents([.day], from: lastPlayed, to: newDate).day ?? 0

            if daysSinceLastPlay == 1 {
                // Consecutive day - increment streak
                stats.currentStreak += 1
            } else if daysSinceLastPlay > 1 {
                // Missed a day - reset streak
                stats.currentStreak = 1
            }
            // Same day - no change to streak
        } else {
            // First game ever
            stats.currentStreak = 1
        }

        // Update max streak
        stats.maxStreak = max(stats.maxStreak, stats.currentStreak)
    }

    // MARK: - Debug/Testing

    /// Clears all local score data. Use for testing only.
    func clearAllData() {
        defaults.removeObject(forKey: scoresStorageKey)
        defaults.removeObject(forKey: userStatsStorageKey)
        print("LocalLeaderboardService: Cleared all data")
    }

    /// Gets total count of stored scores.
    var totalScoreCount: Int {
        return loadAllScores().count
    }

    /// Prints debug info about stored scores.
    func printDebugInfo() {
        let scores = loadAllScores()
        print("=== LocalLeaderboardService Debug ===")
        print("Total scores: \(scores.count)")
        for gameType in GameType.allCases {
            let gameScores = scores.filter { $0.gameType == gameType }
            print("  \(gameType.rawValue): \(gameScores.count) scores")
        }
        print("Pending sync: \(pendingScoreCount)")
        print("=====================================")
    }
}
