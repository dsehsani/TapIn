//
//  LetterTile.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/20/26.
//
//  MARK: - Model Layer (MVVM)
//  This struct represents a single tile in the 6x5 Wordle game grid.
//  Each tile contains a letter (optional), its evaluation state, and animation properties.
//
//  Integration Notes:
//  - The game grid is a 2D array of LetterTile: [[LetterTile]]
//  - Each row represents one guess (6 guesses total)
//  - Each column represents one letter position (5 letters per word)
//  - Used by: GameViewModel (state management), TileView (rendering)
//

import Foundation

// MARK: - Letter Tile Model
/// Represents a single tile in the Wordle game grid.
///
/// Each tile tracks:
/// - The letter it contains (if any)
/// - Its current evaluation state (empty, filled, correct, etc.)
/// - Animation state for the reveal flip effect
///
/// Example usage:
/// ```swift
/// var tile = LetterTile()
/// tile.letter = "A"
/// tile.state = .filled
/// // After evaluation:
/// tile.state = .correct
/// ```
///
struct LetterTile: Identifiable {
    /// Unique identifier for SwiftUI ForEach loops
    let id = UUID()

    /// The letter displayed in this tile (nil if empty)
    var letter: Character?

    /// Current evaluation state of the tile
    /// - See `LetterState` for possible values
    var state: LetterState = .empty

    /// Whether this tile is currently animating its reveal
    /// Set to true when the guess is submitted, triggers flip animation
    var isRevealing: Bool = false

    /// Staggered delay for the reveal animation (in seconds)
    /// Each tile in a row has an increasing delay for cascading effect
    /// Example: tile 0 = 0s, tile 1 = 0.15s, tile 2 = 0.30s, etc.
    var revealDelay: Double = 0
}
