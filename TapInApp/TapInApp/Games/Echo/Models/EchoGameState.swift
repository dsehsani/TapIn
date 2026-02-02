//
//  EchoGameState.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  State machine enum for the Echo game. Controls which screen is shown
//  and what interactions are available at each phase.
//

import Foundation

// MARK: - Echo Game State
enum EchoGameState {
    /// Displaying original sequence for memorization (2-second timer)
    case showingSequence

    /// Rules appearing one by one
    case revealingRules

    /// Player is building their answer sequence
    case playerInput

    /// Checking the player's submission (transient feedback state)
    case evaluating

    /// Showing result of the round (correct or out of attempts)
    case roundComplete

    /// All rounds completed, final summary
    case gameOver
}
