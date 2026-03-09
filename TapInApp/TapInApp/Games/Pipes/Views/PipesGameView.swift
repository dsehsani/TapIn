//
//  PipesGameView.swift
//  TapInApp
//

import SwiftUI
import AudioToolbox

struct PipesGameView: View {
    let onDismiss: () -> Void
    var onGameComplete: ((Bool) -> Void)? = nil
    @State private var viewModel = PipesGameViewModel()
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("tutorial_seen_pipes") private var hasSeenTutorial = false
    @State private var showStartScreen = true
    @State private var showArchive = false
    @State private var showSolvedToast = false
    @State private var showExitDialog = false
    @State private var hasShownExitDialog = false
    @State private var pipesLeaderboardEntries: [PipesLeaderboardEntryResponse] = []
    @State private var isLoadingPipesLeaderboard = false

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            if viewModel.isLoadingPuzzle {
                VStack(spacing: 16) {
                    header
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(Color.ucdGold)
                    Text("Loading today's puzzles...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
            VStack(spacing: 16) {
                header

                // Cumulative timer — always runs from sessionStartTime when active.
                // Only falls back to static gameDurationSeconds on the all-complete screen.
                if let startTime = viewModel.sessionStartTime, !viewModel.justCompletedAll {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = Int(context.date.timeIntervalSince(startTime))
                        let minutes = elapsed / 60
                        let seconds = elapsed % 60
                        Text(String(format: "%d:%02d", minutes, seconds))
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.justCompletedAll && viewModel.gameDurationSeconds > 0 {
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

                if viewModel.didExitGame && !viewModel.isArchiveMode {
                    HStack(spacing: 5) {
                        Image(systemName: "trophy.slash.fill")
                            .font(.system(size: 11))
                        Text("Not eligible for leaderboard")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.orange.opacity(0.85)))
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
            }

            // MARK: - Overlays (mutually exclusive, priority order)

            // 1. "Just completed all 5" celebration — user solved the last one this session
            if !viewModel.isLoadingPuzzle && viewModel.justCompletedAll {
                allCompleteOverlay
            }
            // 2. "Just solved a single puzzle" — brief toast, then auto-advance
            if showSolvedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.ucdGold)
                        Text("Puzzle \(viewModel.currentPuzzleIndex + 1) Solved!")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(hex: "#1e293b") : .white)
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                    )
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
            // 3. "Already completed today" — re-entry when all 5 were done previously
            else if !viewModel.isLoadingPuzzle && viewModel.alreadyCompletedToday {
                alreadyCompletedOverlay
            }
            // 4. Tutorial / start screen — only for fresh day (no progress)
            else if !viewModel.isLoadingPuzzle && showStartScreen && viewModel.gameState == .playing {
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
                if viewModel.gameState == .playing {
                    if viewModel.gameStartTime != nil {
                        viewModel.resumeSession()  // Reconstruct sessionStartTime from saved times
                    } else {
                        viewModel.startTimer()
                    }
                }
            }
        }
        .overlay {
            if showExitDialog {
                LeaveGameDialog(
                    onStay: {
                        hasShownExitDialog = true
                        showExitDialog = false
                    },
                    onLeave: {
                        showExitDialog = false
                        viewModel.markAsExited()
                        viewModel.saveCurrentPuzzleProgress()
                        onDismiss()
                    }
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: showExitDialog)
            }
        }
        .onChange(of: viewModel.justSolvedPuzzle) { _, isSolved in
            guard isSolved else { return }
            // Haptic feedback
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // System success sound
            AudioServicesPlaySystemSound(1057)
            // Show toast briefly then auto-advance
            let hasNext = viewModel.currentPuzzleIndex + 1 < viewModel.dailyPuzzles.count
            if hasNext {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showSolvedToast = true
                }
                // Fix 3: use Task so the closure doesn't retain a strong reference
                // to a potentially dismissed view context
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                    guard viewModel.justSolvedPuzzle || !viewModel.dailyPuzzles.isEmpty else { return }
                    withAnimation(.easeOut(duration: 0.2)) { showSolvedToast = false }
                    viewModel.goToNextPuzzle()
                }
            }
        }
        .onChange(of: viewModel.justCompletedAll) { _, isComplete in
            if isComplete && !viewModel.isArchiveMode {
                fetchPipesLeaderboard()
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
        ZStack {
            // Centered title
            VStack(spacing: 2) {
                Text("Pipes")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                Text(headerSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }

            // Left and right buttons pinned to edges
            HStack {
                HStack(spacing: 8) {
                    Button(action: {
                        let hasActivity = viewModel.moves > 0 || !viewModel.paths.isEmpty
                        let gameStillActive = viewModel.gameState == .playing && !viewModel.isArchiveMode
                        if gameStillActive && hasActivity && !hasShownExitDialog && !viewModel.didExitGame {
                            showExitDialog = true
                        } else {
                            viewModel.saveCurrentPuzzleProgress()
                            onDismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                            .frame(width: 36, height: 36)
                            .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"))
                            .clipShape(Circle())
                    }

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
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var headerSubtitle: String {
        if viewModel.isArchiveMode {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            if let date = df.date(from: viewModel.currentDateKey) {
                let display = DateFormatter()
                display.dateStyle = .medium
                return display.string(from: date)
            }
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


    // MARK: - All Complete Overlay (just finished the 5th puzzle this session)

    private var allCompleteOverlay: some View {
        let cardBg: Color = colorScheme == .dark ? Color(hex: "#141424") : .white
        let muted: Color = colorScheme == .dark ? Color(hex: "#8b8fa3") : Color(hex: "#64748b")
        let textPrimary: Color = colorScheme == .dark ? .white : Color(hex: "#0f172a")

        return ZStack(alignment: .bottom) {
            // Backdrop
            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.25)
                .ignoresSafeArea()

            // Bottom sheet
            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                // Result header
                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 38))
                        .foregroundColor(Color.ucdGold)

                    Text("All 5 Complete!")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)

                    let totalTime = viewModel.gameDurationSeconds > 0 ? viewModel.gameDurationSeconds : viewModel.totalTimeForDay
                    let totalMoves = viewModel.totalMovesForDay
                    let mins = totalTime / 60
                    let secs = totalTime % 60
                    HStack(spacing: 16) {
                        Label("\(totalMoves) moves", systemImage: "arrow.triangle.2.circlepath")
                        Label(String(format: "%d:%02d", mins, secs), systemImage: "clock")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(muted)
                }
                .padding(.bottom, 18)

                // Leaderboard (non-archive only)
                if !viewModel.isArchiveMode {
                    pipesLeaderboardSection(muted: muted, textPrimary: textPrimary)
                        .padding(.bottom, 18)
                }

                // Actions
                VStack(spacing: 10) {
                    if !viewModel.isArchiveMode {
                        Text("Come back tomorrow!")
                            .font(.system(size: 13))
                            .foregroundColor(muted)
                    }
                    Button(action: {
                        viewModel.alreadyCompletedToday = false
                        showArchive = true
                        viewModel.justCompletedAll = false
                    }) {
                        Text("Browse Archive")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ucdBlue))
                    }
                    Button(action: {
                        onGameComplete?(true)
                        onDismiss()
                    }) {
                        Text("Back to Games")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color(hex: "#e2e8f0"), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardBg)
                    .shadow(color: .black.opacity(0.2), radius: 30, y: -5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : .clear, lineWidth: 1)
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.justCompletedAll)
    }

    // MARK: - Pipes Leaderboard Section

    @ViewBuilder
    private func pipesLeaderboardSection(muted: Color, textPrimary: Color) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 5) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.ucdGold)
                Text("LEADERBOARD")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(muted)
            }

            if isLoadingPipesLeaderboard {
                ProgressView()
                    .padding(.vertical, 16)
            } else if pipesLeaderboardEntries.isEmpty {
                Text("No entries yet")
                    .font(.system(size: 13))
                    .foregroundColor(muted)
                    .padding(.vertical, 8)
            } else {
                pipesPodiumView(muted: muted, textPrimary: textPrimary)
                    .padding(.horizontal, 24)

                // Show current user's rank if outside top 3
                if let me = pipesLeaderboardEntries.first(where: {
                    viewModel.assignedUsername != nil && $0.username == viewModel.assignedUsername
                }), me.rank > 3 {
                    HStack(spacing: 8) {
                        Text("#\(me.rank)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.ucdGold)
                        Text(me.username)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(textPrimary)
                        Spacer()
                        Text("\(me.totalMoves)mv")
                            .font(.system(size: 12))
                            .foregroundColor(muted)
                        Text(formatTime(me.totalTimeSeconds))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(muted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.ucdGold.opacity(0.1)))
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    @ViewBuilder
    private func pipesPodiumView(muted: Color, textPrimary: Color) -> some View {
        let top3 = Array(pipesLeaderboardEntries.prefix(3))
        let first = top3.first(where: { $0.rank == 1 })
        let second = top3.first(where: { $0.rank == 2 })
        let third = top3.first(where: { $0.rank == 3 })

        HStack(alignment: .bottom, spacing: 8) {
            if let entry = second {
                pipesPodiumSlot(entry: entry, height: 52, medal: "2", muted: muted, textPrimary: textPrimary)
            } else {
                Spacer().frame(maxWidth: .infinity)
            }
            if let entry = first {
                pipesPodiumSlot(entry: entry, height: 72, medal: "1", muted: muted, textPrimary: textPrimary)
            } else {
                Spacer().frame(maxWidth: .infinity)
            }
            if let entry = third {
                pipesPodiumSlot(entry: entry, height: 40, medal: "3", muted: muted, textPrimary: textPrimary)
            } else {
                Spacer().frame(maxWidth: .infinity)
            }
        }
    }

    private func pipesPodiumSlot(entry: PipesLeaderboardEntryResponse, height: CGFloat, medal: String, muted: Color, textPrimary: Color) -> some View {
        let isMe = viewModel.assignedUsername != nil && entry.username == viewModel.assignedUsername
        let podiumColor: Color = {
            switch entry.rank {
            case 1: return Color.ucdGold
            case 2: return Color(hex: "#94a3b8")
            case 3: return Color(hex: "#b45309")
            default: return Color.gray
            }
        }()

        return VStack(spacing: 0) {
            Text(entry.username)
                .font(.system(size: 11, weight: isMe ? .bold : .semibold))
                .foregroundColor(isMe ? Color.ucdGold : textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.bottom, 4)

            Text("\(entry.totalMoves)mv")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(muted)
                .padding(.bottom, 6)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(podiumColor.opacity(colorScheme == .dark ? 0.3 : 0.15))

                VStack(spacing: 2) {
                    Text(medal)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(podiumColor)
                    Text(formatTime(entry.totalTimeSeconds))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(muted)
                }
            }
            .frame(height: height)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Leaderboard Fetch

    private func fetchPipesLeaderboard() {
        isLoadingPipesLeaderboard = true
        Task {
            do {
                let entries = try await LeaderboardService.shared.fetchPipesLeaderboard(for: viewModel.currentDateKey, limit: 5)
                await MainActor.run {
                    pipesLeaderboardEntries = entries
                    isLoadingPipesLeaderboard = false
                }
            } catch {
                await MainActor.run {
                    isLoadingPipesLeaderboard = false
                }
            }
        }
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
