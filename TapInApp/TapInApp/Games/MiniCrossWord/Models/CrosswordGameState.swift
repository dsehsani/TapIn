//
//  CrosswordGameState.swift
//  TapInApp
//
//  MARK: - Model Layer
//  Defines the game state for crossword puzzles.
//

import Foundation

/// State of a crossword game
enum CrosswordGameState: String, Codable {
    case playing
    case completed
}
