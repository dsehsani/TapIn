//
//  CrosswordPuzzleProvider.swift
//  TapInApp
//
//  MARK: - Service Layer
//  Singleton service that provides crossword puzzles.
//  Cycles through available puzzles based on date.
//

import Foundation

/// Singleton service for providing crossword puzzles
class CrosswordPuzzleProvider {

    // MARK: - Singleton

    static let shared = CrosswordPuzzleProvider()

    private init() {}

    // MARK: - Date Formatting

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Returns a date key string for a given date
    func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Puzzle Selection

    /// Returns the puzzle for a specific date
    /// Cycles through available puzzles based on day of year
    func puzzleForDate(_ date: Date) -> CrosswordPuzzle {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let puzzleIndex = (dayOfYear - 1) % SamplePuzzles.puzzles.count

        let puzzle = SamplePuzzles.puzzles[puzzleIndex]
        // Create a new puzzle with the date key set
        return CrosswordPuzzle(
            id: puzzle.id,
            title: puzzle.title,
            author: puzzle.author,
            dateKey: dateKey(for: date),
            gridSize: puzzle.gridSize,
            clues: puzzle.clues,
            blockedCells: puzzle.blockedCells
        )
    }

    /// Returns today's puzzle
    func todaysPuzzle() -> CrosswordPuzzle {
        puzzleForDate(Date())
    }

    /// Returns today's date normalized to start of day
    static var today: Date {
        Calendar.current.startOfDay(for: Date())
    }
}
