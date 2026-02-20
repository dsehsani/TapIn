//
//  PipesModels.swift
//  TapInApp
//

import SwiftUI

// MARK: - Position

struct PipePosition: Equatable, Hashable {
    let row: Int
    let col: Int
}

// MARK: - Pipe Color

enum PipeColor: String, CaseIterable, Hashable {
    case red, blue, green, yellow, orange, purple

    var displayColor: Color {
        switch self {
        case .red: return Color(red: 0.94, green: 0.27, blue: 0.27)
        case .blue: return Color(red: 0.23, green: 0.51, blue: 0.96)
        case .green: return Color(red: 0.13, green: 0.77, blue: 0.37)
        case .yellow: return Color(red: 0.92, green: 0.70, blue: 0.05)
        case .orange: return Color(red: 0.98, green: 0.45, blue: 0.09)
        case .purple: return Color(red: 0.66, green: 0.33, blue: 0.97)
        }
    }
}

// MARK: - Puzzle Definition

struct PipeEndpointPair {
    let color: PipeColor
    let start: PipePosition
    let end: PipePosition
}

struct PipePuzzle {
    let size: Int
    let pairs: [PipeEndpointPair]
}

// MARK: - Game State

enum PipesGameState {
    case playing
    case solved
}
