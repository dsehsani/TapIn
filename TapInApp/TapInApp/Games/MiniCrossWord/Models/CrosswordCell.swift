//
//  CrosswordCell.swift
//  TapInApp
//
//  MARK: - Model Layer
//  Represents a single cell in the crossword grid.
//

import Foundation

/// A single cell in the crossword grid
struct CrosswordCell: Identifiable, Equatable {
    let id: UUID
    let row: Int
    let col: Int
    var isBlocked: Bool
    var letter: Character?
    var correctLetter: Character?
    var clueNumber: Int?
    var acrossClueID: UUID?
    var downClueID: UUID?
    var isRevealed: Bool
    var isChecked: Bool
    var isIncorrect: Bool

    init(
        id: UUID = UUID(),
        row: Int,
        col: Int,
        isBlocked: Bool = false,
        letter: Character? = nil,
        correctLetter: Character? = nil,
        clueNumber: Int? = nil,
        acrossClueID: UUID? = nil,
        downClueID: UUID? = nil,
        isRevealed: Bool = false,
        isChecked: Bool = false,
        isIncorrect: Bool = false
    ) {
        self.id = id
        self.row = row
        self.col = col
        self.isBlocked = isBlocked
        self.letter = letter
        self.correctLetter = correctLetter
        self.clueNumber = clueNumber
        self.acrossClueID = acrossClueID
        self.downClueID = downClueID
        self.isRevealed = isRevealed
        self.isChecked = isChecked
        self.isIncorrect = isIncorrect
    }

    /// Whether this cell is empty (no letter entered)
    var isEmpty: Bool {
        letter == nil
    }

    /// Whether the entered letter matches the correct answer
    var isCorrect: Bool {
        guard let letter = letter, let correctLetter = correctLetter else { return false }
        return letter == correctLetter
    }
}
