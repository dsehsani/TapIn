//
//  GamesViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - Games ViewModel
//  Manages game state and available games
//  TODO: ADD YOUR GAME LOGIC HERE
//

import Foundation
import SwiftUI
import Combine

class GamesViewModel: ObservableObject {
    @Published var availableGames: [Game] = []
    @Published var currentGame: Game?
    @Published var isLoading: Bool = false
    @Published var userStats: GameStats = GameStats()
    @Published var showingWordle: Bool = false

    init() {
        loadAvailableGames()
        loadUserStats()
    }

    // TODO: REPLACE WITH YOUR GAMES IMPLEMENTATION
    func loadAvailableGames() {
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.availableGames = Game.sampleData
            self.isLoading = false
        }
    }

    func startGame(_ game: Game) {
        currentGame = game

        // Check if it's the Wordle game and show it
        if game.name == "Aggie Wordle" {
            showingWordle = true
        }
    }

    func dismissGame() {
        showingWordle = false
        currentGame = nil
    }

    func endGame() {
        currentGame = nil
    }

    func loadUserStats() {
        userStats = GameStats(gamesPlayed: 42, currentStreak: 7, maxStreak: 15, wins: 35)
    }

    func saveUserStats() {
        // TODO: Save to UserDefaults or backend
    }

    func updateStats(won: Bool) {
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
        saveUserStats()
    }
}
