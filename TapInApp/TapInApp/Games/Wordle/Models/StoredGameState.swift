//
//  StoredGameState.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/22/26.
//
//  MARK: - Model Layer (MVVM)
//  This struct represents a persisted game state for the daily Wordle system.
//  It stores all information needed to restore a game session.
//
//  Integration Notes:
//  - Codable for JSON serialization to UserDefaults
//  - Keyed by date string (yyyy-MM-dd format)
//  - Used by GameStorage for persistence operations
//  - Used by GameViewModel for restoring game state
//

import Foundation

// MARK: - Stored Game State
/// A Codable representation of a game session for persistence.
///
/// This struct is used to save and restore game progress across app launches.
/// Each day has its own stored state, allowing players to:
/// - Resume incomplete games
/// - View completed games in the archive
/// - Track win/loss history
///
/// Storage format (JSON in UserDefaults):
/// ```json
/// {
///   "2026-01-22": {
///     "guesses": ["BRAIN", "SMART"],
///     "gameState": "playing",
///     "dateKey": "2026-01-22"
///   }
/// }
/// ```
///
struct StoredGameState: Codable {
    /// Array of guesses made in this game session
    /// Each guess is a 5-letter uppercase string
    let guesses: [String]

    /// String representation of GameState
    /// Values: "playing", "won", "lost"
    let gameState: String

    /// Date key in yyyy-MM-dd format
    /// Used as the dictionary key for storage
    let dateKey: String

    // MARK: - Computed Properties

    /// Returns true if the game has ended (won or lost)
    var isCompleted: Bool {
        gameState == "won" || gameState == "lost"
    }

    /// Returns true if the player won this game
    var isWon: Bool {
        gameState == "won"
    }
}
