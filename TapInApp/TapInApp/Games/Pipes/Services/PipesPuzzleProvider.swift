//
//  PipesPuzzleProvider.swift
//  TapInApp
//
//  Singleton service that provides one Pipes puzzle per day.
//  Cycles through the puzzle pool based on day-of-year.
//

import Foundation

class PipesPuzzleProvider {

    static let shared = PipesPuzzleProvider()

    private init() {}

    private let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    func dateKey(for date: Date = Date()) -> String {
        dateFormatter.string(from: date)
    }

    func puzzleForDate(_ date: Date = Date()) -> PipePuzzle {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = (dayOfYear - 1) % PipePuzzle.puzzles.count
        return PipePuzzle.puzzles[index]
    }
}
