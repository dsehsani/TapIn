//
//  SudokuGameState.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  This enum represents the overall state of a Sudoku game session.
//

import Foundation

/// Represents the current state of a Sudoku game session.
enum SudokuGameState: String, Codable {
    /// Game is in progress, player can make moves
    case playing

    /// Player successfully completed the puzzle
    case won

    /// Game is paused (app backgrounded)
    case paused
}
