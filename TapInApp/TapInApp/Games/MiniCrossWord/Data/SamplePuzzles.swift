//
//  SamplePuzzles.swift
//  TapInApp
//
//  MARK: - Data Layer
//  Contains hardcoded crossword puzzles with common English words.
//

import Foundation

/// Sample crossword puzzles for the MiniCrossword game
struct SamplePuzzles {
    /// Array of available puzzles (cycled by date)
    static let puzzles: [CrosswordPuzzle] = [
        // MARK: - Puzzle 1: Word Square
        // A perfect word square where rows and columns spell the same words
        // H E A R T
        // E M B E R
        // A B O D E
        // R E D O S
        // T R E S S
        CrosswordPuzzle(
            title: "Word Square",
            author: "Daily Mini",
            gridSize: 5,
            clues: [
                // Across clues
                CrosswordClue(number: 1, direction: .across, text: "Vital organ that pumps blood", answer: "HEART", startRow: 0, startCol: 0),
                CrosswordClue(number: 6, direction: .across, text: "Glowing coal in a fire", answer: "EMBER", startRow: 1, startCol: 0),
                CrosswordClue(number: 7, direction: .across, text: "Place to live, dwelling", answer: "ABODE", startRow: 2, startCol: 0),
                CrosswordClue(number: 8, direction: .across, text: "Does something again", answer: "REDOS", startRow: 3, startCol: 0),
                CrosswordClue(number: 9, direction: .across, text: "Lock of hair", answer: "TRESS", startRow: 4, startCol: 0),
                // Down clues (same words in a word square)
                CrosswordClue(number: 1, direction: .down, text: "Center of emotions", answer: "HEART", startRow: 0, startCol: 0),
                CrosswordClue(number: 2, direction: .down, text: "Hot ash from a fire", answer: "EMBER", startRow: 0, startCol: 1),
                CrosswordClue(number: 3, direction: .down, text: "Home or residence", answer: "ABODE", startRow: 0, startCol: 2),
                CrosswordClue(number: 4, direction: .down, text: "Repeat performances", answer: "REDOS", startRow: 0, startCol: 3),
                CrosswordClue(number: 5, direction: .down, text: "Strand of hair", answer: "TRESS", startRow: 0, startCol: 4)
            ],
            blockedCells: []
        ),

        // MARK: - Puzzle 2: Daily Mix
        // Grid with blocked cells
        // H O P E S
        // O ■ I ■ T
        // P I A N O
        // E ■ N ■ R
        // S T O R Y
        CrosswordPuzzle(
            title: "Daily Mix",
            author: "Daily Mini",
            gridSize: 5,
            clues: [
                // Across clues
                CrosswordClue(number: 1, direction: .across, text: "Wishes for the future", answer: "HOPES", startRow: 0, startCol: 0),
                CrosswordClue(number: 6, direction: .across, text: "Keyboard instrument", answer: "PIANO", startRow: 2, startCol: 0),
                CrosswordClue(number: 7, direction: .across, text: "Narrative tale", answer: "STORY", startRow: 4, startCol: 0),
                // Down clues
                CrosswordClue(number: 1, direction: .down, text: "Desires and dreams", answer: "HOPES", startRow: 0, startCol: 0),
                CrosswordClue(number: 3, direction: .down, text: "Musical keyboard", answer: "PIANO", startRow: 0, startCol: 2),
                CrosswordClue(number: 5, direction: .down, text: "A tale to tell", answer: "STORY", startRow: 0, startCol: 4)
            ],
            blockedCells: [(1, 1), (1, 3), (3, 1), (3, 3)]
        ),

        // MARK: - Puzzle 3: Quick Cross
        // Simple cross pattern
        // ■ ■ T ■ ■
        // ■ ■ H ■ ■
        // W H I L E
        // ■ ■ N ■ ■
        // ■ ■ K ■ ■
        CrosswordPuzzle(
            title: "Quick Cross",
            author: "Daily Mini",
            gridSize: 5,
            clues: [
                // Across clues
                CrosswordClue(number: 1, direction: .across, text: "During the time that", answer: "WHILE", startRow: 2, startCol: 0),
                // Down clues
                CrosswordClue(number: 2, direction: .down, text: "Use your brain", answer: "THINK", startRow: 0, startCol: 2)
            ],
            blockedCells: [
                (0, 0), (0, 1), (0, 3), (0, 4),
                (1, 0), (1, 1), (1, 3), (1, 4),
                (3, 0), (3, 1), (3, 3), (3, 4),
                (4, 0), (4, 1), (4, 3), (4, 4)
            ]
        )
    ]
}
