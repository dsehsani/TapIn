//
//  SudokuGameViewModel.swift
//  TapInApp
//
//  MARK: - ViewModel Layer (MVVM)
//  Central game logic and state management for Sudoku.
//

import SwiftUI
import Combine

/// ViewModel for the Sudoku game, managing all game logic and state.
@Observable
class SudokuGameViewModel {

    // MARK: - Constants
    let gridSize = 9
    let boxSize = 3

    // MARK: - Game State
    var board: SudokuBoard = SudokuBoard()
    var gameState: SudokuGameState = .playing
    var difficulty: SudokuDifficulty = .medium
    var currentDate: Date = Date()

    // MARK: - Selection State
    var selectedRow: Int? = nil
    var selectedCol: Int? = nil
    var isNotesMode: Bool = false

    // MARK: - Timer
    var elapsedSeconds: Int = 0
    private var timer: Timer?

    // MARK: - Error Tracking
    var errorCount: Int = 0

    // MARK: - Initialization

    init() {
        loadGameForDate(SudokuGenerator.today, difficulty: .medium)
    }

    // MARK: - Game Loading

    /// Load game for a specific date and difficulty
    func loadGameForDate(_ date: Date, difficulty: SudokuDifficulty) {
        // Stop any existing timer
        stopTimer()

        self.currentDate = date
        self.difficulty = difficulty

        // Check for saved state first
        if let savedState = SudokuStorage.shared.loadGameState(for: date, difficulty: difficulty) {
            restoreFromSavedState(savedState)
        } else {
            // Generate new puzzle
            let (puzzle, solution) = SudokuGenerator.puzzleForDate(date, difficulty: difficulty)
            board = SudokuBoard(puzzle: puzzle, solution: solution)
            gameState = .playing
            elapsedSeconds = 0
            errorCount = 0
        }

        // Clear selection
        selectedRow = nil
        selectedCol = nil
        isNotesMode = false

        // Update cell states and start timer
        updateAllCellStates()

        if gameState == .playing {
            startTimer()
        }
    }

    /// Restore from saved state
    private func restoreFromSavedState(_ state: StoredSudokuState) {
        // Rebuild board from saved state
        var cells: [[SudokuCell]] = []

        for row in 0..<9 {
            var rowCells: [SudokuCell] = []
            for col in 0..<9 {
                let puzzleValue = state.puzzle[row][col]
                let solutionValue = state.solution[row][col]
                let userValue = state.userValues[row][col]
                let isGiven = puzzleValue != 0

                var cell = SudokuCell(
                    row: row,
                    col: col,
                    value: isGiven ? puzzleValue : (userValue != 0 ? userValue : nil),
                    solution: solutionValue,
                    isGiven: isGiven
                )

                // Restore notes
                cell.notes = Set(state.notes[row][col])

                rowCells.append(cell)
            }
            cells.append(rowCells)
        }

        board.cells = cells
        gameState = SudokuGameState(rawValue: state.gameState) ?? .playing
        elapsedSeconds = state.elapsedSeconds
        errorCount = state.errorCount
    }

    // MARK: - Cell Selection

    /// Select a cell at position
    func selectCell(row: Int, col: Int) {
        selectedRow = row
        selectedCol = col
        updateAllCellStates()
    }

    /// Clear selection
    func clearSelection() {
        selectedRow = nil
        selectedCol = nil
        updateAllCellStates()
    }

    // MARK: - Input Handling

    /// Enter a number (1-9) in selected cell
    func enterNumber(_ number: Int) {
        guard let row = selectedRow, let col = selectedCol else { return }
        guard !board[row, col].isGiven else { return }
        guard gameState == .playing else { return }

        if isNotesMode {
            toggleNote(number, at: row, col: col)
        } else {
            placeValue(number, at: row, col: col)
        }

        saveCurrentState()
    }

