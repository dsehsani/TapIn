//
//  SudokuCellView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Individual cell in the Sudoku grid.
//

import SwiftUI

/// View for a single Sudoku cell.
struct SudokuCellView: View {
    let cell: SudokuCell
    let cellSize: CGFloat
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                Rectangle()
                    .fill(cell.state.backgroundColor(for: colorScheme))

                // Content: Value or Notes
                if let value = cell.value {
                    // Main number
                    Text("\(value)")
                        .font(.system(size: cellSize * 0.55, weight: cell.isGiven ? .bold : .medium, design: .rounded))
                        .foregroundColor(textColor)
                } else if !cell.notes.isEmpty {
                    // Notes grid (3x3)
                    notesGrid
                }
            }
            .frame(width: cellSize, height: cellSize)
            .scaleEffect(cell.isShowingError ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: cell.isShowingError)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Text Color

    private var textColor: Color {
        switch cell.state {
        case .given:
            return colorScheme == .dark ? .white : Color.ucdBlue
        case .error:
            return .red
        case .selected:
            return colorScheme == .dark ? .white : Color.ucdBlue
        case .sameNumber:
            return Color.ucdBlue
        default:
            return colorScheme == .dark ? .white : .black
        }
    }

    // MARK: - Notes Grid

    private var notesGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { col in
                        let number = row * 3 + col + 1
                        Text(cell.notes.contains(number) ? "\(number)" : " ")
                            .font(.system(size: cellSize * 0.2, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: cellSize / 3, height: cellSize / 3)
                    }
                }
            }
        }
    }
}
