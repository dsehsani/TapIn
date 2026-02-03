//
//  CrosswordStorage.swift
//  TapInApp
//
//  MARK: - Service Layer
//  Singleton service for persisting crossword game states.
//  Uses UserDefaults with JSON encoding.
//

import Foundation

/// Singleton service for persisting crossword game states
class CrosswordStorage {

    // MARK: - Singleton

    static let shared = CrosswordStorage()

    // MARK: - Properties

    private let defaults = UserDefaults.standard
    private let storageKey = "crosswordGameStates"

    // MARK: - Initialization

    private init() {}

    // MARK: - Save Methods

    /// Saves the current game state for a given date
    func saveGameState(
        for date: Date,
        puzzleID: UUID,
        letters: [[Character?]],
        gameState: CrosswordGameState,
        elapsedSeconds: Int
    ) {
        let dateKey = CrosswordPuzzleProvider.shared.dateKey(for: date)

        let storedState = StoredCrosswordState(
            dateKey: dateKey,
            puzzleID: puzzleID,
            letters: letters,
            gameState: gameState,
            elapsedSeconds: elapsedSeconds
        )

        var allStates = loadAllStates()
        allStates[dateKey] = storedState
        saveAllStates(allStates)
    }

    // MARK: - Load Methods

    /// Loads the saved game state for a given date
    func loadGameState(for date: Date) -> StoredCrosswordState? {
        let dateKey = CrosswordPuzzleProvider.shared.dateKey(for: date)
        let allStates = loadAllStates()
        return allStates[dateKey]
    }

    // MARK: - Query Methods

    /// Checks if a date has been completed
    func isDateCompleted(_ date: Date) -> Bool {
        guard let state = loadGameState(for: date) else { return false }
        return state.isCompleted
    }

    /// Returns all dates that have saved game data
    func getAllPlayedDates() -> [Date] {
        let allStates = loadAllStates()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return allStates.keys.compactMap { formatter.date(from: $0) }.sorted(by: >)
    }

    // MARK: - Private Helpers

    private func loadAllStates() -> [String: StoredCrosswordState] {
        guard let data = defaults.data(forKey: storageKey),
              let states = try? JSONDecoder().decode([String: StoredCrosswordState].self, from: data) else {
            return [:]
        }
        return states
    }

    private func saveAllStates(_ states: [String: StoredCrosswordState]) {
        if let data = try? JSONEncoder().encode(states) {
            defaults.set(data, forKey: storageKey)
        }
    }

    // MARK: - Debug/Testing

    /// Clears all saved crossword data
    func clearAllData() {
        defaults.removeObject(forKey: storageKey)
    }
}
