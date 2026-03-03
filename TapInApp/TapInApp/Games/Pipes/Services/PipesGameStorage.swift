//
//  PipesGameStorage.swift
//  TapInApp
//
//  MARK: - Service Layer (MVVM)
//  Singleton service for persisting Pipes daily-five game states.
//  Follows the same pattern as Wordle's GameStorage.swift.
//

import Foundation

class PipesGameStorage {

    // MARK: - Singleton

    static let shared = PipesGameStorage()

    // MARK: - Properties

    private let defaults = UserDefaults.standard
    private let storageKey = "pipesDailyFiveStates"
    private let puzzleCacheKey = "pipesDailyFivePuzzleCache"
    private let stateLock = NSLock()

    /// Per-account storage key: appends the user's email when authenticated
    private var currentStorageKey: String {
        let email = AppState.shared.userEmail
        return email.isEmpty ? storageKey : "\(storageKey)_\(email)"
    }

    private var currentCacheKey: String {
        let email = AppState.shared.userEmail
        return email.isEmpty ? puzzleCacheKey : "\(puzzleCacheKey)_\(email)"
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Daily State (full day)

    func saveDailyState(_ state: PipesDailyState) {
        stateLock.lock()
        var allStates = _loadAllDailyStates()
        allStates[state.dateKey] = state
        _saveAllDailyStates(allStates)
        stateLock.unlock()
    }

    func loadDailyState(for dateKey: String) -> PipesDailyState? {
        stateLock.lock()
        let allStates = _loadAllDailyStates()
        stateLock.unlock()
        return allStates[dateKey]
    }

    // MARK: - Individual Puzzle State

    func savePuzzleState(_ puzzleState: PipesStoredPuzzleState, for dateKey: String) {
        stateLock.lock()
        var allStates = _loadAllDailyStates()

        if var dailyState = allStates[dateKey] {
            if puzzleState.puzzleIndex < dailyState.puzzleStates.count {
                dailyState.puzzleStates[puzzleState.puzzleIndex] = puzzleState
            }
            allStates[dateKey] = dailyState
        }

        _saveAllDailyStates(allStates)
        stateLock.unlock()
    }

    func loadPuzzleState(for dateKey: String, puzzleIndex: Int) -> PipesStoredPuzzleState? {
        stateLock.lock()
        let allStates = _loadAllDailyStates()
        stateLock.unlock()

        guard let dailyState = allStates[dateKey],
              puzzleIndex < dailyState.puzzleStates.count else {
            return nil
        }
        return dailyState.puzzleStates[puzzleIndex]
    }

    // MARK: - Day Status (for archive calendar)

    func getDayStatus(for dateKey: String) -> PipesDayStatus {
        stateLock.lock()
        let allStates = _loadAllDailyStates()
        stateLock.unlock()

        guard let dailyState = allStates[dateKey] else {
            return .notPlayed
        }

        if dailyState.isAllComplete {
            return .allComplete
        } else if dailyState.completedCount > 0 ||
                  dailyState.puzzleStates.contains(where: { $0.status == .inProgress }) {
            return .partial
        }
        return .notPlayed
    }

    func getAllPlayedDates() -> [String: PipesDayStatus] {
        stateLock.lock()
        let allStates = _loadAllDailyStates()
        stateLock.unlock()

        var result: [String: PipesDayStatus] = [:]
        for (dateKey, dailyState) in allStates {
            if dailyState.isAllComplete {
                result[dateKey] = .allComplete
            } else if dailyState.completedCount > 0 ||
                      dailyState.puzzleStates.contains(where: { $0.status == .inProgress }) {
                result[dateKey] = .partial
            }
        }
        return result
    }

    // MARK: - Puzzle Cache (offline support)

    func cachePuzzles(for dateKey: String, puzzles: [PipePuzzle]) {
        stateLock.lock()
        var cache = _loadPuzzleCache()
        cache[dateKey] = puzzles
        _savePuzzleCache(cache)
        stateLock.unlock()
    }

    func getCachedPuzzles(for dateKey: String) -> [PipePuzzle]? {
        stateLock.lock()
        let cache = _loadPuzzleCache()
        stateLock.unlock()
        return cache[dateKey]
    }

    // MARK: - Private: Daily State Access (caller must hold stateLock)

    private func _loadAllDailyStates() -> [String: PipesDailyState] {
        guard let data = defaults.data(forKey: currentStorageKey),
              let states = try? JSONDecoder().decode([String: PipesDailyState].self, from: data) else {
            return [:]
        }
        return states
    }

    private func _saveAllDailyStates(_ states: [String: PipesDailyState]) {
        if let data = try? JSONEncoder().encode(states) {
            defaults.set(data, forKey: currentStorageKey)
        }
    }

    // MARK: - Private: Puzzle Cache Access (caller must hold stateLock)

    private func _loadPuzzleCache() -> [String: [PipePuzzle]] {
        guard let data = defaults.data(forKey: currentCacheKey),
              let cache = try? JSONDecoder().decode([String: [PipePuzzle]].self, from: data) else {
            return [:]
        }
        return cache
    }

    private func _savePuzzleCache(_ cache: [String: [PipePuzzle]]) {
        if let data = try? JSONEncoder().encode(cache) {
            defaults.set(data, forKey: currentCacheKey)
        }
    }
}
