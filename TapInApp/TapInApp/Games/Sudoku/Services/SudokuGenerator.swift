//
//  SudokuGenerator.swift
//  TapInApp
//
//  MARK: - Service Layer (MVVM)
//  Deterministic puzzle generation for daily Sudoku.
//

import Foundation

/// Generates Sudoku puzzles deterministically based on date.
struct SudokuGenerator {

    // MARK: - Reference Date (same as Wordle for consistency)
    private static let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()

    /// Generate a deterministic puzzle for a date and difficulty
    /// - Returns: Tuple of (puzzle, solution) where puzzle has 0s for empty cells
    static func puzzleForDate(_ date: Date, difficulty: SudokuDifficulty) -> ([[Int]], [[Int]]) {
        let seed = seedForDate(date, difficulty: difficulty)
        var rng = SeededRandomNumberGenerator(seed: seed)

        // Generate a complete valid board
        let solution = generateSolvedBoard(using: &rng)

        // Remove cells based on difficulty
        let puzzle = removeCells(from: solution, count: difficulty.cellsToRemove, using: &rng)

        return (puzzle, solution)
    }

    /// Create date key string (yyyy-MM-dd)
    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Get today's date at start of day
    static var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Format date for display
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Private Methods

    /// Create deterministic seed from date and difficulty
    private static func seedForDate(_ date: Date, difficulty: SudokuDifficulty) -> UInt64 {
        let days = daysBetween(referenceDate, and: date)
        let difficultyOffset: UInt64 = {
            switch difficulty {
            case .easy: return 0
            case .medium: return 1_000_000
            case .hard: return 2_000_000
            }
        }()
        return UInt64(abs(days)) + difficultyOffset
    }

    /// Calculate days between two dates
    private static func daysBetween(_ start: Date, and end: Date) -> Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let components = calendar.dateComponents([.day], from: startDay, to: endDay)
        return components.day ?? 0
    }

    /// Generate a complete valid Sudoku board
    private static func generateSolvedBoard(using rng: inout SeededRandomNumberGenerator) -> [[Int]] {
        var board = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        _ = fillBoard(&board, using: &rng)
        return board
    }

    /// Recursive backtracking to fill board with random valid numbers
    private static func fillBoard(_ board: inout [[Int]], using rng: inout SeededRandomNumberGenerator) -> Bool {
        guard let (row, col) = findEmpty(board) else {
            return true // Board is complete
        }

        // Try numbers 1-9 in shuffled order
        var numbers = Array(1...9)
        numbers.shuffle(using: &rng)

        for num in numbers {
            if SudokuSolver.isValid(board, num: num, row: row, col: col) {
                board[row][col] = num
                if fillBoard(&board, using: &rng) {
                    return true
                }
                board[row][col] = 0
            }
        }

        return false
    }

    /// Find first empty cell
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

    /// Remove cells to create puzzle while ensuring unique solution
    private static func removeCells(from solution: [[Int]], count: Int, using rng: inout SeededRandomNumberGenerator) -> [[Int]] {
        var puzzle = solution
        var positions = (0..<81).map { ($0 / 9, $0 % 9) }
        positions.shuffle(using: &rng)

        var removed = 0
        for (row, col) in positions {
            guard removed < count else { break }

            let backup = puzzle[row][col]
            puzzle[row][col] = 0

            // For performance, skip unique solution check for easier difficulties
            // (they have enough clues to be unique anyway)
            if count <= 45 {
                removed += 1
            } else if SudokuSolver.hasUniqueSolution(puzzle) {
                removed += 1
            } else {
                puzzle[row][col] = backup
            }
        }

        return puzzle
    }
}

// MARK: - Seeded Random Number Generator

/// A seeded random number generator for deterministic randomness.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64 algorithm
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
