//
//  StoredCrosswordState.swift
//  TapInApp
//
//  MARK: - Model Layer
//  Codable struct for persisting crossword game state.
//

import Foundation

/// Persisted state for a crossword game
struct StoredCrosswordState: Codable {
    let dateKey: String
    let puzzleID: UUID
    let letters: [[String?]]
    let gameState: String
    let elapsedSeconds: Int

    init(
        dateKey: String,
        puzzleID: UUID,
        letters: [[Character?]],
        gameState: CrosswordGameState,
        elapsedSeconds: Int
    ) {
        self.dateKey = dateKey
        self.puzzleID = puzzleID
        self.letters = letters.map { row in
            row.map { char in
                char.map { String($0) }
            }
        }
        self.gameState = gameState.rawValue
        self.elapsedSeconds = elapsedSeconds
    }

    /// Converts stored letters back to Character array
    var lettersAsCharacters: [[Character?]] {
        letters.map { row in
            row.map { str in
                str?.first
            }
        }
    }

    /// Whether the puzzle is completed
    var isCompleted: Bool {
        gameState == CrosswordGameState.completed.rawValue
    }
}
