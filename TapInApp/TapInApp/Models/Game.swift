//
//  Game.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - Game Models
//  Data models for games, stats, and leaderboard entries.
//  All models are Codable for API serialization.
//

import Foundation

// MARK: - Game Type
/// Identifies each game type for leaderboards and analytics.
/// Add new cases here when adding new games.
enum GameType: String, Codable, CaseIterable {
    case wordle = "wordle"
    case trivia = "trivia"
    case crossword = "crossword"
    case echo = "echo"

    var displayName: String {
        switch self {
        case .wordle: return "Aggie Wordle"
        case .trivia: return "Campus Trivia"
        case .crossword: return "Aggie Crossword"
        case .echo: return "Echo"
        }
    }
}

// MARK: - Game
/// Represents a playable game in the app.
struct Game: Identifiable, Codable {
    let id: UUID
    let type: GameType
    let name: String
    let description: String
    let iconName: String
    let isMultiplayer: Bool
    let hasLeaderboard: Bool

    init(
        id: UUID = UUID(),
        type: GameType,
        name: String,
        description: String,
        iconName: String,
        isMultiplayer: Bool = false,
        hasLeaderboard: Bool = true
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.iconName = iconName
        self.isMultiplayer = isMultiplayer
        self.hasLeaderboard = hasLeaderboard
    }
}

// MARK: - Game Stats
/// User statistics for a specific game.
struct GameStats: Codable {
    var gamesPlayed: Int
    var currentStreak: Int
    var maxStreak: Int
    var wins: Int
    var lastPlayedDate: Date?

    init(
        gamesPlayed: Int = 0,
        currentStreak: Int = 0,
        maxStreak: Int = 0,
        wins: Int = 0,
        lastPlayedDate: Date? = nil
    ) {
        self.gamesPlayed = gamesPlayed
        self.currentStreak = currentStreak
        self.maxStreak = maxStreak
        self.wins = wins
        self.lastPlayedDate = lastPlayedDate
    }

    /// Win percentage (0-100)
    var winPercentage: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(wins) / Double(gamesPlayed) * 100
    }
}

// MARK: - Leaderboard Entry
/// A single entry in a game leaderboard.
struct LeaderboardEntry: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let userName: String
    let gameType: GameType
    let score: Int
    let rank: Int
    let date: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        userName: String,
        gameType: GameType,
        score: Int,
        rank: Int = 0,
        date: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.gameType = gameType
        self.score = score
        self.rank = rank
        self.date = date
    }
}

// MARK: - Score Submission
/// Used when submitting a score to the leaderboard.
struct ScoreSubmission: Codable {
    let gameType: GameType
    let score: Int
    let date: Date
    let metadata: [String: String]?

    init(gameType: GameType, score: Int, date: Date = Date(), metadata: [String: String]? = nil) {
        self.gameType = gameType
        self.score = score
        self.date = date
        self.metadata = metadata
    }
}

// MARK: - Sample Data
extension Game {
    static let sampleData: [Game] = [
        Game(
            type: .wordle,
            name: "Aggie Wordle",
            description: "UC Davis themed daily word puzzle",
            iconName: "puzzlepiece.extension.fill",
            isMultiplayer: false,
            hasLeaderboard: true
        ),
        Game(
            type: .trivia,
            name: "Campus Trivia",
            description: "Test your Davis knowledge with friends",
            iconName: "questionmark.circle.fill",
            isMultiplayer: true,
            hasLeaderboard: true
        ),
        Game(
            type: .crossword,
            name: "Aggie Crossword",
            description: "Weekly campus-themed crossword",
            iconName: "square.grid.3x3.fill",
            isMultiplayer: false,
            hasLeaderboard: true
        ),
        Game(
            type: .echo,
            name: "Echo",
            description: "Memory meets logic — transform the sequence",
            iconName: "waveform.path",
            isMultiplayer: false,
            hasLeaderboard: true
        )
    ]
}

extension LeaderboardEntry {
    static let sampleData: [LeaderboardEntry] = [
        LeaderboardEntry(
            userId: UUID(),
            userName: "AggieChamp",
            gameType: .wordle,
            score: 1250,
            rank: 1
        ),
        LeaderboardEntry(
            userId: UUID(),
            userName: "DavisStudent",
            gameType: .wordle,
            score: 1180,
            rank: 2
        ),
        LeaderboardEntry(
            userId: UUID(),
            userName: "MustangFan",
            gameType: .wordle,
            score: 1050,
            rank: 3
        )
    ]
}
