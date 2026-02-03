//
//  CrosswordViewModel.swift
//  TapInApp
//
//  MARK: - ViewModel Layer (MVVM)
//  Central ViewModel for the MiniCrossword game.
//  Manages all game logic, state, and coordinates with persistence.
//

import SwiftUI

/// Central ViewModel managing all crossword game logic and state
@Observable
class CrosswordViewModel {

    // MARK: - Game Configuration

    let gridSize = 5

    // MARK: - Game State

    var currentPuzzle: CrosswordPuzzle?
    var grid: [[CrosswordCell]] = []
    var gameState: CrosswordGameState = .playing

    // MARK: - Selection State

    var selectedRow: Int = 0
    var selectedCol: Int = 0
    var currentDirection: CrosswordDirection = .across
    var selectedClue: CrosswordClue?

    // MARK: - Timer State

    var elapsedSeconds: Int = 0
    private var timerTask: Task<Void, Never>?
    private var gameStartTime: Date?

    // MARK: - Daily Mode

    var currentDate: Date = Date()

    // MARK: - Initialization

    init() {
        loadPuzzle(for: Date())
    }

    // MARK: - Puzzle Loading

    /// Loads the puzzle for a specific date
    func loadPuzzle(for date: Date) {
        currentDate = date
        currentPuzzle = CrosswordPuzzleProvider.shared.puzzleForDate(date)

        guard let puzzle = currentPuzzle else { return }

        // Initialize empty grid
        initializeGrid(puzzle: puzzle)

        // Reset state
        gameState = .playing
        selectedRow = 0
        selectedCol = 0
        currentDirection = .across
        elapsedSeconds = 0

        // Find first non-blocked cell
        selectFirstAvailableCell()

        // Update selected clue
        updateSelectedClue()

        // Load saved state if exists
        if let savedState = CrosswordStorage.shared.loadGameState(for: date) {
            restoreFromSavedState(savedState)
        }

        // Start timer if playing
        if gameState == .playing {
            startTimer()
        }
    }

    /// Initializes the grid from a puzzle definition
    private func initializeGrid(puzzle: CrosswordPuzzle) {
        // Create empty grid
        grid = (0..<gridSize).map { row in
            (0..<gridSize).map { col in
                CrosswordCell(row: row, col: col)
            }
        }

        // Mark blocked cells
        for (row, col) in puzzle.blockedCells {
            if row < gridSize && col < gridSize {
                grid[row][col].isBlocked = true
            }
        }

        // Set up clue associations and correct letters
        for clue in puzzle.clues {
            let positions = clue.cellPositions
            let answerChars = Array(clue.answer)

            for (index, pos) in positions.enumerated() {
                guard pos.row < gridSize && pos.col < gridSize else { continue }

                // Set correct letter
                grid[pos.row][pos.col].correctLetter = answerChars[index]

                // Set clue number on first cell
                if index == 0 {
                    grid[pos.row][pos.col].clueNumber = clue.number
                }

                // Associate clue with cell
                switch clue.direction {
                case .across:
                    grid[pos.row][pos.col].acrossClueID = clue.id
                case .down:
                    grid[pos.row][pos.col].downClueID = clue.id
                }
            }
        }
    }

    /// Restores game state from saved data
    private func restoreFromSavedState(_ state: StoredCrosswordState) {
        let letters = state.lettersAsCharacters

        for row in 0..<min(letters.count, gridSize) {
            for col in 0..<min(letters[row].count, gridSize) {
                grid[row][col].letter = letters[row][col]
            }
        }

        elapsedSeconds = state.elapsedSeconds

        if state.isCompleted {
            gameState = .completed
            stopTimer()
        }
    }

