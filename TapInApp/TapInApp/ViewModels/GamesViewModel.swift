//
//  GamesViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - Games ViewModel
//  Manages game state, available games, and aggregate user stats.
//  Stats persist to UserDefaults (instant) and sync to backend (cross-device).
//

import Foundation
import SwiftUI
import Combine

@MainActor
class GamesViewModel: ObservableObject {
    @Published var availableGames: [Game] = []
    @Published var currentGame: Game?
    @Published var isLoading: Bool = false
    @Published var userStats: GameStats = GameStats()
    @Published var showingWordle: Bool = false
    @Published var showingEcho: Bool = false
    @Published var showingPipes: Bool = false
    @Published var showingLeaderboard: Bool = false

    private var currentStatsKey: String {
        let email = AppState.shared.userEmail
        return email.isEmpty ? "aggregateGameStats" : "aggregateGameStats_\(email)"
    }

    init() {
        loadAvailableGames()
        loadUserStats()
    }

    func loadAvailableGames() {
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.availableGames = Game.sampleData
            self?.isLoading = false
        }
    }

    func startGame(_ game: Game) {
        currentGame = game

        switch game.type {
        case .wordle:
            showingWordle = true
        case .echo:
            showingEcho = true
        case .pipes:
            showingPipes = true
        default:
            break
        }
    }

    func dismissGame() {
        showingWordle = false
        showingEcho = false
        showingPipes = false
        showingLeaderboard = false
        currentGame = nil
    }

    func endGame() {
        currentGame = nil
    }

    // MARK: - Stats Persistence

    func loadUserStats() {
        let key = currentStatsKey
        let oldKey = "aggregateGameStats"

        // Migration: if per-user key has no data but the old shared key does, copy it over
        if key != oldKey,
           UserDefaults.standard.data(forKey: key) == nil,
           let oldData = UserDefaults.standard.data(forKey: oldKey),
           let oldStats = try? JSONDecoder().decode(GameStats.self, from: oldData) {
            userStats = oldStats
            if let data = try? JSONEncoder().encode(userStats) {
                UserDefaults.standard.set(data, forKey: key)
            }
        } else if let data = UserDefaults.standard.data(forKey: key),
                  let stats = try? JSONDecoder().decode(GameStats.self, from: data) {
            userStats = stats
        }

        // Check if streak should be reset (missed a day)
        resetStreakIfNeeded()

        // Async fetch from backend and merge
        Task {
            await fetchStatsFromBackend()
        }
    }

    func saveUserStats() {
        // Save to UserDefaults (instant)
        if let data = try? JSONEncoder().encode(userStats) {
            UserDefaults.standard.set(data, forKey: currentStatsKey)
        }

        // Sync to backend in background
        Task {
            await syncStatsToBackend()
        }
    }

    func updateStats(won: Bool) {
        // Reset streak if the user missed a day
        resetStreakIfNeeded()

        userStats.gamesPlayed += 1
        if won {
            userStats.wins += 1
            userStats.currentStreak += 1
            if userStats.currentStreak > userStats.maxStreak {
                userStats.maxStreak = userStats.currentStreak
            }
        } else {
            userStats.currentStreak = 0
        }
        userStats.lastPlayedDate = Date()
        saveUserStats()
    }

    // MARK: - Streak Logic

    private func resetStreakIfNeeded() {
        guard let lastPlayed = userStats.lastPlayedDate else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastPlayed)

        // If last played is before yesterday, reset streak
        if let daysSince = calendar.dateComponents([.day], from: lastDay, to: today).day,
           daysSince > 1 {
            userStats.currentStreak = 0
        }
    }

    // MARK: - Backend Sync

    private func fetchStatsFromBackend() async {
        guard let token = AppState.shared.backendToken else { return }

        do {
            if let remote = try await UserAPIService.shared.fetchGameStats(token: token) {
                let remoteGamesPlayed = remote["gamesPlayed"] as? Int ?? 0
                let remoteWins = remote["wins"] as? Int ?? 0
                let remoteCurrentStreak = remote["currentStreak"] as? Int ?? 0
                let remoteMaxStreak = remote["maxStreak"] as? Int ?? 0

                // Merge: take the higher values (handles cross-device play)
                var merged = false
                if remoteGamesPlayed > userStats.gamesPlayed {
                    userStats.gamesPlayed = remoteGamesPlayed
                    merged = true
                }
                if remoteWins > userStats.wins {
                    userStats.wins = remoteWins
                    merged = true
                }
                if remoteCurrentStreak > userStats.currentStreak {
                    userStats.currentStreak = remoteCurrentStreak
                    merged = true
                }
                if remoteMaxStreak > userStats.maxStreak {
                    userStats.maxStreak = remoteMaxStreak
                    merged = true
                }

                // If local had higher values than remote, push merged stats back
                let localWasHigher = userStats.gamesPlayed > remoteGamesPlayed
                    || userStats.wins > remoteWins
                    || userStats.maxStreak > remoteMaxStreak

                if merged {
                    if let data = try? JSONEncoder().encode(userStats) {
                        UserDefaults.standard.set(data, forKey: currentStatsKey)
                    }
                }

                if merged || localWasHigher {
                    await syncStatsToBackend()
                }
            }
        } catch {
            #if DEBUG
            print("GamesVM: Failed to fetch stats from backend — \(error.localizedDescription)")
            #endif
        }
    }

    private func syncStatsToBackend() async {
        guard let token = AppState.shared.backendToken else { return }

        let stats: [String: Any] = [
            "gamesPlayed": userStats.gamesPlayed,
            "wins": userStats.wins,
            "currentStreak": userStats.currentStreak,
            "maxStreak": userStats.maxStreak,
            "lastPlayedDate": userStats.lastPlayedDate?.ISO8601Format() ?? NSNull()
        ]

        do {
            try await UserAPIService.shared.updateGameStats(token: token, stats: stats)
        } catch {
            #if DEBUG
            print("GamesVM: Failed to sync stats to backend — \(error.localizedDescription)")
            #endif
        }
    }
}
