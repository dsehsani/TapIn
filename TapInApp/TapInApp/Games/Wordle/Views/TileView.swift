//
//  TileView.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/20/26.
//
//  MARK: - View Layer (MVVM)
//  This view renders a single tile in the Wordle game grid.
//  It handles the 3D flip animation when revealing letter states.
//
//  Integration Notes:
//  - Used by GameGridView to render each tile in the 6x5 grid
//  - Animates based on `tile.isRevealing` and `tile.revealDelay`
//  - Colors determined by LetterState (see Models/LetterState.swift)
//  - Animation: 3D flip on X-axis with staggered timing
//

import SwiftUI

// MARK: - Tile View
/// Renders a single tile in the Wordle game grid with flip animation.
///
/// Visual states:
/// - Empty: White tile with light border
/// - Filled: White tile with darker border, shows letter
/// - Revealed: Colored background (green/gold/gray) with white text
///
/// Animation behavior:
/// - When `tile.isRevealing` becomes true, triggers a 3D flip
/// - Color appears at midpoint of flip for smooth transition
/// - Staggered delays create cascading reveal effect
///
struct TileView: View {
    /// The tile data to display (from GameViewModel.grid)
    let tile: LetterTile

    /// Whether this tile is in the row currently being revealed
    /// Used to distinguish between animated reveals and restored states
    let isInRevealingRow: Bool

    /// Color scheme for dark mode support
    var colorScheme: ColorScheme = .light

    // MARK: - Animation State

    /// Controls the 3D rotation of the tile (0° or 180°)
    @State private var flipped = false

    /// Controls when the colored background is shown
    /// Set at midpoint of flip animation for seamless color transition
    @State private var showColor = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background - colored after reveal
            RoundedRectangle(cornerRadius: 8)
                .fill(showColor ? tile.state.backgroundColor : Color.clear)

            // Border - visible only before reveal (with dark mode support)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(showColor ? Color.clear : tile.state.borderColor(for: colorScheme), lineWidth: 2)

            // Letter - centered in tile
            if let letter = tile.letter {
                Text(String(letter))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(tileTextColor)
            }
        }
        .frame(width: 58, height: 58)
        // 3D flip rotation on X-axis
        .rotation3DEffect(
            .degrees(flipped ? 180 : 0),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.5
        )
        // Trigger flip animation when tile starts revealing
        .onChange(of: tile.isRevealing) { _, isRevealing in
            if isRevealing {
                startRevealAnimation()
            }
        }
        // Handle immediate state changes (restored games, new game loads)
        .onChange(of: tile.state) { oldState, newState in
            handleStateChange(from: oldState, to: newState)
        }
        // Set initial color state for already-revealed tiles
        .onAppear {
            if tile.state != .empty && tile.state != .filled {
                showColor = true
            }
        }
    }

    // MARK: - Animation Methods

    /// Starts the 3D flip reveal animation with staggered timing
    private func startRevealAnimation() {
        // Flip animation with delay based on tile position
        withAnimation(.easeInOut(duration: 0.3).delay(tile.revealDelay)) {
            flipped = true
        }

        // Show color at midpoint of flip (0.15s into the 0.3s animation)
        DispatchQueue.main.asyncAfter(deadline: .now() + tile.revealDelay + 0.15) {
            showColor = true
        }

        // Flip back to upright after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + tile.revealDelay + 0.3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                flipped = false
            }
        }
    }

    /// Handles non-animated state changes (game restoration, new game)
    private func handleStateChange(from oldState: LetterState, to newState: LetterState) {
        // Immediate color update for restored games (no animation)
        if !isInRevealingRow && newState != .empty && newState != .filled {
            showColor = true
        }
        // Reset showColor when tile becomes empty (new game loaded)
        if newState == .empty {
            showColor = false
        }
    }

    // MARK: - Computed Properties

    /// Text color based on current tile state
    /// White text on colored backgrounds, adaptive on empty/filled
    private var tileTextColor: Color {
        if showColor {
            switch tile.state {
            case .correct, .wrongPosition, .notInWord:
                return .white
            default:
                return Color.wordleTileText(colorScheme)
            }
        }
        return Color.wordleTileText(colorScheme)
    }
}

// MARK: - Preview
#Preview {
    HStack {
        TileView(tile: LetterTile(), isInRevealingRow: false)
        TileView(
            tile: {
                var t = LetterTile()
                t.letter = "A"
                t.state = .filled
                return t
            }(),
            isInRevealingRow: false
        )
        TileView(
            tile: {
                var t = LetterTile()
                t.letter = "B"
                t.state = .correct
                return t
            }(),
            isInRevealingRow: false
        )
    }
}
