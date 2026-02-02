//
//  CrosswordClue.swift
//  TapInApp
//
//  MARK: - Model Layer
//  Represents a single crossword clue with its answer and position.
//

import Foundation

/// A crossword clue with its answer and grid position
struct CrosswordClue: Identifiable, Codable, Equatable {
    let id: UUID
    let number: Int
    let direction: CrosswordDirection
    let text: String
    let answer: String
    let startRow: Int
    let startCol: Int

    init(
        id: UUID = UUID(),
        number: Int,
        direction: CrosswordDirection,
        text: String,
        answer: String,
        startRow: Int,
        startCol: Int
    ) {
        self.id = id
        self.number = number
        self.direction = direction
        self.text = text
        self.answer = answer.uppercased()
        self.startRow = startRow
        self.startCol = startCol
    }

    /// Returns the (row, col) positions for each cell this clue occupies
    var cellPositions: [(row: Int, col: Int)] {
        var positions: [(Int, Int)] = []
        for i in 0..<answer.count {
            switch direction {
            case .across:
                positions.append((startRow, startCol + i))
            case .down:
                positions.append((startRow + i, startCol))
            }
        }
        return positions
    }

    /// The length of the answer
    var length: Int {
        answer.count
    }
}
