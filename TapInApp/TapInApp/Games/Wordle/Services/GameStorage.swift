//
//  GameStorage.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/22/26.
//
//  MARK: - Service Layer (MVVM)
//  This singleton service handles persistent storage of game states.
//  It uses UserDefaults to store game progress keyed by date.
//
//  Architecture:
//  - Singleton pattern (GameStorage.shared)
//  - JSON encoding/decoding for StoredGameState
//  - Date-keyed storage for daily game support
//
//  Integration Notes:
//  - Access via GameStorage.shared
//  - Call saveGameState() after each guess
//  - Call loadGameState() when loading a date
//  - Supports querying completed games for archive
//
//  Storage Format:
//  - Key: "wordleGameStates"
//  - Value: JSON dictionary of [dateKey: StoredGameState]
//

import Foundation

// MARK: - Game Storage Manager
/// Singleton service for persisting Wordle game states.
///
/// Provides functionality for:
/// - Saving game progress (guesses, game state)
/// - Loading saved games by date
/// - Querying played/completed dates for archive
/// - Tracking win/loss statistics
///
/// Storage is handled via UserDefaults with JSON encoding.
/// Each game is keyed by date string (yyyy-MM-dd format).
///
/// Example usage:
/// ```swift
/// // Save current game
/// GameStorage.shared.saveGameState(
///     for: date,
///     guesses: ["BRAIN", "SMART"],
///     gameState: .playing
/// )
///
/// // Load saved game
/// if let saved = GameStorage.shared.loadGameState(for: date) {
///     // Restore game from saved state
/// }
/// ```
///
class GameStorage {

    // MARK: - Singleton

    /// Shared instance of GameStorage
    static let shared = GameStorage()

    // MARK: - Properties

    /// UserDefaults instance for persistence
    private let defaults = UserDefaults.standard

    /// Key used for storing game states dictionary
    private let storageKey = "wordleGameStates"

    // MARK: - Initialization

    /// Private initializer to enforce singleton pattern
    private init() {}

    // MARK: - Save Methods

    /// Saves the current game state for a given date
    ///
    /// This method:
    /// 1. Converts GameState enum to string for Codable support
    /// 2. Creates a StoredGameState with the provided data
    /// 3. Merges into existing states dictionary
    /// 4. Persists to UserDefaults
    ///
    /// - Parameters:
    ///   - date: The date to save the game for
    ///   - guesses: Array of guess strings made in this game
    ///   - gameState: Current game state (playing, won, lost)
    func saveGameState(for date: Date, guesses: [String], gameState: GameState) {
        let dateKey = DateWordGenerator.dateKey(for: date)

        // Convert GameState enum to string for Codable
        let stateString: String
        switch gameState {
        case .playing: stateString = "playing"
        case .won: stateString = "won"
        case .lost: stateString = "lost"
        }

        let storedState = StoredGameState(
            guesses: guesses,
            gameState: stateString,
            dateKey: dateKey
        )

        // Merge into existing states
        var allStates = loadAllStates()
        allStates[dateKey] = storedState
        saveAllStates(allStates)
    }

    // MARK: - Load Methods

    /// Loads the saved game state for a given date
    ///
    /// - Parameter date: The date to load the game for
    /// - Returns: The stored state if exists, nil otherwise
    func loadGameState(for date: Date) -> StoredGameState? {
        let dateKey = DateWordGenerator.dateKey(for: date)
        let allStates = loadAllStates()
        return allStates[dateKey]
    }

    // MARK: - Query Methods

    /// Checks if a date has any saved game data
    ///
    /// - Parameter date: The date to check
    /// - Returns: True if any progress exists for this date
    func hasPlayedDate(_ date: Date) -> Bool {
        return loadGameState(for: date) != nil
    }

    /// Checks if a date's game has been completed (won or lost)
    ///
    /// - Parameter date: The date to check
    /// - Returns: True if the game ended (not still in progress)
    func isDateCompleted(_ date: Date) -> Bool {
        guard let state = loadGameState(for: date) else { return false }
        return state.isCompleted
    }

    /// Returns all dates that have saved game data
    ///
    /// - Returns: Array of dates sorted by most recent first
    func getAllPlayedDates() -> [Date] {
        let allStates = loadAllStates()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return allStates.keys.compactMap { formatter.date(from: $0) }.sorted(by: >)
    }

    /// Returns all completed games with their win/loss status
    ///
    /// Used by ArchiveView to display calendar with color-coded results
    ///
    /// - Returns: Array of tuples (date, won) sorted by most recent first
    func getCompletedDatesWithStatus() -> [(date: Date, won: Bool)] {
        let allStates = loadAllStates()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return allStates.compactMap { key, state -> (Date, Bool)? in
            guard state.isCompleted, let date = formatter.date(from: key) else { return nil }
            return (date, state.isWon)
        }.sorted { $0.0 > $1.0 }
    }

    // MARK: - Private Helpers

    /// Loads all stored game states from UserDefaults
    ///
    /// - Returns: Dictionary of dateKey -> StoredGameState, empty if none exist
    private func loadAllStates() -> [String: StoredGameState] {
        guard let data = defaults.data(forKey: storageKey),
              let states = try? JSONDecoder().decode([String: StoredGameState].self, from: data) else {
            return [:]
        }
        return states
    }

    /// Saves all game states to UserDefaults
    ///
    /// - Parameter states: Dictionary of all game states to persist
    private func saveAllStates(_ states: [String: StoredGameState]) {
        if let data = try? JSONEncoder().encode(states) {
            defaults.set(data, forKey: storageKey)
        }
    }

    // MARK: - Debug/Testing

    /// Clears all saved game data (use for testing only)
    func clearAllData() {
        defaults.removeObject(forKey: storageKey)
    }
}
