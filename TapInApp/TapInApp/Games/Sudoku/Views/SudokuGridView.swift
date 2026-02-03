//
//  SudokuGridView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  9x9 Sudoku grid with 3x3 box divisions.
//

import SwiftUI

/// View for the complete 9x9 Sudoku grid.
struct SudokuGridView: View {
    let board: SudokuBoard
    let selectedRow: Int?
    let selectedCol: Int?
    let onCellTap: (Int, Int) -> Void

    @Environment(\.colorScheme) var colorScheme

    // Calculate cell size based on screen width
    private var cellSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let gridWidth = screenWidth - 32 // Horizontal padding
        let availableWidth = gridWidth - 6 // Thick borders (3pt * 2)
        return (availableWidth - 6) / 9 // 9 cells with thin borders
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { boxRow in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { boxCol in
                        // 3x3 box
                        boxView(boxRow: boxRow, boxCol: boxCol)

                        // Thick vertical divider between boxes
                        if boxCol < 2 {
                            Rectangle()
                                .fill(thickBorderColor)
                                .frame(width: 3)
                        }
                    }
                }

                // Thick horizontal divider between boxes
                if boxRow < 2 {
                    Rectangle()
                        .fill(thickBorderColor)
                        .frame(height: 3)
                }
            }
        }
        .background(thickBorderColor)
        .cornerRadius(8)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 4)
    }

    // MARK: - Box View

    @ViewBuilder
    private func boxView(boxRow: Int, boxCol: Int) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { localRow in
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { localCol in
                        let row = boxRow * 3 + localRow
                        let col = boxCol * 3 + localCol

                        SudokuCellView(
                            cell: board[row, col],
                            cellSize: cellSize,
                            onTap: { onCellTap(row, col) }
                        )
                    }
                }
            }
        }
        .background(thinBorderColor)
    }

    // MARK: - Colors

    private var thickBorderColor: Color {
        colorScheme == .dark ? Color(hex: "#555555") : Color(hex: "#333333")
    }

    private var thinBorderColor: Color {
        colorScheme == .dark ? Color(hex: "#444444") : Color(hex: "#cccccc")
    }
}
