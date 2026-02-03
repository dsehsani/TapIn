//
//  CrosswordGridView.swift
//  TapInApp
//
//  MARK: - View Layer
//  Renders the 5x5 crossword grid.
//

import SwiftUI

/// Container view for the crossword grid
struct CrosswordGridView: View {
    let grid: [[CrosswordCell]]
    let selectedRow: Int
    let selectedCol: Int
    let highlightedPositions: [(row: Int, col: Int)]
    let colorScheme: ColorScheme
    let onCellTap: (Int, Int) -> Void

    private let spacing: CGFloat = 2

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<grid.count, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<grid[row].count, id: \.self) { col in
                        CrosswordCellView(
                            cell: grid[row][col],
                            isSelected: row == selectedRow && col == selectedCol,
                            isHighlighted: isHighlighted(row: row, col: col),
                            colorScheme: colorScheme,
                            onTap: { onCellTap(row, col) }
                        )
                    }
                }
            }
        }
        .padding(4)
        .background(Color.crosswordBorder(colorScheme))
    }

    private func isHighlighted(row: Int, col: Int) -> Bool {
        highlightedPositions.contains { $0.row == row && $0.col == col }
    }
}

// MARK: - Preview
#Preview {
    let sampleGrid: [[CrosswordCell]] = (0..<5).map { row in
        (0..<5).map { col in
            CrosswordCell(
                row: row,
                col: col,
                isBlocked: (row == 2 && col == 2),
                letter: row == 0 ? Character(["A", "G", "G", "I", "E"][col]) : nil,
                correctLetter: Character(["A", "G", "G", "I", "E"][col]),
                clueNumber: (row == 0 && col == 0) ? 1 : nil
            )
        }
    }

    CrosswordGridView(
        grid: sampleGrid,
        selectedRow: 0,
        selectedCol: 0,
        highlightedPositions: [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)],
        colorScheme: .light,
        onCellTap: { _, _ in }
    )
    .frame(width: 300, height: 300)
    .padding()
}
