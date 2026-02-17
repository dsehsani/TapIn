//
//  LeaderboardRowView.swift
//  TapInApp
//
//  MARK: - Leaderboard Row Component
//  Displays a single score entry in the leaderboard list.
//  Shows rank, username, score, and optional medal for top 3.
//

import SwiftUI

// MARK: - Leaderboard Row View

struct LeaderboardRowView: View {
    let score: LocalScore
    let rank: Int
    let isCurrentUser: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Rank indicator
            rankView

            // User info and score
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(score.username ?? "You")
                        .font(.system(size: 16, weight: isCurrentUser ? .bold : .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

                    if isCurrentUser {
                        Text("YOU")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.ucdGold)
                            .clipShape(Capsule())
                    }
                }

                if let secondary = score.secondaryDisplay {
                    Text(secondary)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            // Score display
            VStack(alignment: .trailing, spacing: 2) {
                Text(score.scoreDisplay)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(rankColor)

                Text(scoreLabel)
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(16)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: isCurrentUser ? 2 : 1)
        )
    }

    // MARK: - Rank View

    private var rankView: some View {
        ZStack {
            if let medal = medalEmoji {
                Text(medal)
                    .font(.system(size: 24))
            } else {
                Text("#\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#64748b"))
            }
        }
        .frame(width: 44, height: 44)
        .background(rankBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Computed Properties

    private var medalEmoji: String? {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "#FFD700")  // Gold
        case 2: return Color(hex: "#C0C0C0")  // Silver
        case 3: return Color(hex: "#CD7F32")  // Bronze
        default: return colorScheme == .dark ? .white : Color(hex: "#0f172a")
        }
    }

    private var rankBackground: Color {
        switch rank {
        case 1: return Color(hex: "#FFD700").opacity(0.2)
        case 2: return Color(hex: "#C0C0C0").opacity(0.2)
        case 3: return Color(hex: "#CD7F32").opacity(0.2)
        default: return colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9")
        }
    }

    private var rowBackground: Color {
        if isCurrentUser {
            return colorScheme == .dark ? Color.ucdBlue.opacity(0.2) : Color.ucdBlue.opacity(0.05)
        }
        return colorScheme == .dark ? Color(hex: "#0f172a") : .white
    }

    private var borderColor: Color {
        if isCurrentUser {
            return Color.ucdGold.opacity(0.5)
        }
        return colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9")
    }

    private var scoreLabel: String {
        switch score.gameType {
        case .wordle: return "guesses"
        case .echo: return "points"
        case .crossword: return "time"
        case .trivia: return "correct"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        LeaderboardRowView(
            score: LocalScore(
                gameType: .wordle,
                score: 550,
                date: Date(),
                metadata: .wordle(guesses: 2, timeSeconds: 45),
                username: "AggieChamp"
            ),
            rank: 1,
            isCurrentUser: false,
            colorScheme: .light
        )

        LeaderboardRowView(
            score: LocalScore(
                gameType: .wordle,
                score: 450,
                date: Date(),
                metadata: .wordle(guesses: 3, timeSeconds: 120),
                username: nil
            ),
            rank: 2,
            isCurrentUser: true,
            colorScheme: .light
        )

        LeaderboardRowView(
            score: LocalScore(
                gameType: .echo,
                score: 1200,
                date: Date(),
                metadata: .echo(totalScore: 1200, roundScores: [300, 300, 300, 200, 100], perfectRounds: 3, totalAttempts: 7, roundsSolved: 5)
            ),
            rank: 5,
            isCurrentUser: false,
            colorScheme: .light
        )
    }
    .padding()
    .background(Color.backgroundLight)
}