    /// Selects the first non-blocked cell
    private func selectFirstAvailableCell() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if !grid[row][col].isBlocked {
                    selectedRow = row
                    selectedCol = col
                    return
                }
            }
        }
    }

    // MARK: - Cell Selection

    /// Selects a cell at the given position
    func selectCell(row: Int, col: Int) {
        guard row >= 0 && row < gridSize && col >= 0 && col < gridSize else { return }
        guard !grid[row][col].isBlocked else { return }

        // If tapping same cell, toggle direction
        if row == selectedRow && col == selectedCol {
            toggleDirection()
        } else {
            selectedRow = row
            selectedCol = col
        }

        updateSelectedClue()
    }

    /// Toggles between across and down direction
    func toggleDirection() {
        let cell = grid[selectedRow][selectedCol]

        // Only toggle if cell has clues in both directions
        let hasAcross = cell.acrossClueID != nil
        let hasDown = cell.downClueID != nil

        if hasAcross && hasDown {
            currentDirection = currentDirection.opposite
        } else if hasAcross {
            currentDirection = .across
        } else if hasDown {
            currentDirection = .down
        }

        updateSelectedClue()
    }

    /// Updates the selected clue based on current cell and direction
    private func updateSelectedClue() {
        let cell = grid[selectedRow][selectedCol]

        let clueID: UUID?
        switch currentDirection {
        case .across:
            clueID = cell.acrossClueID ?? cell.downClueID
            if cell.acrossClueID == nil && cell.downClueID != nil {
                currentDirection = .down
            }
        case .down:
            clueID = cell.downClueID ?? cell.acrossClueID
            if cell.downClueID == nil && cell.acrossClueID != nil {
                currentDirection = .across
            }
        }

        selectedClue = currentPuzzle?.clues.first { $0.id == clueID }
    }

    /// Selects a clue and navigates to its first cell
    func selectClue(_ clue: CrosswordClue) {
        selectedClue = clue
        currentDirection = clue.direction
        selectedRow = clue.startRow
        selectedCol = clue.startCol
    }

    // MARK: - Input Handling

    /// Inputs a letter at the current position
    func inputLetter(_ letter: Character) {
        guard gameState == .playing else { return }
        guard !grid[selectedRow][selectedCol].isBlocked else { return }

        // Set the letter (uppercase)
        grid[selectedRow][selectedCol].letter = Character(letter.uppercased())
        grid[selectedRow][selectedCol].isIncorrect = false
        grid[selectedRow][selectedCol].isChecked = false

        // Move to next cell
        moveToNextCell()

        // Check completion
        checkCompletion()

        // Auto-save
        saveCurrentState()
    }

    /// Deletes the letter at the current position
    func deleteLetter() {
        guard gameState == .playing else { return }

        let cell = grid[selectedRow][selectedCol]

        if cell.letter != nil {
            // Delete current cell's letter
            grid[selectedRow][selectedCol].letter = nil
            grid[selectedRow][selectedCol].isIncorrect = false
            grid[selectedRow][selectedCol].isChecked = false
        } else {
            // Move to previous cell and delete
            moveToPreviousCell()
            grid[selectedRow][selectedCol].letter = nil
            grid[selectedRow][selectedCol].isIncorrect = false
            grid[selectedRow][selectedCol].isChecked = false
        }

        saveCurrentState()
    }

    /// Moves to the next cell in the current direction
    private func moveToNextCell() {
        guard let clue = selectedClue else { return }

        let positions = clue.cellPositions
        guard let currentIndex = positions.firstIndex(where: { $0.row == selectedRow && $0.col == selectedCol }) else { return }

        let nextIndex = currentIndex + 1
        if nextIndex < positions.count {
            selectedRow = positions[nextIndex].row
            selectedCol = positions[nextIndex].col
        }
    }

    /// Moves to the previous cell in the current direction
    private func moveToPreviousCell() {
        guard let clue = selectedClue else { return }

        let positions = clue.cellPositions
        guard let currentIndex = positions.firstIndex(where: { $0.row == selectedRow && $0.col == selectedCol }) else { return }

        let prevIndex = currentIndex - 1
        if prevIndex >= 0 {
            selectedRow = positions[prevIndex].row
            selectedCol = positions[prevIndex].col
        }
    }

    // MARK: - Check & Reveal

    /// Checks all entered answers and marks incorrect ones
    func checkAnswers() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if !grid[row][col].isBlocked && grid[row][col].letter != nil {
                    grid[row][col].isChecked = true
                    grid[row][col].isIncorrect = !grid[row][col].isCorrect
                }
            }
        }
        saveCurrentState()
    }

    /// Reveals the current cell's correct letter
    func revealCell() {
        guard !grid[selectedRow][selectedCol].isBlocked else { return }

        grid[selectedRow][selectedCol].letter = grid[selectedRow][selectedCol].correctLetter
        grid[selectedRow][selectedCol].isRevealed = true
        grid[selectedRow][selectedCol].isIncorrect = false

        checkCompletion()
        saveCurrentState()
    }

    /// Reveals all letters in the current word
    func revealWord() {
        guard let clue = selectedClue else { return }

        for pos in clue.cellPositions {
            guard pos.row < gridSize && pos.col < gridSize else { continue }
            grid[pos.row][pos.col].letter = grid[pos.row][pos.col].correctLetter
            grid[pos.row][pos.col].isRevealed = true
            grid[pos.row][pos.col].isIncorrect = false
        }

        checkCompletion()
        saveCurrentState()
    }

    /// Reveals the entire puzzle
    func revealPuzzle() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if !grid[row][col].isBlocked {
                    grid[row][col].letter = grid[row][col].correctLetter
                    grid[row][col].isRevealed = true
                    grid[row][col].isIncorrect = false
                }
            }
        }

        gameState = .completed
        stopTimer()
        saveCurrentState()
    }

    // MARK: - Completion Check

    /// Checks if the puzzle is completed correctly
    func checkCompletion() {
        // Check if all non-blocked cells are filled correctly
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let cell = grid[row][col]
                if !cell.isBlocked {
                    if cell.letter == nil || !cell.isCorrect {
                        return
                    }
                }
            }
        }

        // Puzzle is complete!
        gameState = .completed
        stopTimer()
        saveCurrentState()
    }

    // MARK: - Timer Management

    private func startTimer() {
        stopTimer()
        gameStartTime = Date()

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard let self = self, self.gameState == .playing else { return }
                    self.elapsedSeconds += 1
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Persistence

    private func saveCurrentState() {
        guard let puzzle = currentPuzzle else { return }

        let letters: [[Character?]] = grid.map { row in
            row.map { $0.letter }
        }

        CrosswordStorage.shared.saveGameState(
            for: currentDate,
            puzzleID: puzzle.id,
            letters: letters,
            gameState: gameState,
            elapsedSeconds: elapsedSeconds
        )
    }

    // MARK: - Computed Properties

    /// Formatted timer string (MM:SS)
    var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Whether today's puzzle is completed
    var isTodayCompleted: Bool {
        CrosswordStorage.shared.isDateCompleted(Date())
    }

    /// Returns cells that should be highlighted (same word as selected)
    func isHighlighted(row: Int, col: Int) -> Bool {
        guard let clue = selectedClue else { return false }
        return clue.cellPositions.contains { $0.row == row && $0.col == col }
    }

    /// Returns whether a cell is currently selected
    func isSelected(row: Int, col: Int) -> Bool {
        return row == selectedRow && col == selectedCol
    }
}
