//
//  SudokuGameView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Main container view for the Sudoku game.
//

import SwiftUI

/// Main container view for the Sudoku game.
struct SudokuGameView: View {
    /// Callback when the game view is dismissed
    var onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = SudokuGameViewModel()
    @State private var showDifficultyPicker = false
    @State private var showGameOverOverlay = true

    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                SudokuHeaderView(
                    difficulty: viewModel.difficulty,
                    formattedTime: viewModel.formattedTime,
                    onBack: onDismiss,
                    onDifficultyTap: { showDifficultyPicker = true }
                )

                Spacer()

                // Grid
                SudokuGridView(
                    board: viewModel.board,
                    selectedRow: viewModel.selectedRow,
                    selectedCol: viewModel.selectedCol,
                    onCellTap: { row, col in
                        viewModel.selectCell(row: row, col: col)
                    }
                )
                .padding(.horizontal, 16)

                Spacer()

                // Numpad
                SudokuNumpadView(
                    isNotesMode: viewModel.isNotesMode,
                    onNumberTap: { viewModel.enterNumber($0) },
                    onClearTap: { viewModel.clearSelectedCell() },
                    onNotesTap: { viewModel.toggleNotesMode() },
                    isDisabled: viewModel.gameState != .playing
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            // Game over overlay
            if viewModel.gameState == .won && showGameOverOverlay {
                SudokuGameOverView(
                    elapsedTime: viewModel.formattedTime,
                    difficulty: viewModel.difficulty,
                    errorCount: viewModel.errorCount,
                    onChangeDifficulty: {
                        showGameOverOverlay = false
                        showDifficultyPicker = true
                    },
                    onDismiss: { showGameOverOverlay = false },
                    onBack: onDismiss
                )
            }
        }
        .sheet(isPresented: $showDifficultyPicker) {
            SudokuDifficultyPickerView(
                currentDifficulty: viewModel.difficulty,
                onSelect: { difficulty in
                    viewModel.loadGameForDate(viewModel.currentDate, difficulty: difficulty)
                    showDifficultyPicker = false
                    showGameOverOverlay = true
                }
            )
            .presentationDetents([.medium])
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            viewModel.pauseGame()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.resumeGame()
        }
    }

    // MARK: - Colors

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "#0f1923") : Color(hex: "#f8f9fa")
    }
}

// MARK: - Preview

#Preview {
    SudokuGameView(onDismiss: {})
}
