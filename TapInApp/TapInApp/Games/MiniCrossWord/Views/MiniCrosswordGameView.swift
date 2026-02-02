//
//  MiniCrosswordGameView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Main entry view for the MiniCrossword game.
//

import SwiftUI

/// Main entry view for the MiniCrossword game
struct MiniCrosswordGameView: View {
    var onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = CrosswordViewModel()
    @State private var showCompletionOverlay = true

    var body: some View {
        ZStack {
            // Background
            Color.crosswordBackground(colorScheme)
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Header
                CrosswordHeaderView(
                    formattedTime: viewModel.formattedTime,
                    onBack: onDismiss,
                    onCheck: { viewModel.checkAnswers() },
                    onRevealCell: { viewModel.revealCell() },
                    onRevealWord: { viewModel.revealWord() },
                    onRevealPuzzle: { viewModel.revealPuzzle() },
                    colorScheme: colorScheme
                )

                Spacer(minLength: 8)

                // Current clue display
                if let clue = viewModel.selectedClue {
                    CurrentClueView(clue: clue, colorScheme: colorScheme)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 8)

                // Grid
                CrosswordGridView(
                    grid: viewModel.grid,
                    selectedRow: viewModel.selectedRow,
                    selectedCol: viewModel.selectedCol,
                    highlightedPositions: viewModel.selectedClue?.cellPositions ?? [],
                    colorScheme: colorScheme,
                    onCellTap: { row, col in
                        viewModel.selectCell(row: row, col: col)
                    }
                )
                .frame(maxWidth: 320, maxHeight: 320)
                .padding(.horizontal, 16)

                Spacer(minLength: 8)

                // Clue list
                ClueListView(
                    puzzle: viewModel.currentPuzzle,
                    selectedClue: viewModel.selectedClue,
                    onSelectClue: { clue in
                        viewModel.selectClue(clue)
                    },
                    colorScheme: colorScheme
                )
                .frame(height: 140)
                .padding(.horizontal, 8)

                Spacer(minLength: 8)

                // Keyboard
                CrosswordKeyboardView(
                    onKeyTap: { letter in
                        viewModel.inputLetter(letter)
                    },
                    onDelete: {
                        viewModel.deleteLetter()
                    },
                    isDisabled: viewModel.gameState == .completed,
                    colorScheme: colorScheme
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            // Completion overlay
            if viewModel.gameState == .completed && showCompletionOverlay {
                CrosswordCompletionView(
                    elapsedSeconds: viewModel.elapsedSeconds,
                    onDismiss: { showCompletionOverlay = false },
                    onBack: onDismiss,
                    colorScheme: colorScheme
                )
            }
        }
    }
}

/// Displays the currently selected clue
struct CurrentClueView: View {
    let clue: CrosswordClue
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            Text("\(clue.number)\(clue.direction == .across ? "A" : "D").")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.ucdGold)

            Text(clue.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.crosswordText(colorScheme))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.crosswordClueBackground(colorScheme))
        )
    }
}

// MARK: - Preview
#Preview {
    MiniCrosswordGameView(onDismiss: {})
}
