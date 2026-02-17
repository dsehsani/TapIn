//
//  LeaderboardHeaderView.swift
//  TapInApp
//
//  MARK: - Leaderboard Header Component
//  Header section with game type selector, date navigation, and stats summary.
//

import SwiftUI

// MARK: - Leaderboard Header View

struct LeaderboardHeaderView: View {
    @Bindable var viewModel: LeaderboardViewModel
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 16) {
            // Game Type Selector
            gameTypeSelector

            // Date Navigation
            dateNavigator

            // Stats Summary
            statsSummary
        }
    }

    // MARK: - Game Type Selector

    private var gameTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.availableGameTypes, id: \.self) { gameType in
                    GameTypePill(
                        gameType: gameType,
                        isSelected: viewModel.selectedGameType == gameType,
                        colorScheme: colorScheme
                    ) {
                        viewModel.selectGameType(gameType)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Date Navigator

    private var dateNavigator: some View {
        HStack(spacing: 16) {
            // Previous day button
            Button(action: viewModel.previousDay) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                    .frame(width: 36, height: 36)
                    .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"))
                    .clipShape(Circle())
            }

            // Date display
            Button(action: { viewModel.showingDatePicker = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                    Text(viewModel.formattedDate)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
            }

            // Next day button
            Button(action: viewModel.nextDay) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(viewModel.canGoForward
                        ? (colorScheme == .dark ? .white : Color.ucdBlue)
                        : .textSecondary.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"))
                    .clipShape(Circle())
            }
            .disabled(!viewModel.canGoForward)

            Spacer()

            // Today button (if not viewing today)
            if !viewModel.isToday {
                Button(action: viewModel.goToToday) {
                    Text("Today")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.ucdBlue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Stats Summary

    private var statsSummary: some View {
        HStack(spacing: 16) {
            LeaderboardStatBox(
                title: "Your Best",
                value: viewModel.bestScore?.scoreDisplay ?? "-",
                icon: "trophy.fill",
                colorScheme: colorScheme
            )

            LeaderboardStatBox(
                title: "Games Played",
                value: "\(viewModel.userStats.gamesPlayed)",
                icon: "gamecontroller.fill",
                colorScheme: colorScheme
            )

            LeaderboardStatBox(
                title: "Win Rate",
                value: String(format: "%.0f%%", viewModel.userStats.winPercentage),
                icon: "chart.line.uptrend.xyaxis",
                colorScheme: colorScheme
            )
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Game Type Pill

struct GameTypePill: View {
    let gameType: GameType
    let isSelected: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                Text(gameType.displayName)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, isSelected ? 20 : 16)
            .frame(height: 40)
            .background(
                isSelected
                    ? Color.ucdBlue
                    : (colorScheme == .dark ? Color(hex: "#1e293b") : Color.white)
            )
            .foregroundColor(
                isSelected
                    ? .white
                    : (colorScheme == .dark ? Color(hex: "#cbd5e1") : Color(hex: "#334155"))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected
                            ? Color.clear
                            : (colorScheme == .dark ? Color(hex: "#334155") : Color(hex: "#e2e8f0")),
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? Color.ucdBlue.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var iconName: String {
        switch gameType {
        case .wordle: return "puzzlepiece.extension.fill"
        case .echo: return "waveform.path"
        case .crossword: return "square.grid.3x3.fill"
        case .trivia: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Leaderboard Stat Box

struct LeaderboardStatBox: View {
    let title: String
    let value: String
    let icon: String
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color.ucdGold)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        LeaderboardHeaderView(
            viewModel: LeaderboardViewModel(),
            colorScheme: .light
        )
        Spacer()
    }
    .background(Color.backgroundLight)
}
