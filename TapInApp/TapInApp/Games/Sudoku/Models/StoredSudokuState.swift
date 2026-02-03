//
//  StoredSudokuState.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  Codable struct for persisting Sudoku game state.
//

import Foundation

/// Codable struct for persisting Sudoku game state to UserDefaults.
struct StoredSudokuState: Codable {
    /// User's current values (9x9 grid, 0 for empty)
    let userValues: [[Int]]

    /// Notes for each cell (9x9 grid of arrays)
    let notes: [[[Int]]]

    /// Original puzzle (given cells, 0 for empty)
    let puzzle: [[Int]]

    /// Complete solution
    let solution: [[Int]]

    /// Game state string ("playing", "won", "paused")
    let gameState: String

    /// Difficulty level
    let difficulty: String

    /// Elapsed time in seconds
    let elapsedSeconds: Int

    /// Date key (yyyy-MM-dd format)
    let dateKey: String

    /// Number of errors made
    let errorCount: Int

    /// Whether the game is completed
    var isCompleted: Bool {
        gameState == "won"
    }
}
