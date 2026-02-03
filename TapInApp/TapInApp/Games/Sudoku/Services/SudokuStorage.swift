//
//  SudokuStorage.swift
//  TapInApp
//
//  MARK: - Service Layer (MVVM)
//  Persistence manager for Sudoku game state.
//

import Foundation

/// Manages persistence of Sudoku game state via UserDefaults.
class SudokuStorage {

    // MARK: - Singleton
    static let shared = SudokuStorage()

    // MARK: - Properties
    private let defaults = UserDefaults.standard
    private let storageKey = "sudokuGameStates"

    private init() {}

    // MARK: - Save Methods

    /// Save current game state
    func saveGameState(
        for date: Date,
        difficulty: SudokuDifficulty,
        board: SudokuBoard,
        gameState: SudokuGameState,
        elapsedSeconds: Int,
        errorCount: Int
    ) {
        let key = makeKey(date: date, difficulty: difficulty)

        // Extract user values (0 for empty)
        let userValues = board.cells.map { row in
            row.map { $0.value ?? 0 }
        }

        // Extract notes
        let notes = board.cells.map { row in
            row.map { Array($0.notes).sorted() }
        }

        // Extract original puzzle
        let puzzle = board.cells.map { row in
            row.map { $0.isGiven ? $0.solution : 0 }
        }

        // Extract solution
        let solution = board.cells.map { row in
            row.map { $0.solution }
        }

        let stored = StoredSudokuState(
            userValues: userValues,
            notes: notes,
            puzzle: puzzle,
            solution: solution,
            gameState: gameState.rawValue,
            difficulty: difficulty.rawValue,
            elapsedSeconds: elapsedSeconds,
            dateKey: key,
            errorCount: errorCount
        )

        var allStates = loadAllStates()
        allStates[key] = stored
        saveAllStates(allStates)
    }

    // MARK: - Load Methods

    /// Load game state for a specific date and difficulty
    func loadGameState(for date: Date, difficulty: SudokuDifficulty) -> StoredSudokuState? {
        let key = makeKey(date: date, difficulty: difficulty)
        return loadAllStates()[key]
    }

    // MARK: - Query Methods

    /// Check if a date has been played at a difficulty
    func hasPlayedDate(_ date: Date, difficulty: SudokuDifficulty) -> Bool {
        loadGameState(for: date, difficulty: difficulty) != nil
    }

    /// Check if a date is completed at a difficulty
    func isDateCompleted(_ date: Date, difficulty: SudokuDifficulty) -> Bool {
        loadGameState(for: date, difficulty: difficulty)?.isCompleted ?? false
    }

    /// Get all played dates for a difficulty
    func getAllPlayedDates(difficulty: SudokuDifficulty) -> [Date] {
        let states = loadAllStates()
        let suffix = "_\(difficulty.rawValue)"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return states.keys
            .filter { $0.hasSuffix(suffix) }
            .compactMap { key -> Date? in
                let dateString = String(key.dropLast(suffix.count))
                return formatter.date(from: dateString)
            }
            .sorted()
    }

    /// Get completed dates with stats
    func getCompletedDatesWithStats(difficulty: SudokuDifficulty) -> [(date: Date, time: Int, errors: Int)] {
        let states = loadAllStates()
        let suffix = "_\(difficulty.rawValue)"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return states
            .filter { $0.key.hasSuffix(suffix) && $0.value.isCompleted }
            .compactMap { (key, state) -> (Date, Int, Int)? in
                let dateString = String(key.dropLast(suffix.count))
                guard let date = formatter.date(from: dateString) else { return nil }
                return (date, state.elapsedSeconds, state.errorCount)
            }
            .sorted { $0.0 < $1.0 }
    }

    // MARK: - Clear Data

    /// Clear all Sudoku game data
    func clearAllData() {
        defaults.removeObject(forKey: storageKey)
    }

    // MARK: - Private Helpers

    /// Create storage key from date and difficulty
    private func makeKey(date: Date, difficulty: SudokuDifficulty) -> String {
        let dateKey = SudokuGenerator.dateKey(for: date)
        return "\(dateKey)_\(difficulty.rawValue)"
    }

    /// Load all stored states
    private func loadAllStates() -> [String: StoredSudokuState] {
        guard let data = defaults.data(forKey: storageKey),
              let states = try? JSONDecoder().decode([String: StoredSudokuState].self, from: data) else {
            return [:]
        }
        return states
    }

    /// Save all states
    private func saveAllStates(_ states: [String: StoredSudokuState]) {
        guard let data = try? JSONEncoder().encode(states) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
