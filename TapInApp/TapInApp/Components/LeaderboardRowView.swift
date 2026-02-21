//
//  LeaderboardRowView.swift
//  TapInApp
//
//  Created by Claude on 2/21/26.
//

import SwiftUI

struct LeaderboardRowView: View {
    let entry: LeaderboardEntryResponse
    let isCurrentUser: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Rank Badge
            rankBadge

            // Username + YOU badge
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.username)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                        .lineLimit(1)

                    if isCurrentUser {
                        Text("YOU")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.ucdGold))
                    }
                }

                // Guesses display (green blocks)
                Text(entry.guessesDisplay)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Time
            Text(formatTime(entry.timeSeconds))
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser
                      ? (colorScheme == .dark ? Color.ucdGold.opacity(0.15) : Color.ucdGold.opacity(0.1))
                      : (colorScheme == .dark ? Color(hex: "#1a2033") : .white))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentUser
                        ? Color.ucdGold.opacity(0.4)
                        : (colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9")),
                        lineWidth: 1)
        )
    }

    // MARK: - Rank Badge

    private var rankBadge: some View {
        ZStack {
            Circle()
                .fill(rankColor)
                .frame(width: 32, height: 32)
            Text("\(entry.rank)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1: return Color(hex: "#FFD700") // gold
        case 2: return Color(hex: "#C0C0C0") // silver
        case 3: return Color(hex: "#CD7F32") // bronze
        default: return Color(hex: "#6B7280") // gray
        }
    }

    // MARK: - Time Formatter

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}
