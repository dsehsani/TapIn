//
//  GameState.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/20/26.
//
//  MARK: - Model Layer (MVVM)
//  This enum represents the overall state of a Wordle game session.
//  It determines whether the player can continue guessing or if the game has ended.
//
//  Integration Notes:
//  - Used by GameViewModel to control game flow
//  - Used by ContentView to show/hide GameOverView
//  - Persisted via GameStorage (converted to String for Codable support)
//

import Foundation

// MARK: - Game State Enum
/// Represents the current state of a Wordle game session.
///
/// Game flow:
/// 1. Game starts in `.playing` state
/// 2. Player makes guesses (up to 6)
/// 3. Game ends in either:
///    - `.won` - Player guessed the word correctly
///    - `.lost` - Player used all 6 guesses without success
///
/// Once the game ends, no more input is accepted and the game over overlay is shown.
///
enum GameState {
    /// Game is in progress, player can make guesses
    case playing

    /// Player successfully guessed the target word
    case won

    /// Player exhausted all 6 guesses without finding the word
    case lost
}
