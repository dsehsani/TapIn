//
//  GameOverView.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/20/26.
//
//  MARK: - View Layer (MVVM)
//  This view displays the game over overlay with results and navigation options.
//  It appears when the player wins or loses, providing feedback and next actions.
//
//  Integration Notes:
//  - Used by ContentView as a modal overlay
//  - Displays different content based on win/loss and archive mode
//  - Provides navigation to archive or today's game
//  - Shows leaderboard ranking on win
//  - Can be dismissed by tapping the background
//

import SwiftUI

// MARK: - Game Over View
/// Displays the game over overlay with results and navigation options.
///
/// Content varies based on:
/// - Win vs Loss: Different icons, messages, and details
/// - Archive mode: Different action button options
/// - Today's completion: Adjusts messaging and options
/// - Leaderboard: Shows top 5 players on win
///
/// Layout:
/// - Semi-transparent backdrop (tappable to dismiss)
/// - Centered card with icon, message, leaderboard, and action buttons
///
struct GameOverView: View {
    // MARK: - Properties

    /// The final game state (won or lost)
    let gameState: GameState

    /// The target word (revealed on loss)
    let targetWord: String

    /// Number of guesses used (displayed on win)
    let attempts: Int

    /// Whether viewing an archived game
    let isArchiveMode: Bool

    /// Whether today's game has been completed
    let isTodayCompleted: Bool

    // MARK: - Leaderboard Properties

    /// Top 5 leaderboard entries for this puzzle
    var leaderboardEntries: [LeaderboardEntryResponse] = []

    /// The username assigned to the current player (if score was submitted)
    var assignedUsername: String? = nil

    /// Whether the leaderboard is currently loading
    var isLoadingLeaderboard: Bool = false

    // MARK: - Callbacks

    /// Called when "Play Today's Word" is tapped
    let onPlayToday: () -> Void

    /// Called when "Play Previous Weeks" is tapped
    let onBrowseArchive: () -> Void

    /// Called when the backdrop is tapped (dismiss overlay)
    let onDismiss: () -> Void

    /// Called when "Back" is tapped (placeholder for future use)
    let onBack: () -> Void

    /// Color scheme for dark mode support
    var colorScheme: ColorScheme = .light

    // MARK: - Computed Properties

    private var accentColor: Color {
        Color.adaptiveAccent(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "#1a1a2e") : .white
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(colorScheme == .dark ? 0.6 : 0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Result card
            VStack(spacing: 20) {
                // Result icon
                resultIcon

                // Title
                Text(gameState == .won ? "Congratulations!" : "Game Over")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)

                // Result details
                resultDetails

                // Leaderboard section (only shown on win with data)
                if gameState == .won && !isArchiveMode {
                    leaderboardSection
                }

                // Action buttons
                actionButtons
                    .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackground)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 20)
            )
            .padding(40)
        }
    }

    // MARK: - Subviews

    /// Icon showing win (checkmark) or loss (X)
    private var resultIcon: some View {
        Image(systemName: gameState == .won ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 60))
            .foregroundColor(gameState == .won ? .wordleGreen : .ucdGold)
    }

    /// Details about the result (attempts for win, word for loss)
    @ViewBuilder
    private var resultDetails: some View {
        if gameState == .won {
            // Show number of guesses on win
            Text("Solved in \(attempts) \(attempts == 1 ? "guess" : "guesses")")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        } else {
            // Reveal the target word on loss
            VStack(spacing: 4) {
                Text("The word was")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                Text(targetWord)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
            }
        }
    }

    /// Leaderboard section showing top 5 players
    @ViewBuilder
    private var leaderboardSection: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.ucdGold)
                Text("Today's Leaderboard")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(accentColor)
            }

            if isLoadingLeaderboard {
                // Loading state
                ProgressView()
                    .padding(.vertical, 8)
            } else if leaderboardEntries.isEmpty {
                // No entries yet
                Text("Be the first to complete today's puzzle!")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                // Leaderboard entries
                VStack(spacing: 8) {
                    ForEach(leaderboardEntries) { entry in
                        leaderboardRow(entry: entry)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
        )
    }

    /// Single row in the leaderboard
    private func leaderboardRow(entry: LeaderboardEntryResponse) -> some View {
        let isCurrentUser = assignedUsername != nil && entry.username == assignedUsername

        return HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor(for: entry.rank))
                    .frame(width: 28, height: 28)
                Text("\(entry.rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            // Username
            Text(entry.username)
                .font(.system(size: 15, weight: isCurrentUser ? .bold : .medium, design: .rounded))
                .foregroundColor(isCurrentUser ? accentColor : .primary)

            Spacer()

            // Guesses display (green blocks)
            Text(entry.guessesDisplay)
                .font(.system(size: 14))

            // Time taken
            Text(formatTime(entry.timeSeconds))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentUser ? accentColor.opacity(0.15) : Color.clear)
        )
    }

    /// Returns the color for a rank badge
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .ucdGold        // Gold
        case 2: return Color.gray      // Silver
        case 3: return Color.brown     // Bronze
        default: return Color.gray.opacity(0.5)
        }
    }

    /// Formats seconds into a readable time string (e.g., "1:23")
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Action buttons based on context
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isArchiveMode {
                // Archive mode: offer to play today if not completed
                archiveModeButtons
            } else {
                // Today's game completed: offer to browse archive
                todayModeButtons
            }
        }
    }

    /// Buttons shown when viewing an archived game
    @ViewBuilder
    private var archiveModeButtons: some View {
        // Only show "Play Today" if today isn't completed
        if !isTodayCompleted {
            Button(action: onPlayToday) {
                Text("Play Today's Word")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 48)
                    .background(accentColor)
                    .cornerRadius(24)
            }
        }

        Button(action: onBrowseArchive) {
            Text("Play Previous Weeks")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(accentColor)
        }
    }

    /// Buttons shown when today's game is completed
    @ViewBuilder
    private var todayModeButtons: some View {
        Text("Come back tomorrow for a new word!")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

        Button(action: onBrowseArchive) {
            Text("Play Previous Weeks")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 200, height: 48)
                .background(accentColor)
                .cornerRadius(24)
        }

        Button(action: onBack) {
            Text("Back")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(accentColor)
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        GameOverView(
            gameState: .won,
            targetWord: "BRAIN",
            attempts: 4,
            isArchiveMode: false,
            isTodayCompleted: true,
            onPlayToday: { },
            onBrowseArchive: { },
            onDismiss: { },
            onBack: { }
        )
    }
}
