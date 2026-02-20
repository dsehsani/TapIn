//
//  GameOverLeaderboardView.swift
//  TapInApp
//
//  MARK: - Game Over Leaderboard View
//  Overlay shown after game completion displaying leaderboard and user info.
//
//  Integration Notes:
//  - Use this view in place of game-specific completion views
//  - Pass the gameType, result info, and callbacks
//  - Leaderboard data is fetched automatically from LocalLeaderboardService
//

import SwiftUI

/// Game over overlay displaying leaderboard results.
///
/// Shows:
/// - Game result (win/complete message)
/// - Top 5 scores for today
/// - User's display name
/// - User's rank (as 6th entry if not in top 5)
/// - Action buttons (View Game, Back to Games)
///
struct GameOverLeaderboardView: View {

    // MARK: - Properties

    @State private var viewModel: GameOverLeaderboardViewModel

    /// Game-specific result info
    let resultTitle: String
    let resultSubtitle: String
    let resultIcon: String
    let resultColor: Color

    /// Callbacks
    let onDismiss: () -> Void
    let onBack: () -> Void

    @Environment(\.colorScheme) var colorScheme

    // MARK: - Initialization

    init(
        gameType: GameType,
        gameDate: Date = Date(),
        userScore: LocalScore? = nil,
        resultTitle: String,
        resultSubtitle: String,
        resultIcon: String = "trophy.fill",
        resultColor: Color = .ucdGold,
        onDismiss: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self._viewModel = State(initialValue: GameOverLeaderboardViewModel(
            gameType: gameType,
            gameDate: gameDate,
            userScore: userScore
        ))
        self.resultTitle = resultTitle
        self.resultSubtitle = resultSubtitle
        self.resultIcon = resultIcon
        self.resultColor = resultColor
        self.onDismiss = onDismiss
        self.onBack = onBack
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Main card
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Result header
                    resultHeader

                    // Leaderboard section
                    leaderboardSection

                    // User info blurb
                    userInfoSection

                    // Action buttons
                    actionButtons
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(colorScheme == .dark ? Color(hex: "#1a1a2e") : .white)
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 48)
            }
        }
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: resultIcon)
                .font(.system(size: 48))
                .foregroundColor(resultColor)

            Text(resultTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)

            Text(resultSubtitle)
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Leaderboard Section

    private var leaderboardSection: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.ucdGold)
                Text("Today's Leaderboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)

                Spacer()

                if viewModel.totalPlayers > 0 {
                    Text("\(viewModel.totalPlayers) player\(viewModel.totalPlayers == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .padding(.vertical, 20)
            } else if viewModel.topScores.isEmpty {
                emptyState
            } else {
                // Top 5 scores
                VStack(spacing: 8) {
                    ForEach(viewModel.topScores) { score in
                        LeaderboardRowView(
                            score: score,
                            rank: viewModel.rank(for: score),
                            isCurrentUser: viewModel.isUserScore(score),
                            colorScheme: colorScheme
                        )
                    }

                    // 6th row: User's score if not in top 5
                    if let userScore = viewModel.userScoreIfNotInTop,
                       let userRank = viewModel.userRank {
                        Divider()
                            .padding(.vertical, 4)

                        LeaderboardRowView(
                            score: userScore,
                            rank: userRank,
                            isCurrentUser: true,
                            colorScheme: colorScheme
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No scores yet today")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)

            Text("Be the first to set a score!")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
        }
        .padding(.vertical, 16)
    }

    // MARK: - User Info Section

    private var userInfoSection: some View {
        VStack(spacing: 8) {
            Text("Your display name is:")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)

            Text(viewModel.displayName)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color.ucdGold)

            if let rank = viewModel.userRank {
                Text("You ranked #\(rank) out of \(viewModel.totalPlayers)")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.ucdGold.opacity(0.15))
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onDismiss) {
                Text("View \(viewModel.gameDisplayName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.ucdBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.ucdGold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: onBack) {
                Text("Back to Games")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.3) : Color.ucdBlue.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    GameOverLeaderboardView(
        gameType: .wordle,
        resultTitle: "Puzzle Complete!",
        resultSubtitle: "Solved in 4 guesses",
        onDismiss: {},
        onBack: {}
    )
}
