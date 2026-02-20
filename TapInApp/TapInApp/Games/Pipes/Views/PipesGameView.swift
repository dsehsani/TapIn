//
//  PipesGameView.swift
//  TapInApp
//

import SwiftUI

struct PipesGameView: View {
    let onDismiss: () -> Void
    @State private var viewModel = PipesGameViewModel()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                header

                Spacer()

                flowStatus

                PipesGridView(viewModel: viewModel)
                    .padding(.horizontal, 16)

                Spacer()

                Text("Moves: \(viewModel.moves)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)

                Spacer()
            }

            if viewModel.gameState == .solved {
                completionOverlay
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                    .frame(width: 36, height: 36)
                    .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Pipes")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                Text("Daily Puzzle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Button(action: { viewModel.resetPuzzle() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                    .frame(width: 36, height: 36)
                    .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Flow Status

    private var flowStatus: some View {
        let connectedCount = viewModel.currentPuzzle.pairs.filter { pair in
            guard let path = viewModel.paths[pair.color], path.count >= 2 else { return false }
            let first = path.first!
            let last = path.last!
            return (first == pair.start && last == pair.end) ||
                   (first == pair.end && last == pair.start)
        }.count
        let total = viewModel.currentPuzzle.pairs.count

        return HStack(spacing: 8) {
            Text("Flows: \(connectedCount)/\(total)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

            let filledCount = viewModel.grid.flatMap { $0 }.compactMap { $0 }.count
            let totalCells = viewModel.gridSize * viewModel.gridSize
            Text("Pipe: \(Int(Double(filledCount) / Double(totalCells) * 100))%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.ucdGold)
        }
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.ucdGold)

                Text("Puzzle Solved!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Completed in \(viewModel.moves) moves")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))

                Text("Come back tomorrow for a new puzzle!")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 16) {
                    Button(action: { viewModel.resetPuzzle() }) {
                        Text("Play Again")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Button(action: onDismiss) {
                        Text("Back to Games")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.ucdBlue)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.ucdGold)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "#0f172a"))
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }
}
