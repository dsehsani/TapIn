//
//  GamesView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct GamesView: View {
    @ObservedObject var viewModel: GamesViewModel

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aggie Games")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                            Text("Test your UC Davis knowledge")
                                .font(.system(size: 14))
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        // Streak Badge
                        VStack(spacing: 2) {
                            Text("\(viewModel.userStats.currentStreak)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color.ucdGold)
                            Text("streak")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(hex: "#1e293b") : .white)
                                .shadow(color: .black.opacity(0.05), radius: 4)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Stats Overview
                    HStack(spacing: 16) {
                        StatCard(title: "Games Played", value: "\(viewModel.userStats.gamesPlayed)", icon: "gamecontroller.fill", colorScheme: colorScheme)
                        StatCard(title: "Wins", value: "\(viewModel.userStats.wins)", icon: "trophy.fill", colorScheme: colorScheme)
                        StatCard(title: "Best Streak", value: "\(viewModel.userStats.maxStreak)", icon: "flame.fill", colorScheme: colorScheme)
                    }
                    .padding(.horizontal, 16)

                    // Featured Game
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Challenge")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                            .padding(.horizontal, 16)

                        if let featuredGame = viewModel.availableGames.first {
                            FeaturedGameCard(game: featuredGame, colorScheme: colorScheme) {
                                viewModel.startGame(featuredGame)
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // All Games
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Games")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                            .padding(.horizontal, 16)

                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.availableGames) { game in
                                GameRowCard(game: game, colorScheme: colorScheme) {
                                    viewModel.startGame(game)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                        .frame(height: 8)
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showingWordle) {
            WordleGameView(onDismiss: {
                viewModel.dismissGame()
            })
        }
        .fullScreenCover(isPresented: $viewModel.showingEcho) {
            EchoGameView(onDismiss: {
                viewModel.dismissGame()
            })
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color.ucdGold)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"), lineWidth: 1)
        )
    }
}

struct FeaturedGameCard: View {
    let game: Game
    let colorScheme: ColorScheme
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.ucdBlue, Color(hex: "#1e3a5f")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(game.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text(game.description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))

                    Button(action: onPlay) {
                        Text("Play Now")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.ucdBlue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.ucdGold)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }

                Spacer()

                Image(systemName: game.iconName)
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(20)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.ucdBlue.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct GameRowCard: View {
    let game: Game
    let colorScheme: ColorScheme
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.ucdGold.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: game.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(Color.ucdGold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(game.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                    Text(game.description)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)

                    if game.isMultiplayer {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            Text("Multiplayer")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(Color.ucdBlue)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
            .padding(16)
            .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    GamesView(viewModel: GamesViewModel())
}

