//
//  PipesGameView.swift
//  TapInApp
//

import SwiftUI

struct PipesGameView: View {
    let onDismiss: () -> Void
    @State private var viewModel = PipesGameViewModel()
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("tutorial_seen_pipes") private var hasSeenTutorial = false
    @State private var showStartScreen = true

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                header

                // Live timer
                if viewModel.gameState == .playing, let startTime = viewModel.gameStartTime {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = Int(context.date.timeIntervalSince(startTime))
                        let minutes = elapsed / 60
                        let seconds = elapsed % 60
                        Text(String(format: "%d:%02d", minutes, seconds))
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.gameState == .solved && viewModel.gameDurationSeconds > 0 {
                    let minutes = viewModel.gameDurationSeconds / 60
                    let seconds = viewModel.gameDurationSeconds % 60
                    Text(String(format: "%d:%02d", minutes, seconds))
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                flowStatus

                PipesGridView(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .allowsHitTesting(!showStartScreen)

                Spacer()

                Text("Moves: \(viewModel.moves)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)

                Spacer()
            }

            if viewModel.gameState == .solved {
                completionOverlay
            }

            // Loading overlay (when fetching puzzle from backend)
            if viewModel.isLoadingPuzzle {
                loadingOverlay
            }

            // Start screen / tutorial overlay
            if showStartScreen && viewModel.gameState == .playing {
                GameTutorialOverlay(
                    gameName: "Pipes",
                    gameIcon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                    accentColor: Color.ucdGold,
                    rules: [
                        (icon: "circle.circle.fill", text: "Connect matching colored dots by drawing paths."),
                        (icon: "square.grid.3x3.fill", text: "Fill every cell on the board."),
                        (icon: "xmark.circle", text: "Paths cannot cross each other."),
                        (icon: "hand.draw", text: "Drag from a dot to draw its path.")
                    ],
                    onStart: {
                        hasSeenTutorial = true
                        withAnimation(.easeOut(duration: 0.3)) {
                            showStartScreen = false
                        }
                        viewModel.startTimer()
                    },
                    onExit: onDismiss,
                    subtitle: "Daily Puzzle",
                    showRulesInitially: !hasSeenTutorial
                )
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

                if viewModel.gameDurationSeconds > 0 {
                    let minutes = viewModel.gameDurationSeconds / 60
                    let seconds = viewModel.gameDurationSeconds % 60
                    Text("Completed in \(String(format: "%d:%02d", minutes, seconds)) · \(viewModel.moves) moves")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("Completed in \(viewModel.moves) moves")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }

                Text("Come back tomorrow for a new puzzle!")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.resetPuzzle()
                        showStartScreen = true
                    }) {
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

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color.ucdGold)

                Text("Loading today's puzzle...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#0f172a").opacity(0.9))
            )
        }
        .transition(.opacity)
    }
}
