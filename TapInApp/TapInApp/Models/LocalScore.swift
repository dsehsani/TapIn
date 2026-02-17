//
//  LocalScore.swift
//  TapInApp
//
//  MARK: - Local Score Model
//  Represents a score stored locally on the device.
//  Supports offline-first architecture with sync status tracking.
//

import Foundation

// MARK: - Sync Status

/// Tracks the synchronization state of a local score with the remote server.
enum SyncStatus: String, Codable {
    case pending    // Not yet synced to server
    case synced     // Successfully synced
    case failed     // Sync attempted but failed, will retry
}

// MARK: - Game Metadata

/// Game-specific metadata for different game types.
/// Each game stores its own relevant data here.
struct GameMetadata: Codable, Equatable {
    // Wordle-specific
    var guesses: Int?           // Number of guesses (1-6)
    var timeSeconds: Int?       // Time taken in seconds

    // Echo-specific
    var totalScore: Int?        // Total score (0-1500)
    var roundScores: [Int]?     // Score per round
    var perfectRounds: Int?     // Rounds solved on first attempt
    var totalAttempts: Int?     // Total attempts used
    var roundsSolved: Int?      // Number of rounds solved

    // Crossword-specific
    var completionTimeSeconds: Int?  // Time to complete
    var hintsUsed: Int?              // Number of hints used (for display only)

    // Trivia-specific (for future)
    var correctAnswers: Int?
    var totalQuestions: Int?

    init() {}

    // MARK: - Convenience Initializers

    /// Creates metadata for a Wordle game
    static func wordle(guesses: Int, timeSeconds: Int) -> GameMetadata {
        var metadata = GameMetadata()
        metadata.guesses = guesses
        metadata.timeSeconds = timeSeconds
        return metadata
    }

    /// Creates metadata for an Echo game
    static func echo(
        totalScore: Int,
        roundScores: [Int],
        perfectRounds: Int,
        totalAttempts: Int,
        roundsSolved: Int
    ) -> GameMetadata {
        var metadata = GameMetadata()
        metadata.totalScore = totalScore
        metadata.roundScores = roundScores
        metadata.perfectRounds = perfectRounds
        metadata.totalAttempts = totalAttempts
        metadata.roundsSolved = roundsSolved
        return metadata
    }

    /// Creates metadata for a Crossword game
    /// Note: hintsUsed is stored for reference but doesn't affect ranking
    static func crossword(completionTimeSeconds: Int, hintsUsed: Int? = nil) -> GameMetadata {
        var metadata = GameMetadata()
        metadata.completionTimeSeconds = completionTimeSeconds
        metadata.hintsUsed = hintsUsed
        return metadata
    }

    /// Creates metadata for a Trivia game (future)
    static func trivia(correctAnswers: Int, totalQuestions: Int) -> GameMetadata {
        var metadata = GameMetadata()
        metadata.correctAnswers = correctAnswers
        metadata.totalQuestions = totalQuestions
        return metadata
    }
}

// MARK: - Local Score

/// A score stored locally on the device.
///
/// This model supports:
/// - Offline storage and retrieval
/// - Sync status tracking for eventual consistency
/// - Game-specific metadata for different game types
/// - Date-based organization for daily leaderboards
///
struct LocalScore: Identifiable, Codable, Equatable {
    let id: UUID
    let gameType: GameType
    let score: Int                      // Computed/display score
    let date: Date                      // Game/puzzle date (not submission time)
    let metadata: GameMetadata          // Game-specific data
    let createdAt: Date                 // When this score was created locally
    var syncStatus: SyncStatus          // Sync state with server
    var remoteId: String?               // Server-assigned ID after sync
    var username: String?               // Username (assigned by server or generated)

    init(
        id: UUID = UUID(),
        gameType: GameType,
        score: Int,
        date: Date,
        metadata: GameMetadata,
        createdAt: Date = Date(),
        syncStatus: SyncStatus = .pending,
        remoteId: String? = nil,
        username: String? = nil
    ) {
        self.id = id
        self.gameType = gameType
        self.score = score
        self.date = date
        self.metadata = metadata
        self.createdAt = createdAt
        self.syncStatus = syncStatus
        self.remoteId = remoteId
        self.username = username
    }

