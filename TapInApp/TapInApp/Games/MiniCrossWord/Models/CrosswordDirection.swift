//
//  CrosswordDirection.swift
//  TapInApp
//
//  MARK: - Model Layer
//  Defines the direction for crossword clues (across or down).
//

import Foundation

/// Direction of a crossword clue
enum CrosswordDirection: String, Codable, CaseIterable {
    case across
    case down

    /// Returns the opposite direction
    var opposite: CrosswordDirection {
        switch self {
        case .across: return .down
        case .down: return .across
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .across: return "Across"
        case .down: return "Down"
        }
    }
}
