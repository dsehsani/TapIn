//
//  SudokuCell.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  Represents a single cell in the Sudoku grid.
//

import Foundation

/// Represents a single cell in the Sudoku grid.
struct SudokuCell: Identifiable {
    let id = UUID()

    /// Row index (0-8)
    let row: Int

    /// Column index (0-8)
    let col: Int

    /// Current value (1-9, or nil if empty)
    var value: Int?

    /// The correct solution value
    let solution: Int

    /// Whether this is a given (pre-filled) cell
    let isGiven: Bool

    /// Pencil marks / notes (possible values 1-9)
    var notes: Set<Int> = []

    /// Current visual state
    var state: SudokuCellState = .empty

    /// Animation state for error shake
    var isShowingError: Bool = false

    /// Whether the current value matches the solution
    var isCorrect: Bool {
        value == solution
    }

    /// 3x3 box index (0-8), calculated as (row/3)*3 + (col/3)
    var boxIndex: Int {
        (row / 3) * 3 + (col / 3)
    }

    /// Initialize a cell
    init(row: Int, col: Int, value: Int? = nil, solution: Int, isGiven: Bool) {
        self.row = row
        self.col = col
        self.value = value
        self.solution = solution
        self.isGiven = isGiven
        self.state = isGiven ? .given : .empty
    }
}
