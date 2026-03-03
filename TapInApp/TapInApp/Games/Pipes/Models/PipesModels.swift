//
//  PipesModels.swift
//  TapInApp
//

import SwiftUI

// MARK: - Position

struct PipePosition: Equatable, Hashable, Codable {
    let row: Int
    let col: Int
}

// MARK: - Pipe Color

enum PipeColor: String, CaseIterable, Hashable, Codable {
    case red, blue, green, yellow, orange, purple

    var displayColor: Color {
        switch self {
        case .red: return Color(red: 0.94, green: 0.27, blue: 0.27)
        case .blue: return Color(red: 0.23, green: 0.51, blue: 0.96)
        case .green: return Color(red: 0.13, green: 0.77, blue: 0.37)
        case .yellow: return Color(red: 0.92, green: 0.70, blue: 0.05)
        case .orange: return Color(red: 0.98, green: 0.45, blue: 0.09)
        case .purple: return Color(red: 0.66, green: 0.33, blue: 0.97)
        }
    }
}

// MARK: - Puzzle Definition

struct PipeEndpointPair: Codable {
    let color: PipeColor
    let start: PipePosition
    let end: PipePosition
}

struct PipePuzzle: Codable {
    let size: Int
    let pairs: [PipeEndpointPair]
}

// MARK: - Game State

enum PipesGameState {
    case playing
    case solved
}

// MARK: - Puzzle Status (Daily Five)

enum PipesPuzzleStatus: String, Codable {
    case locked
    case available
    case inProgress
    case completed
}

// MARK: - Stored Puzzle State (per puzzle within a day)

struct PipesStoredPuzzleState: Codable {
    let puzzleIndex: Int
    let dateKey: String
    var status: PipesPuzzleStatus
    /// Serialized paths using String keys for reliable JSON encoding
    var storedPaths: [String: [PipePosition]]
    var moves: Int
    var timeSeconds: Int

    /// Convenience: get/set paths using PipeColor keys
    var paths: [PipeColor: [PipePosition]] {
        get {
            var result: [PipeColor: [PipePosition]] = [:]
            for (key, value) in storedPaths {
                if let color = PipeColor(rawValue: key) {
                    result[color] = value
                }
            }
            return result
        }
        set {
            storedPaths = [:]
            for (color, positions) in newValue {
                storedPaths[color.rawValue] = positions
            }
        }
    }

    init(puzzleIndex: Int, dateKey: String, status: PipesPuzzleStatus,
         paths: [PipeColor: [PipePosition]], moves: Int, timeSeconds: Int) {
        self.puzzleIndex = puzzleIndex
        self.dateKey = dateKey
        self.status = status
        self.storedPaths = [:]
        for (color, positions) in paths {
            self.storedPaths[color.rawValue] = positions
        }
        self.moves = moves
        self.timeSeconds = timeSeconds
    }
}

// MARK: - Daily State (all 5 puzzles for a day)

struct PipesDailyState: Codable {
    let dateKey: String
    var puzzleStates: [PipesStoredPuzzleState]

    var completedCount: Int {
        puzzleStates.filter { $0.status == .completed }.count
    }

    var isAllComplete: Bool {
        completedCount == puzzleStates.count
    }
}

// MARK: - Day Status (for archive calendar)

enum PipesDayStatus: String, Codable {
    case allComplete
    case partial
    case notPlayed
}
