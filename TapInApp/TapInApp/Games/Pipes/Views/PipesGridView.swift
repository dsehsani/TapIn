//
//  PipesGridView.swift
//  TapInApp
//

import SwiftUI

struct PipesGridView: View {
    var viewModel: PipesGameViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let cellSize = geometry.size.width / CGFloat(viewModel.gridSize)

            ZStack {
                // Grid background cells
                ForEach(0..<viewModel.gridSize, id: \.self) { row in
                    ForEach(0..<viewModel.gridSize, id: \.self) { col in
                        let color = viewModel.grid[row][col]
                        RoundedRectangle(cornerRadius: 4)
                            .fill(cellFill(color: color))
                            .frame(width: cellSize - 3, height: cellSize - 3)
                            .position(
                                x: CGFloat(col) * cellSize + cellSize / 2,
                                y: CGFloat(row) * cellSize + cellSize / 2
                            )
                    }
                }

                // Pipe paths (thick colored lines through cell centers)
                ForEach(viewModel.currentPuzzle.pairs, id: \.color) { pair in
                    if let path = viewModel.paths[pair.color], path.count >= 2 {
                        Path { p in
                            for (i, pos) in path.enumerated() {
                                let point = CGPoint(
                                    x: CGFloat(pos.col) * cellSize + cellSize / 2,
                                    y: CGFloat(pos.row) * cellSize + cellSize / 2
                                )
                                if i == 0 { p.move(to: point) }
                                else { p.addLine(to: point) }
                            }
                        }
                        .stroke(
                            pair.color.displayColor,
                            style: StrokeStyle(
                                lineWidth: cellSize * 0.45,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }
                }

                // Endpoint dots
                ForEach(viewModel.currentPuzzle.pairs, id: \.color) { pair in
                    endpointCircle(pair.start, color: pair.color, cellSize: cellSize)
                    endpointCircle(pair.end, color: pair.color, cellSize: cellSize)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let col = clamp(Int(value.location.x / cellSize), 0, viewModel.gridSize - 1)
                        let row = clamp(Int(value.location.y / cellSize), 0, viewModel.gridSize - 1)
                        viewModel.handleDragAt(row: row, col: col)
                    }
                    .onEnded { _ in
                        viewModel.handleDragEnd()
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Helpers

    private func cellFill(color: PipeColor?) -> Color {
        if let color = color {
            return color.displayColor.opacity(0.15)
        }
        return colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.90)
    }

    private func endpointCircle(_ pos: PipePosition, color: PipeColor, cellSize: CGFloat) -> some View {
        Circle()
            .fill(color.displayColor)
            .overlay(
                Circle()
                    .fill(color.displayColor.opacity(0.4))
                    .scaleEffect(1.3)
                    .blur(radius: 4)
            )
            .frame(width: cellSize * 0.52, height: cellSize * 0.52)
            .position(
                x: CGFloat(pos.col) * cellSize + cellSize / 2,
                y: CGFloat(pos.row) * cellSize + cellSize / 2
            )
    }

    private func clamp(_ value: Int, _ lo: Int, _ hi: Int) -> Int {
        max(lo, min(hi, value))
    }
}
