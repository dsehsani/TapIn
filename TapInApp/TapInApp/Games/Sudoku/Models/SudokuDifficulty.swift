//
//  SudokuDifficulty.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  Difficulty levels for Sudoku puzzles.
//

import Foundation

/// Difficulty levels for Sudoku puzzles.
enum SudokuDifficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"

    /// Display name for UI
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    /// Number of cells to remove from a complete board
    var cellsToRemove: Int {
        switch self {
        case .easy: return 35      // ~46 clues remaining
        case .medium: return 45    // ~36 clues remaining
        case .hard: return 54      // ~27 clues remaining
        }
    }

    /// Description for difficulty picker
    var description: String {
        switch self {
        case .easy: return "~46 clues, perfect for beginners"
        case .medium: return "~36 clues, balanced challenge"
        case .hard: return "~27 clues, for experts"
        }
    }
}
