//
//  SamplePuzzles.swift
//  TapInApp
//
//  MARK: - Data Layer
//  Contains hardcoded UC Davis themed crossword puzzles.
//

import Foundation

/// Sample crossword puzzles for the MiniCrossword game
struct SamplePuzzles {
    /// Array of available puzzles (cycled by date)
    static let puzzles: [CrosswordPuzzle] = [
        // MARK: - Puzzle 1: Campus Life
        CrosswordPuzzle(
            title: "Campus Life",
            author: "Aggie Games",
            gridSize: 5,
            clues: [
                // Across clues
                CrosswordClue(number: 1, direction: .across, text: "UC Davis mascot", answer: "AGGIE", startRow: 0, startCol: 0),
                CrosswordClue(number: 6, direction: .across, text: "Campus bike path", answer: "TRAIL", startRow: 1, startCol: 0),
                CrosswordClue(number: 7, direction: .across, text: "Picnic Day month", answer: "APRIL", startRow: 2, startCol: 0),
                CrosswordClue(number: 8, direction: .across, text: "Library study area", answer: "QUIET", startRow: 3, startCol: 0),
                CrosswordClue(number: 9, direction: .across, text: "Exam period", answer: "FINAL", startRow: 4, startCol: 0),
                // Down clues
                CrosswordClue(number: 1, direction: .down, text: "Arts building", answer: "ATAQF", startRow: 0, startCol: 0),
                CrosswordClue(number: 2, direction: .down, text: "Grape variety grown at UCD", answer: "GRIUI", startRow: 0, startCol: 1),
                CrosswordClue(number: 3, direction: .down, text: "Goal of research", answer: "GRAIN", startRow: 0, startCol: 2),
                CrosswordClue(number: 4, direction: .down, text: "What students write", answer: "IILEA", startRow: 0, startCol: 3),
                CrosswordClue(number: 5, direction: .down, text: "Final result", answer: "ELTLL", startRow: 0, startCol: 4)
            ],
            blockedCells: []
        ),

        // MARK: - Puzzle 2: Aggie Athletics
        CrosswordPuzzle(
            title: "Aggie Athletics",
            author: "Aggie Games",
            gridSize: 5,
            clues: [
                // Across clues
                CrosswordClue(number: 1, direction: .across, text: "UC Davis color with blue", answer: "GOLD", startRow: 0, startCol: 0),
                CrosswordClue(number: 5, direction: .across, text: "Athletic competition", answer: "GAME", startRow: 1, startCol: 0),
                CrosswordClue(number: 6, direction: .across, text: "Soccer or football field", answer: "TURF", startRow: 2, startCol: 0),
                CrosswordClue(number: 7, direction: .across, text: "Track event", answer: "RACE", startRow: 3, startCol: 0),
                CrosswordClue(number: 8, direction: .across, text: "Victory", answer: "WIN", startRow: 4, startCol: 0),
                // Down clues
                CrosswordClue(number: 1, direction: .down, text: "Protective sports equipment", answer: "GGTRW", startRow: 0, startCol: 0),
                CrosswordClue(number: 2, direction: .down, text: "Running circuit", answer: "OAUAI", startRow: 0, startCol: 1),
                CrosswordClue(number: 3, direction: .down, text: "Playing area", answer: "LMRCN", startRow: 0, startCol: 2),
                CrosswordClue(number: 4, direction: .down, text: "Athletic shoe brand", answer: "DEE", startRow: 0, startCol: 3)
            ],
            blockedCells: [(0, 4), (1, 4), (2, 4), (3, 3), (3, 4), (4, 3), (4, 4)]
        ),

        // MARK: - Puzzle 3: Davis Downtown
        CrosswordPuzzle(
            title: "Davis Downtown",
            author: "Aggie Games",
            gridSize: 5,
            clues: [
                // Across clues
                CrosswordClue(number: 1, direction: .across, text: "Popular Davis coffee shop drink", answer: "LATTE", startRow: 0, startCol: 0),
                CrosswordClue(number: 6, direction: .across, text: "Downtown shopping", answer: "STORE", startRow: 1, startCol: 0),
                CrosswordClue(number: 7, direction: .across, text: "Davis farmers market day", answer: "SATAM", startRow: 2, startCol: 0),
                CrosswordClue(number: 8, direction: .across, text: "Local pizza spot", answer: "SLICE", startRow: 3, startCol: 0),
                CrosswordClue(number: 9, direction: .across, text: "Ice cream treat", answer: "SCOOP", startRow: 4, startCol: 0),
                // Down clues
                CrosswordClue(number: 1, direction: .down, text: "Part of campus life", answer: "LSSSL", startRow: 0, startCol: 0),
                CrosswordClue(number: 2, direction: .down, text: "Study snack", answer: "ATAIC", startRow: 0, startCol: 1),
                CrosswordClue(number: 3, direction: .down, text: "Coffee shop seating", answer: "TOTOO", startRow: 0, startCol: 2),
                CrosswordClue(number: 4, direction: .down, text: "Lunch hour", answer: "TRAMP", startRow: 0, startCol: 3),
                CrosswordClue(number: 5, direction: .down, text: "Weekend", answer: "EMEEP", startRow: 0, startCol: 4)
            ],
            blockedCells: []
        )
    ]
}
