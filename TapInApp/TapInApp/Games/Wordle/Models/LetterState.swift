//
//  LetterState.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/20/26.
//
//  MARK: - Model Layer (MVVM)
//  This enum represents the possible states of a letter tile in the Wordle game.
//  It is used by both the ViewModel (GameViewModel) and Views (TileView, KeyboardView)
//  to determine visual styling and game logic.
//
//  Integration Notes:
//  - Import this file when you need to reference tile states
//  - Colors are defined in Extensions/Color+Theme.swift
//  - Used by: GameViewModel, TileView, KeyboardView, KeyView
//

import SwiftUI

// MARK: - Letter State Enum
/// Represents the evaluation state of a letter in the Wordle game.
///
/// States progress as follows:
/// 1. `.empty` - No letter entered yet
/// 2. `.filled` - Letter entered but not submitted
/// 3. After submission, one of:
///    - `.correct` - Letter is in the correct position (green)
///    - `.wrongPosition` - Letter exists in word but wrong position (gold)
///    - `.notInWord` - Letter is not in the target word (gray)
///
enum LetterState {
    /// Tile has no letter (default state)
    case empty

    /// Tile has a letter but guess not yet submitted
    case filled

    /// Letter is in the correct position (green)
    case correct

    /// Letter exists in word but in wrong position (gold/yellow)
    case wrongPosition

    /// Letter is not in the target word (gray)
    case notInWord

    // MARK: - Visual Properties

    /// Returns the background color for this state.
    /// Used by TileView and KeyView for rendering.
    var backgroundColor: Color {
        switch self {
        case .empty, .filled:
            return Color.clear
        case .correct:
            return Color.wordleGreen
        case .wrongPosition:
            return Color.ucdGold
        case .notInWord:
            return Color.wordleGray
        }
    }

    /// Returns the border color for this state.
    /// Only applies to empty/filled states; revealed tiles have no border.
    var borderColor: Color {
        switch self {
        case .empty:
            return Color.tileBorder
        case .filled:
            return Color.tileBorderFilled
        case .correct, .wrongPosition, .notInWord:
            return Color.clear
        }
    }

    /// Returns the border color for this state with dark mode support.
    func borderColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .empty:
            return Color.wordleTileBorder(colorScheme)
        case .filled:
            return Color.wordleTileBorderFilled(colorScheme)
        case .correct, .wrongPosition, .notInWord:
            return Color.clear
        }
    }
}