    // MARK: - Date Key

    /// Returns the date formatted as a string key (yyyy-MM-dd)
    var dateKey: String {
        Self.formatDateKey(date)
    }

    /// Formats a date as a string key
    static func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Display Helpers

    /// Returns a display string for the score based on game type
    var scoreDisplay: String {
        switch gameType {
        case .wordle:
            if let guesses = metadata.guesses {
                return "\(guesses)/6"
            }
            return "\(score)"
        case .echo:
            return "\(score) pts"
        case .crossword:
            if let time = metadata.completionTimeSeconds {
                let minutes = time / 60
                let seconds = time % 60
                return String(format: "%d:%02d", minutes, seconds)
            }
            return "\(score)"
        case .trivia:
            if let correct = metadata.correctAnswers, let total = metadata.totalQuestions {
                return "\(correct)/\(total)"
            }
            return "\(score)"
        }
    }

    /// Returns a secondary display string (e.g., time for Wordle)
    var secondaryDisplay: String? {
        switch gameType {
        case .wordle:
            if let time = metadata.timeSeconds {
                let minutes = time / 60
                let seconds = time % 60
                return String(format: "%d:%02d", minutes, seconds)
            }
        case .echo:
            if let rounds = metadata.roundsSolved {
                return "\(rounds)/5 rounds"
            }
        case .crossword:
            return nil  // Time is the primary display
        case .trivia:
            return nil
        }
        return nil
    }
}

// MARK: - Score Calculation Helpers

extension LocalScore {

    /// Calculates a normalized score for Wordle (for ranking purposes)
    /// Lower guesses = higher score, faster time = tiebreaker
    static func calculateWordleScore(guesses: Int, timeSeconds: Int) -> Int {
        let baseScore = (7 - guesses) * 100  // 600 for 1 guess, 100 for 6 guesses
        let timeBonus = max(0, 300 - timeSeconds)  // Up to 300 bonus for speed
        return baseScore + timeBonus
    }

    /// Calculates score for Echo (already computed in game)
    static func calculateEchoScore(roundScores: [Int]) -> Int {
        return roundScores.reduce(0, +)
    }

    /// Calculates score for Crossword (time-based only, lower time = higher score)
    /// Note: Hints do NOT affect score (confirmed decision)
    static func calculateCrosswordScore(completionTimeSeconds: Int) -> Int {
        // Invert time so higher score = better (for consistent ranking)
        // Max score 3600 for instant completion, 0 for 1 hour+
        return max(0, 3600 - completionTimeSeconds)
    }

    /// Calculates score for Trivia (future)
    static func calculateTriviaScore(correctAnswers: Int, totalQuestions: Int, timeSeconds: Int) -> Int {
        let baseScore = correctAnswers * 100
        let timeBonus = max(0, 60 - (timeSeconds / totalQuestions))
        return baseScore + timeBonus
    }
}

// MARK: - Sorting Helpers

extension LocalScore {

    /// Compares two scores for ranking (higher rank = better)
    /// Returns true if self should rank higher than other
    func ranksHigherThan(_ other: LocalScore) -> Bool {
        guard gameType == other.gameType else { return false }

        switch gameType {
        case .wordle:
            // Fewer guesses = better, then faster time = better
            let selfGuesses = metadata.guesses ?? Int.max
            let otherGuesses = other.metadata.guesses ?? Int.max
            if selfGuesses != otherGuesses {
                return selfGuesses < otherGuesses
            }
            let selfTime = metadata.timeSeconds ?? Int.max
            let otherTime = other.metadata.timeSeconds ?? Int.max
            return selfTime < otherTime

        case .echo:
            // Higher score = better
            return score > other.score

        case .crossword:
            // Faster time = better
            let selfTime = metadata.completionTimeSeconds ?? Int.max
            let otherTime = other.metadata.completionTimeSeconds ?? Int.max
            return selfTime < otherTime

        case .trivia:
            // Higher score = better
            return score > other.score
        }
    }
}
