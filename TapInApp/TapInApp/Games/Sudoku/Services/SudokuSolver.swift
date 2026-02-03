//
//  SudokuSolver.swift
//  TapInApp
//
//  MARK: - Service Layer (MVVM)
//  Backtracking solver for Sudoku validation and solving.
//

import Foundation

/// Sudoku solver using backtracking algorithm.
struct SudokuSolver {

    /// Solve a puzzle and return the solution (or nil if unsolvable)
    static func solve(_ puzzle: [[Int]]) -> [[Int]]? {
        var board = puzzle
        if solveBacktrack(&board) {
            return board
        }
        return nil
    }

    /// Check if a puzzle has exactly one unique solution
    static func hasUniqueSolution(_ puzzle: [[Int]]) -> Bool {
        var board = puzzle
        var count = 0
        countSolutions(&board, count: &count, limit: 2)
        return count == 1
    }

    /// Validate if a completed board is a valid Sudoku solution
    static func isValidSolution(_ board: [[Int]]) -> Bool {
        // Check all rows
        for row in 0..<9 {
            if !isValidGroup(board[row]) { return false }
        }

        // Check all columns
        for col in 0..<9 {
            let column = (0..<9).map { board[$0][col] }
            if !isValidGroup(column) { return false }
        }

        // Check all 3x3 boxes
        for boxRow in 0..<3 {
            for boxCol in 0..<3 {
                var box: [Int] = []
                for r in 0..<3 {
                    for c in 0..<3 {
                        box.append(board[boxRow * 3 + r][boxCol * 3 + c])
                    }
                }
                if !isValidGroup(box) { return false }
            }
        }

        return true
    }

    /// Check if placing num at (row, col) is valid
    static func isValid(_ board: [[Int]], num: Int, row: Int, col: Int) -> Bool {
        // Check row
        if board[row].contains(num) { return false }

        // Check column
        for r in 0..<9 {
            if board[r][col] == num { return false }
        }

        // Check 3x3 box
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        for r in boxRow..<boxRow+3 {
            for c in boxCol..<boxCol+3 {
                if board[r][c] == num { return false }
            }
        }

        return true
    }

    // MARK: - Private Methods

    /// Backtracking solver
    private static func solveBacktrack(_ board: inout [[Int]]) -> Bool {
        guard let (row, col) = findEmpty(board) else {
            return true // Board is complete
        }

        for num in 1...9 {
            if isValid(board, num: num, row: row, col: col) {
                board[row][col] = num
                if solveBacktrack(&board) {
                    return true
                }
                board[row][col] = 0
            }
        }

        return false
    }

    /// Count solutions up to a limit
    private static func countSolutions(_ board: inout [[Int]], count: inout Int, limit: Int) {
        guard count < limit else { return }

        guard let (row, col) = findEmpty(board) else {
            count += 1
            return
        }

        for num in 1...9 {
            if isValid(board, num: num, row: row, col: col) {
                board[row][col] = num
                countSolutions(&board, count: &count, limit: limit)
                board[row][col] = 0
            }
        }
    }

    /// Find the first empty cell (value == 0)
    private static func findEmpty(_ board: [[Int]]) -> (Int, Int)? {
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row][col] == 0 {
                    return (row, col)
                }
            }
        }
        return nil
    }

    /// Check if a group (row/col/box) contains all numbers 1-9 exactly once
    private static func isValidGroup(_ group: [Int]) -> Bool {
        let filtered = group.filter { $0 != 0 }
        return filtered.count == 9 && Set(filtered) == Set(1...9)
    }
}
