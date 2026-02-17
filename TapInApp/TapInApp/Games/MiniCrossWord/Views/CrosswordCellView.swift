//
//  CrosswordCellView.swift
//  TapInApp
//
//  MARK: - View Layer
//  Renders a single cell in the crossword grid.
//

import SwiftUI

/// Individual cell rendering for the crossword grid
struct CrosswordCellView: View {
    let cell: CrosswordCell
    let isSelected: Bool
    let isHighlighted: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        if cell.isBlocked {
            return Color.crosswordBlocked(colorScheme)
        }
        if isSelected {
            return Color.crosswordSelected(colorScheme)
        }
        if isHighlighted {
            return Color.crosswordHighlighted(colorScheme)
        }
        if cell.isRevealed {
            return Color.crosswordRevealed(colorScheme)
        }
        if cell.isIncorrect {
            return Color.crosswordIncorrect(colorScheme)
        }
        return Color.crosswordCellBackground(colorScheme)
    }

    private var borderColor: Color {
        if cell.isBlocked {
            return Color.crosswordBlocked(colorScheme)
        }
        return Color.crosswordBorder(colorScheme)
    }

    private var textColor: Color {
        if cell.isRevealed {
            return Color.crosswordRevealedText(colorScheme)
        }
        return Color.crosswordText(colorScheme)
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                // Background
                Rectangle()
                    .fill(backgroundColor)
                    .overlay(
                        Rectangle()
                            .stroke(borderColor, lineWidth: 1)
                    )

                // Clue number
                if let number = cell.clueNumber {
                    Text("\(number)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.crosswordClueNumber(colorScheme))
                        .padding(2)
                }

                // Letter
                if let letter = cell.letter {
                    Text(String(letter))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(cell.isBlocked)
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Preview
#Preview {
    HStack {
        CrosswordCellView(
            cell: CrosswordCell(row: 0, col: 0, correctLetter: "A", clueNumber: 1),
            isSelected: true,
            isHighlighted: false,
            colorScheme: .light,
            onTap: {}
        )
        .frame(width: 50, height: 50)

        CrosswordCellView(
            cell: CrosswordCell(row: 0, col: 1, letter: "B", correctLetter: "B"),
            isSelected: false,
            isHighlighted: true,
            colorScheme: .light,
            onTap: {}
        )
        .frame(width: 50, height: 50)

        CrosswordCellView(
            cell: CrosswordCell(row: 0, col: 2, isBlocked: true),
            isSelected: false,
            isHighlighted: false,
            colorScheme: .light,
            onTap: {}
        )
        .frame(width: 50, height: 50)
    }
    .padding()
}
