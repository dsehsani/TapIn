//
//  SudokuCellState.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  This enum represents the visual state of a cell in the Sudoku grid.
//

import SwiftUI

/// Represents the visual state of a Sudoku cell.
enum SudokuCellState {
    /// Pre-filled cell that cannot be modified
    case given

    /// Empty cell that user can fill
    case empty

    /// Cell filled by user
    case userFilled

    /// Currently selected cell
    case selected

    /// Cell in same row, column, or box as selected
    case highlighted

    /// Cell contains same number as selected cell
    case sameNumber

    /// Cell has a conflict (same number in row/col/box)
    case error

    // MARK: - Visual Properties

    /// Returns the background color for this state.
    func backgroundColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .given:
            return colorScheme == .dark ? Color(hex: "#2a2a3e") : Color(hex: "#e8e8e8")
        case .empty, .userFilled:
            return colorScheme == .dark ? Color(hex: "#1a1a2e") : .white
        case .selected:
            return Color.ucdGold.opacity(0.4)
        case .highlighted:
            return colorScheme == .dark ? Color.ucdBlue.opacity(0.2) : Color.ucdBlue.opacity(0.1)
        case .sameNumber:
            return Color.ucdGold.opacity(0.25)
        case .error:
            return Color.red.opacity(0.3)
        }
    }
}
