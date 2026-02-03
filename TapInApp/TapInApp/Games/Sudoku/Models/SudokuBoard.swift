//
//  SudokuBoard.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  Represents the 9x9 Sudoku board with validation logic.
//

import Foundation

/// Represents a 9x9 Sudoku board.
struct SudokuBoard {
    /// 9x9 grid of cells
    var cells: [[SudokuCell]]

    /// Initialize an empty board
    init() {
        cells = (0..<9).map { row in
            (0..<9).map { col in
                SudokuCell(row: row, col: col, solution: 0, isGiven: false)
            }
        }
    }

    /// Initialize with puzzle and solution arrays
    /// - Parameters:
    ///   - puzzle: 9x9 array where 0 means empty cell
    ///   - solution: 9x9 array with complete solution
    init(puzzle: [[Int]], solution: [[Int]]) {
        cells = (0..<9).map { row in
            (0..<9).map { col in
                let puzzleValue = puzzle[row][col]
                let solutionValue = solution[row][col]
                let isGiven = puzzleValue != 0
                return SudokuCell(
                    row: row,
                    col: col,
                    value: isGiven ? puzzleValue : nil,
                    solution: solutionValue,
                    isGiven: isGiven
                )
            }
        }
    }

    /// Subscript for easy access: board[row, col]
    subscript(row: Int, col: Int) -> SudokuCell {
        get { cells[row][col] }
        set { cells[row][col] = newValue }
    }

    /// Get all cells in a row
    func row(_ index: Int) -> [SudokuCell] {
        cells[index]
    }

    /// Get all cells in a column
    func column(_ index: Int) -> [SudokuCell] {
        cells.map { $0[index] }
    }

    /// Get all cells in a 3x3 box (0-8)
    func box(_ index: Int) -> [SudokuCell] {
        let startRow = (index / 3) * 3
        let startCol = (index % 3) * 3
        var boxCells: [SudokuCell] = []
        for r in startRow..<startRow+3 {
            for c in startCol..<startCol+3 {
                boxCells.append(cells[r][c])
            }
        }
        return boxCells
    }

    /// Check if placing a value at position would be valid (no conflicts)
    func isValidPlacement(_ value: Int, at row: Int, col: Int) -> Bool {
        // Check row
        for c in 0..<9 where c != col {
            if cells[row][c].value == value { return false }
        }

        // Check column
        for r in 0..<9 where r != row {
            if cells[r][col].value == value { return false }
        }

        // Check 3x3 box
        let boxStartRow = (row / 3) * 3
        let boxStartCol = (col / 3) * 3
        for r in boxStartRow..<boxStartRow+3 {
            for c in boxStartCol..<boxStartCol+3 {
                if r != row || c != col {
                    if cells[r][c].value == value { return false }
                }
            }
        }

        return true
    }

    /// Check if the entire board is correctly solved
    var isSolved: Bool {
        for row in cells {
            for cell in row {
                guard let value = cell.value else { return false }
                if value != cell.solution { return false }
            }
        }
        return true
    }

    /// Count of filled cells
    var filledCount: Int {
        cells.flatMap { $0 }.filter { $0.value != nil }.count
    }

    /// Progress as percentage (0.0 to 1.0)
    var progress: Double {
        Double(filledCount) / 81.0
    }
}