    /// Place a value in a cell
    private func placeValue(_ value: Int, at row: Int, col: Int) {
        // Clear any notes
        board[row, col].notes.removeAll()

        // Set the value
        board[row, col].value = value

        // Check for errors
        if !board.isValidPlacement(value, at: row, col: col) {
            board[row, col].isShowingError = true
            errorCount += 1

            // Auto-clear error animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.board[row, col].isShowingError = false
            }
        }

        updateAllCellStates()
        checkWinCondition()
    }

    /// Toggle a note in a cell
    private func toggleNote(_ number: Int, at row: Int, col: Int) {
        // Clear value if exists
        board[row, col].value = nil

        // Toggle the note
        if board[row, col].notes.contains(number) {
            board[row, col].notes.remove(number)
        } else {
            board[row, col].notes.insert(number)
        }

        updateAllCellStates()
    }

    /// Clear the selected cell
    func clearSelectedCell() {
        guard let row = selectedRow, let col = selectedCol else { return }
        guard !board[row, col].isGiven else { return }
        guard gameState == .playing else { return }

        board[row, col].value = nil
        board[row, col].notes.removeAll()

        updateAllCellStates()
        saveCurrentState()
    }

    /// Toggle notes mode
    func toggleNotesMode() {
        isNotesMode.toggle()
    }

    // MARK: - Cell State Updates

    /// Update visual states for all cells
    private func updateAllCellStates() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                board[row, col].state = computeCellState(row: row, col: col)
            }
        }
    }

    /// Compute the visual state for a cell
    private func computeCellState(row: Int, col: Int) -> SudokuCellState {
        let cell = board[row, col]

        // Check if selected
        if row == selectedRow && col == selectedCol {
            return .selected
        }

        // Given cells that aren't selected
        if cell.isGiven {
            // Check if same number as selected
            if let selRow = selectedRow, let selCol = selectedCol {
                let selectedValue = board[selRow, selCol].value
                if let selValue = selectedValue, cell.value == selValue {
                    return .sameNumber
                }
            }
            return .given
        }

        // Check selection-based highlighting
        if let selRow = selectedRow, let selCol = selectedCol {
            let selectedValue = board[selRow, selCol].value

            // Same number highlighting
            if let selValue = selectedValue, let cellValue = cell.value, cellValue == selValue {
                return .sameNumber
            }

            // Same row/col/box highlighting
            let selectedBox = board[selRow, selCol].boxIndex
            if row == selRow || col == selCol || cell.boxIndex == selectedBox {
                return .highlighted
            }
        }

        // Check for conflicts (errors)
        if let value = cell.value, !board.isValidPlacement(value, at: row, col: col) {
            return .error
        }

        // User filled or empty
        return cell.value != nil ? .userFilled : .empty
    }

    // MARK: - Win Condition

    /// Check if puzzle is solved
    private func checkWinCondition() {
        if board.isSolved {
            gameState = .won
            stopTimer()
            saveCurrentState()
        }
    }

    // MARK: - Timer Management

    func startTimer() {
        guard gameState == .playing else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func pauseGame() {
        if gameState == .playing {
            gameState = .paused
            stopTimer()
            saveCurrentState()
        }
    }

    func resumeGame() {
        if gameState == .paused {
            gameState = .playing
            startTimer()
        }
    }

    // MARK: - Persistence

    private func saveCurrentState() {
        SudokuStorage.shared.saveGameState(
            for: currentDate,
            difficulty: difficulty,
            board: board,
            gameState: gameState,
            elapsedSeconds: elapsedSeconds,
            errorCount: errorCount
        )
    }

    // MARK: - Computed Properties

    /// Formatted time string (M:SS or MM:SS)
    var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted current date for display
    var formattedCurrentDate: String {
        SudokuGenerator.formatDate(currentDate)
    }

    /// Progress percentage (0.0 to 1.0)
    var progress: Double {
        board.progress
    }

    /// Whether the selected cell can be edited
    var canEditSelectedCell: Bool {
        guard let row = selectedRow, let col = selectedCol else { return false }
        return !board[row, col].isGiven && gameState == .playing
    }
}
