//
//  WordleGameView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/20/26.
//
//  MARK: - View Layer (MVVM)
//  This is the main entry view for the Wordle game.
//  It orchestrates all subviews and manages navigation state.
//

import SwiftUI

// MARK: - Wordle Game View
/// Main entry view for the Wordle game integrated into TapInApp.
struct WordleGameView: View {
    // MARK: - Properties

    /// Closure to dismiss this view and return to games list
    var onDismiss: () -> Void

    /// Called when the game ends with a result (true = won, false = lost)
    var onGameComplete: ((Bool) -> Void)? = nil

    // MARK: - Environment
    @Environment(\.colorScheme) var colorScheme

    // MARK: - State

    /// The game ViewModel - central source of truth for game state
    @State private var viewModel = GameViewModel()

    /// Whether the archive sheet is currently presented
    @State private var showArchive = false

    /// Whether the game over overlay is visible
    @State private var showGameOverOverlay = true

    /// Whether the standalone leaderboard sheet is shown
    @State private var showLeaderboard = false

    // MARK: - Leaderboard State

    /// Leaderboard entries for the current puzzle
    @State private var leaderboardEntries: [LeaderboardEntryResponse] = []

    /// Full leaderboard entries (up to 10, for the dedicated view)
    @State private var fullLeaderboardEntries: [LeaderboardEntryResponse] = []

    /// Whether the leaderboard is currently loading
    @State private var isLoadingLeaderboard = false

    /// Whether the full leaderboard is loading
    @State private var isLoadingFullLeaderboard = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background color - adaptive for dark mode
            Color.wordleBackground(colorScheme)
                .ignoresSafeArea()

            // Main content stack
            VStack(spacing: 0) {
                // Header with navigation controls
                HeaderView(
                    isArchiveMode: viewModel.isArchiveMode,
                    currentDate: viewModel.formattedCurrentDate,
                    onArchiveTap: { showArchive = true },
                    onLeaderboardTap: {
                        fetchFullLeaderboard()
                        showLeaderboard = true
                    },
                    onBackToToday: {
                        viewModel.loadTodaysGame()
                        showGameOverOverlay = true
                    },
                    onBack: onDismiss,
                    colorScheme: colorScheme
                )

                // Game grid - centered in available space
                Spacer(minLength: 10)

                GameGridView(grid: viewModel.grid, revealingRow: viewModel.revealingRow, colorScheme: colorScheme)
                    .padding(.horizontal, 20)
                    .fixedSize()

                Spacer(minLength: 10)

                // Keyboard for input
                KeyboardView(
                    onKeyTap: { letter in viewModel.addLetter(letter) },
                    onDelete: { viewModel.deleteLetter() },
                    onEnter: { viewModel.submitGuess() },
                    getKeyState: { viewModel.getKeyState(for: $0) },
                    isDisabled: viewModel.isReadOnly || viewModel.isRevealing,
                    colorScheme: colorScheme
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            // Game over sheet (slides up from bottom)
            if viewModel.gameState != .playing && !viewModel.isRevealing && showGameOverOverlay {
                GameOverView(
                    gameState: viewModel.gameState,
                    targetWord: viewModel.targetWord,
                    attempts: viewModel.gameState == .won ? viewModel.currentRow + 1 : viewModel.currentRow,
                    isArchiveMode: viewModel.isArchiveMode,
                    isTodayCompleted: viewModel.isTodayCompleted,
                    leaderboardEntries: leaderboardEntries,
                    assignedUsername: viewModel.assignedUsername,
                    isLoadingLeaderboard: isLoadingLeaderboard,
                    onPlayToday: {
                        viewModel.loadTodaysGame()
                        leaderboardEntries = []
                        showGameOverOverlay = true
                    },
                    onBrowseArchive: { showArchive = true },
                    onDismiss: { showGameOverOverlay = false },
                    onBack: onDismiss,
                    colorScheme: colorScheme
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showGameOverOverlay)
            }
        }
        // Invalid word alert
        .alert("Not in word list", isPresented: $viewModel.showInvalidWordAlert) {
            Button("OK", role: .cancel) { }
        }
        // Leaderboard sheet
        .sheet(isPresented: $showLeaderboard) {
            WordleLeaderboardView(
                entries: fullLeaderboardEntries,
                assignedUsername: viewModel.assignedUsername,
                isLoading: isLoadingFullLeaderboard,
                onDismiss: { showLeaderboard = false }
            )
        }
        // Archive sheet
        .sheet(isPresented: $showArchive) {
            ArchiveView(
                onSelectDate: { date in
                    viewModel.loadGameForDate(date)
                    leaderboardEntries = []  // Clear leaderboard for new game
                    showGameOverOverlay = true  // Reset overlay when loading new game
                    showArchive = false
                },
                onDismiss: { showArchive = false }
            )
        }
        // Fetch leaderboard on appear if game already won (e.g. returning to completed game)
        .onAppear {
            if viewModel.gameState == .won && !viewModel.isArchiveMode && leaderboardEntries.isEmpty {
                fetchLeaderboard()
            }
        }
        // Fetch leaderboard when game ends with a win
        .onChange(of: viewModel.gameState) { oldState, newState in
            if newState == .won && !viewModel.isArchiveMode {
                fetchLeaderboard()
                onGameComplete?(true)
            } else if newState == .lost && !viewModel.isArchiveMode {
                onGameComplete?(false)
            }
        }
    }

    // MARK: - Leaderboard Methods

    /// Fetches the leaderboard for the current puzzle date (top 5, for game over view)
    private func fetchLeaderboard() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let puzzleDate = dateFormatter.string(from: viewModel.currentDate)

        isLoadingLeaderboard = true

        Task {
            do {
                let entries = try await LeaderboardService.shared.fetchLeaderboard(for: puzzleDate)
                await MainActor.run {
                    leaderboardEntries = entries
                    isLoadingLeaderboard = false
                }
            } catch {
                #if DEBUG
                print("Failed to fetch leaderboard: \(error)")
                #endif
                await MainActor.run {
                    isLoadingLeaderboard = false
                }
            }
        }
    }

    /// Fetches the full leaderboard (up to 10 entries, for the dedicated leaderboard view)
    private func fetchFullLeaderboard() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let puzzleDate = dateFormatter.string(from: viewModel.currentDate)

        isLoadingFullLeaderboard = true

        Task {
            do {
                let entries = try await LeaderboardService.shared.fetchLeaderboard(for: puzzleDate, limit: 10)
                await MainActor.run {
                    fullLeaderboardEntries = entries
                    isLoadingFullLeaderboard = false
                }
            } catch {
                #if DEBUG
                print("Failed to fetch full leaderboard: \(error)")
                #endif
                await MainActor.run {
                    isLoadingFullLeaderboard = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    WordleGameView(onDismiss: {})
}
