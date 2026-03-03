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
                // Grid background cells with snap animation
                ForEach(0..<viewModel.gridSize, id: \.self) { row in
                    ForEach(0..<viewModel.gridSize, id: \.self) { col in
                        let pos = PipePosition(row: row, col: col)
                        let color = viewModel.grid[row][col]
                        let isRecentlyFilled = viewModel.recentlyFilledCells.contains(pos)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(cellFill(color: color))
                            .frame(width: cellSize - 3, height: cellSize - 3)
                            .scaleEffect(isRecentlyFilled ? 1.1 : 1.0)
                            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isRecentlyFilled)
                            .position(
                                x: CGFloat(col) * cellSize + cellSize / 2,
                                y: CGFloat(row) * cellSize + cellSize / 2
                            )
                    }
                }

                // Pipe paths with smooth curves
                ForEach(viewModel.currentPuzzle.pairs, id: \.color) { pair in
                    if let path = viewModel.paths[pair.color], path.count >= 2 {
                        smoothPathShape(for: path, cellSize: cellSize)
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

                // Live preview line (follows finger)
                if let activeColor = viewModel.activeColor,
                   let path = viewModel.paths[activeColor],
                   let lastPos = path.last,
                   let livePos = viewModel.liveDrawPosition {

                    let lastPoint = CGPoint(
                        x: CGFloat(lastPos.col) * cellSize + cellSize / 2,
                        y: CGFloat(lastPos.row) * cellSize + cellSize / 2
                    )

                    // Clamp live position to grid bounds
                    let clampedLivePos = CGPoint(
                        x: max(0, min(geometry.size.width, livePos.x)),
                        y: max(0, min(geometry.size.height, livePos.y))
                    )

                    Path { p in
                        p.move(to: lastPoint)
                        p.addLine(to: clampedLivePos)
                    }
                    .stroke(
                        activeColor.displayColor.opacity(0.5),
                        style: StrokeStyle(
                            lineWidth: cellSize * 0.35,
                            lineCap: .round
                        )
                    )

                    // Preview dot at finger position
                    Circle()
                        .fill(activeColor.displayColor.opacity(0.4))
                        .frame(width: cellSize * 0.3, height: cellSize * 0.3)
                        .position(clampedLivePos)
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
                        // Update live draw position for flowing line preview
                        viewModel.liveDrawPosition = value.location

                        // Calculate cell for snapping logic
                        let col = clamp(Int(value.location.x / cellSize), 0, viewModel.gridSize - 1)
                        let row = clamp(Int(value.location.y / cellSize), 0, viewModel.gridSize - 1)
                        viewModel.handleDragAt(row: row, col: col)
                    }
                    .onEnded { _ in
                        viewModel.handleDragEnd()
                    }
            )
            .drawingGroup() // Optimize rendering performance
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Smooth Path Drawing

    /// Creates a smooth path using quadratic curves for a more fluid appearance
    private func smoothPathShape(for positions: [PipePosition], cellSize: CGFloat) -> Path {
        Path { p in
            let points = positions.map { pos -> CGPoint in
                CGPoint(
                    x: CGFloat(pos.col) * cellSize + cellSize / 2,
                    y: CGFloat(pos.row) * cellSize + cellSize / 2
                )
            }

            guard !points.isEmpty else { return }

            p.move(to: points[0])

            if points.count == 2 {
                // Simple line for two points
                p.addLine(to: points[1])
            } else {
                // Use quadratic curves for smoother corners
                for i in 1..<points.count {
                    let prev = points[i - 1]
                    let curr = points[i]

                    // Calculate midpoint for smooth transition
                    let midPoint = CGPoint(
                        x: (prev.x + curr.x) / 2,
                        y: (prev.y + curr.y) / 2
                    )

                    if i == 1 {
                        // First segment: line to midpoint
                        p.addLine(to: midPoint)
                    } else {
                        // Subsequent segments: curve through previous point to midpoint
                        p.addQuadCurve(to: midPoint, control: prev)
                    }

                    if i == points.count - 1 {
                        // Last segment: line to final point
                        p.addLine(to: curr)
                    }
                }
            }
        }
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
