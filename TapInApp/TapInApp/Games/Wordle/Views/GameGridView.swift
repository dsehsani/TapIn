//
//  GameGridView.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/20/26.
//
//  MARK: - View Layer (MVVM)
//  This view renders the 6x5 Wordle game grid.
//  It displays all tiles organized in rows (guesses) and columns (letters).
//
//  Integration Notes:
//  - Used by ContentView as the main game display
//  - Receives grid data from GameViewModel
//  - Each tile is rendered by TileView
//  - Grid dimensions: 6 rows (guesses) x 5 columns (letters)
//

import SwiftUI

// MARK: - Game Grid View
/// Renders the 6x5 Wordle game grid.
///
/// Layout:
/// - 6 horizontal rows (one per guess attempt)
/// - 5 tiles per row (one per letter in the word)
/// - 6px spacing between tiles
/// - Fixed size to maintain consistent appearance
///
/// Data flow:
/// - Receives `grid` from GameViewModel via ContentView
/// - Passes each tile to TileView for rendering
/// - `revealingRow` indicates which row is animating
///
struct GameGridView: View {
    /// The 2D array of tiles from GameViewModel
    /// Structure: [[LetterTile]] where outer array is rows, inner is columns
    let grid: [[LetterTile]]

    /// Index of the row currently being revealed (-1 if none)
    /// Used to trigger flip animations only on the active row
    let revealingRow: Int

    /// Color scheme for dark mode support
    var colorScheme: ColorScheme = .light

    // MARK: - Body

    var body: some View {
        VStack(spacing: 6) {
            // Iterate through each row (guess attempt)
            ForEach(Array(grid.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 6) {
                    // Iterate through each tile in the row
                    ForEach(row) { tile in
                        TileView(
                            tile: tile,
                            isInRevealingRow: rowIndex == revealingRow,
                            colorScheme: colorScheme
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    // Create a sample grid for preview
    let sampleGrid: [[LetterTile]] = (0..<6).map { _ in
        (0..<5).map { _ in LetterTile() }
    }

    GameGridView(grid: sampleGrid, revealingRow: -1)
        .padding()
}
