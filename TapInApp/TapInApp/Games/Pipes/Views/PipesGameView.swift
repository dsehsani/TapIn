//
//  PipesGameView.swift
//  TapInApp
//

import SwiftUI

struct PipesGameView: View {
    let onDismiss: () -> Void
    var onGameComplete: ((Bool) -> Void)? = nil
    @State private var viewModel = PipesGameViewModel()
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("tutorial_seen_pipes") private var hasSeenTutorial = false
    @State private var showStartScreen = true
    @State private var showArchive = false

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 16) {
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

                // Puzzle selector strip
                if !viewModel.dailyPuzzles.isEmpty {
                    puzzleSelectorStrip
                }

                Spacer()

                flowStatus

                PipesGridView(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .allowsHitTesting(!showStartScreen && viewModel.gameState == .playing && !viewModel.alreadyCompletedToday)

                Spacer()

                Text("Moves: \(viewModel.moves)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)

                Spacer()
            }

            // MARK: - Overlays (mutually exclusive, priority order)

            // 1. "Just completed all 5" celebration — user solved the last one this session
            if viewModel.justCompletedAll {
                allCompleteOverlay
            }
            // 2. "Just solved a single puzzle" — user solved one this session, more to go
            else if viewModel.justSolvedPuzzle {
                singlePuzzleCompletionOverlay
            }
            // 3. "Already completed today" — re-entry when all 5 were done previously
            else if viewModel.alreadyCompletedToday {
                alreadyCompletedOverlay
            }
            // 4. Tutorial / start screen — only for fresh day (no progress)
            else if showStartScreen && viewModel.gameState == .playing {
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
                        AnalyticsTracker.shared.track(.pipesPlayed)
                    },
                    onExit: onDismiss,
                    subtitle: viewModel.isArchiveMode ? viewModel.currentDateKey : "Daily Five",
                    showRulesInitially: !hasSeenTutorial
                )
            }
        }
        .task {
            await viewModel.loadDailyFive()

            // Skip tutorial if resuming with existing progress
            if viewModel.hasExistingProgress {
                showStartScreen = false
                // Resume timer if the current puzzle is in-progress
                if viewModel.gameState == .playing && viewModel.gameStartTime != nil {
                    // Timer is already set from restored state — no action needed
                } else if viewModel.gameState == .playing {
                    viewModel.startTimer()
                }
            }
        }
        .sheet(isPresented: $showArchive) {
            PipesArchiveView(
                onSelectDate: { date in
                    showArchive = false
                    showStartScreen = true
                    Task {
                        await viewModel.loadDailyFive(for: date)
                        if viewModel.hasExistingProgress {
                            showStartScreen = false
                        }
                    }
                },
                onDismiss: { showArchive = false }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: {
                viewModel.saveCurrentPuzzleProgress()
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                    .frame(width: 36, height: 36)
                    .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"))
                    .clipShape(Circle())
            }

            // Archive calendar button
            Button(action: {
                viewModel.saveCurrentPuzzleProgress()
                showArchive = true
            }) {
                Image(systemName: "calendar")
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
                Text(headerSubtitle)
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

    private var headerSubtitle: String {
        if viewModel.isArchiveMode {
            return viewModel.currentDateKey
        }
        if viewModel.dailyPuzzles.isEmpty {
            return "Daily Puzzle"
        }
        return "Puzzle \(viewModel.currentPuzzleIndex + 1)/\(viewModel.dailyPuzzles.count)"
    }

    // MARK: - Puzzle Selector Strip

    private var puzzleSelectorStrip: some View {
        HStack(spacing: 12) {
            ForEach(0..<viewModel.dailyPuzzles.count, id: \.self) { index in
                VStack(spacing: 4) {
                    puzzleCircle(at: index)
                        .onTapGesture {
                            if viewModel.puzzleStatuses[index] != .locked {
                                showStartScreen = false
                                viewModel.selectPuzzle(at: index)
                                if viewModel.gameState == .playing && viewModel.gameStartTime == nil {
                                    viewModel.startTimer()
                                }
                            }
                        }

                    if index < viewModel.difficultyLabels.count {
                        Text(viewModel.difficultyLabels[index])
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func puzzleCircle(at index: Int) -> some View {
        let status = viewModel.puzzleStatuses[index]
        let isActive = index == viewModel.currentPuzzleIndex

        return ZStack {
            Circle()
                .fill(circleBackground(for: status))
                .frame(width: 40, height: 40)

            if isActive {
                Circle()
                    .strokeBorder(Color.ucdGold, lineWidth: 3)
                    .frame(width: 44, height: 44)
            }

            switch status {
            case .completed:
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            case .locked:
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            case .available, .inProgress:
                Text("\(index + 1)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
            }
        }
    }

    private func circleBackground(for status: PipesPuzzleStatus) -> Color {
        switch status {
        case .completed: return .green
        case .locked: return colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#e2e8f0")
        case .available: return colorScheme == .dark ? Color(hex: "#2d3748") : Color(hex: "#f1f5f9")
        case .inProgress: return colorScheme == .dark ? Color(hex: "#2d3748") : Color(hex: "#f1f5f9")
        }
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

    // MARK: - Single Puzzle Completion Overlay (just solved this session)

    private var singlePuzzleCompletionOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.ucdGold)

                Text("Puzzle \(viewModel.currentPuzzleIndex + 1) Solved!")
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

                Text("\(viewModel.dailyCompletedCount)/\(viewModel.dailyPuzzles.count) puzzles complete")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 16) {
                    if viewModel.currentPuzzleIndex + 1 < viewModel.dailyPuzzles.count {
                        Button(action: {
                            viewModel.goToNextPuzzle()
                        }) {
                            Text("Next Puzzle")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.ucdBlue)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(Color.ucdGold)
                                .clipShape(Capsule())
                        }
                    }

                    Button(action: {
                        viewModel.saveCurrentPuzzleProgress()
                        onDismiss()
                    }) {
                        Text("Back to Games")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
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

    // MARK: - All Complete Overlay (just finished the 5th puzzle this session)

    private var allCompleteOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.ucdGold)

                Text("All 5 Complete!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("You solved all today's Pipes puzzles!")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))

                Button(action: {
                    onGameComplete?(true)
                    onDismiss()
                }) {
                    Text("Back to Games")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.ucdBlue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.ucdGold)
                        .clipShape(Capsule())
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

    // MARK: - Already Completed Today (re-entry overlay)

    private var alreadyCompletedOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.ucdGold)

                Text("Today's Puzzles Complete")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("You've already solved all 5 of today's puzzles. Come back tomorrow for a new set!")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button(action: {
                        viewModel.saveCurrentPuzzleProgress()
                        showArchive = true
                        viewModel.alreadyCompletedToday = false
                    }) {
                        Text("View Archive")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.ucdBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ucdGold)
                            .clipShape(Capsule())
                    }

                    Button(action: onDismiss) {
                        Text("Back to Games")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
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
