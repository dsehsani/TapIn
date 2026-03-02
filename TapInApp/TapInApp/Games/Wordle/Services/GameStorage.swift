//
//  GameStorage.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/22/26.
//
//  MARK: - Service Layer (MVVM)
//  Singleton service for persisting and cloud-syncing Wordle game states.
//
//  Thread Safety:
//  - All UserDefaults reads/writes are serialized through `stateLock` (NSLock)
//  - Cloud sync is coalesced via `activeSyncTask` — concurrent callers await
//    the same in-flight operation instead of spawning duplicates
//  - Single-date pushes from saveGameState() are independent fire-and-forget
//    network calls that don't mutate local state
//
//  Storage Format:
//  - Key: "wordleGameStates" (or "wordleGameStates_<email>" per account)
//  - Value: JSON dictionary of [dateKey: StoredGameState]
//

import Foundation

class GameStorage {

    // MARK: - Singleton

    static let shared = GameStorage()

    // MARK: - Properties

    private let defaults = UserDefaults.standard
    private let storageKey = "wordleGameStates"

    /// Serializes all reads/writes to UserDefaults to prevent interleaved access
    /// between save operations and background sync.
    private let stateLock = NSLock()

    /// Tracks the in-flight sync task so concurrent callers coalesce onto
    /// the same operation rather than issuing duplicate network requests.
    private var activeSyncTask: Task<Void, Never>?

    /// Per-account storage key: appends the user's email when authenticated
    private var currentStorageKey: String {
        let email = AppState.shared.userEmail
        return email.isEmpty ? storageKey : "\(storageKey)_\(email)"
    }

    // MARK: - Initialization

    private init() {
        syncWithBackend()
    }

    // MARK: - Save

    /// Saves the current game state for a given date.
    ///
    /// 1. Acquires `stateLock`, merges into the local dictionary, writes to UserDefaults
    /// 2. Pushes this single date to the backend (fire-and-forget, no local mutation)
    func saveGameState(for date: Date, guesses: [String], gameState: GameState, didExitGame: Bool = false) {
        let dateKey = DateWordGenerator.dateKey(for: date)

        let stateString: String
        switch gameState {
        case .playing: stateString = "playing"
        case .won:     stateString = "won"
        case .lost:    stateString = "lost"
        }

        let storedState = StoredGameState(
            guesses: guesses,
            gameState: stateString,
            dateKey: dateKey,
            didExitGame: didExitGame
        )

        // Thread-safe local write
        stateLock.lock()
        var allStates = _loadAllStates()
        allStates[dateKey] = storedState
        _saveAllStates(allStates)
        stateLock.unlock()

        // Push single date to backend (no local state mutation, safe without lock)
        Task {
            guard let token = AppState.shared.backendToken else { return }
            try? await UserAPIService.shared.syncWordleProgress(
                token: token, dateKey: dateKey, guesses: guesses,
                gameState: stateString, didExitGame: didExitGame
            )
        }
    }

    // MARK: - Load

    func loadGameState(for date: Date) -> StoredGameState? {
        let dateKey = DateWordGenerator.dateKey(for: date)
        stateLock.lock()
        let allStates = _loadAllStates()
        stateLock.unlock()
        return allStates[dateKey]
    }

    // MARK: - Query

    func hasPlayedDate(_ date: Date) -> Bool {
        return loadGameState(for: date) != nil
    }

    func isDateCompleted(_ date: Date) -> Bool {
        guard let state = loadGameState(for: date) else { return false }
        return state.isCompleted
    }

    func getAllPlayedDates() -> [Date] {
        stateLock.lock()
        let allStates = _loadAllStates()
        stateLock.unlock()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return allStates.keys.compactMap { formatter.date(from: $0) }.sorted(by: >)
    }

    func getCompletedDatesWithStatus() -> [(date: Date, won: Bool)] {
        stateLock.lock()
        let allStates = _loadAllStates()
        stateLock.unlock()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return allStates.compactMap { key, state -> (Date, Bool)? in
            guard state.isCompleted, let date = formatter.date(from: key) else { return nil }
            return (date, state.isWon)
        }.sorted { $0.0 > $1.0 }
    }

    // MARK: - Cloud Sync

    /// Awaitable bidirectional sync. Coalesces concurrent calls — if a sync is
    /// already in flight, subsequent callers await the existing task.
    ///
    /// Flow:
    /// 1. Fetch all remote progress from backend
    /// 2. Pull: merge server entries into local (server wins if more guesses)
    /// 3. Push: upload local entries the server doesn't have (or local is ahead)
    func performSync() async {
        // Coalesce: if a sync is already running, await it instead of starting another
        if let existing = activeSyncTask {
            await existing.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self._syncImplementation()
        }
        activeSyncTask = task
        await task.value
        activeSyncTask = nil
    }

    /// Fire-and-forget wrapper for contexts that can't await (init, etc.)
    func syncWithBackend() {
        Task { await performSync() }
    }

    // MARK: - Private: Sync Implementation

    private func _syncImplementation() async {
        guard let token = AppState.shared.backendToken else { return }

        // 1. Fetch remote
        let remote = (try? await UserAPIService.shared.fetchWordleProgress(token: token)) ?? [:]

        // 2. Pull — merge server entries into local (synchronous, lock-safe)
        let snapshot = _mergeRemoteIntoLocal(remote)

        // 3. Push — upload local entries the server is missing or behind on
        for (dateKey, localState) in snapshot {
            let remoteEntry = remote[dateKey]
            let remoteCount = (remoteEntry?["guesses"] as? [String])?.count ?? 0

            if remoteEntry == nil || localState.guesses.count > remoteCount {
                try? await UserAPIService.shared.syncWordleProgress(
                    token: token, dateKey: dateKey,
                    guesses: localState.guesses,
                    gameState: localState.gameState,
                    didExitGame: localState.didExitGame
                )
            }
        }
    }

    /// Merges remote entries into local state and returns a snapshot for the push phase.
    /// Synchronous — safe to hold NSLock.
    private func _mergeRemoteIntoLocal(_ remote: [String: [String: Any]]) -> [String: StoredGameState] {
        stateLock.lock()
        defer { stateLock.unlock() }

        var allStates = _loadAllStates()
        var localChanged = false

        for (dateKey, entry) in remote {
            let remoteGuesses = entry["guesses"] as? [String] ?? []
            let remoteGameState = entry["gameState"] as? String ?? "playing"
            let remoteDidExit = entry["didExitGame"] as? Bool ?? false
            let localState = allStates[dateKey]

            if localState == nil || remoteGuesses.count > (localState?.guesses.count ?? 0) {
                allStates[dateKey] = StoredGameState(
                    guesses: remoteGuesses,
                    gameState: remoteGameState,
                    dateKey: dateKey,
                    didExitGame: remoteDidExit
                )
                localChanged = true
            }
        }

        if localChanged {
            _saveAllStates(allStates)
        }

        return allStates
    }

    // MARK: - Private: State Access (caller must hold stateLock)

    private func _loadAllStates() -> [String: StoredGameState] {
        guard let data = defaults.data(forKey: currentStorageKey),
              let states = try? JSONDecoder().decode([String: StoredGameState].self, from: data) else {
            return [:]
        }
        return states
    }

    private func _saveAllStates(_ states: [String: StoredGameState]) {
        if let data = try? JSONEncoder().encode(states) {
            defaults.set(data, forKey: currentStorageKey)
        }
    }

    // MARK: - Debug/Testing

    func clearAllData() {
        stateLock.lock()
        defaults.removeObject(forKey: currentStorageKey)
        stateLock.unlock()
    }
}
