//
//  LeaderboardSyncService.swift
//  TapInApp
//
//  MARK: - Leaderboard Sync Service
//  Orchestrates synchronization between local and remote leaderboard data.
//  Manages offline-first sync with retry logic.
//
//  Architecture:
//  - Uses LocalLeaderboardService as primary data source
//  - Pushes to RemoteLeaderboardService when online
//  - Handles background sync and retry logic
//
//  Integration Notes:
//  - Call syncPendingScores() periodically or on app foreground
//  - Call syncScore() immediately after saving a score locally
//  - Check APIConfig.useLocalOnlyLeaderboards to disable remote sync
//

import Foundation
import Combine

// MARK: - Leaderboard Sync Service

/// Service for synchronizing leaderboard data between local and remote storage.
///
/// Features:
/// - Automatic retry for failed syncs
/// - Batch sync support
/// - Respects useLocalOnlyLeaderboards setting
///
@MainActor
class LeaderboardSyncService: ObservableObject {

    // MARK: - Singleton

    static let shared = LeaderboardSyncService()

    // MARK: - Dependencies

    private let localService = LocalLeaderboardService.shared
    private let remoteService = RemoteLeaderboardService.shared

    // MARK: - State

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var pendingCount: Int = 0

    // MARK: - Private State

    private var syncTask: Task<Void, Never>?
    private var retryCount: [UUID: Int] = [:]

    // MARK: - Initialization

    private init() {
        updatePendingCount()
    }

    // MARK: - Sync Single Score

    /// Syncs a single score to the remote server.
    ///
    /// Call this immediately after saving a score locally.
    /// If remote sync is disabled, this is a no-op.
    ///
    /// - Parameter score: The LocalScore to sync
    /// - Returns: True if synced successfully (or if remote is disabled)
    ///
    @discardableResult
    func syncScore(_ score: LocalScore) async -> Bool {
        // Skip if local-only mode
        guard !APIConfig.useLocalOnlyLeaderboards else {
            print("LeaderboardSyncService: Remote sync disabled, skipping")
            return true
        }

        // Skip if already synced
        guard score.syncStatus != .synced else {
            return true
        }

        do {
            let response = try await remoteService.submitScore(score)

            // Update local score with remote ID
            localService.markAsSynced(
                score.id,
                remoteId: response.id,
                username: response.username
            )

            updatePendingCount()
            print("LeaderboardSyncService: Synced score \(score.id) -> \(response.id)")
            return true

        } catch {
            // Mark as failed for retry
            localService.markAsFailed(score.id)
            incrementRetryCount(for: score.id)
            updatePendingCount()
            print("LeaderboardSyncService: Failed to sync score \(score.id): \(error)")
            return false
        }
    }

    // MARK: - Sync All Pending

    /// Syncs all pending scores to the remote server.
    ///
    /// Use batch sync when there are multiple pending scores.
    /// Respects APIConfig.syncBatchSize for chunking.
    ///
    /// - Returns: Number of successfully synced scores
    ///
    @discardableResult
    func syncPendingScores() async -> Int {
        // Skip if local-only mode
        guard !APIConfig.useLocalOnlyLeaderboards else {
            print("LeaderboardSyncService: Remote sync disabled")
            return 0
        }

        // Skip if already syncing
        guard !isSyncing else {
            print("LeaderboardSyncService: Sync already in progress")
            return 0
        }

        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
            updatePendingCount()
        }

        let pendingScores = localService.getPendingScores()
            .filter { shouldRetry($0.id) }

        guard !pendingScores.isEmpty else {
            print("LeaderboardSyncService: No pending scores to sync")
            return 0
        }

        print("LeaderboardSyncService: Syncing \(pendingScores.count) pending scores")

        var syncedCount = 0

        // Sync in batches
        let batchSize = APIConfig.syncBatchSize
        for startIndex in stride(from: 0, to: pendingScores.count, by: batchSize) {
            let endIndex = min(startIndex + batchSize, pendingScores.count)
            let batch = Array(pendingScores[startIndex..<endIndex])

            do {
                let response = try await remoteService.syncScores(batch)

                // Process results
                for (index, result) in response.results.enumerated() where index < batch.count {
                    let localScore = batch[index]
                    if result.success {
                        localService.markAsSynced(
                            localScore.id,
                            remoteId: result.remote_id,
                            username: nil  // Keep existing username
                        )
                        clearRetryCount(for: localScore.id)
                        syncedCount += 1
                    } else {
                        localService.markAsFailed(localScore.id)
                        incrementRetryCount(for: localScore.id)
                    }
                }

            } catch {
                // Mark all in batch as failed
                for score in batch {
                    localService.markAsFailed(score.id)
                    incrementRetryCount(for: score.id)
                }
                print("LeaderboardSyncService: Batch sync failed: \(error)")
            }
        }

        print("LeaderboardSyncService: Synced \(syncedCount) of \(pendingScores.count) scores")
        return syncedCount
    }

    // MARK: - Background Sync

    /// Starts periodic background sync.
    ///
    /// Call this when the app becomes active.
    ///
    func startBackgroundSync() {
        guard !APIConfig.useLocalOnlyLeaderboards else { return }

        syncTask?.cancel()
        syncTask = Task {
            while !Task.isCancelled {
                await syncPendingScores()
                try? await Task.sleep(nanoseconds: UInt64(APIConfig.syncIntervalSeconds * 1_000_000_000))
            }
        }
        print("LeaderboardSyncService: Background sync started")
    }

    /// Stops background sync.
    ///
    /// Call this when the app enters background.
    ///
    func stopBackgroundSync() {
        syncTask?.cancel()
        syncTask = nil
        print("LeaderboardSyncService: Background sync stopped")
    }

    // MARK: - Retry Logic

    private func shouldRetry(_ scoreId: UUID) -> Bool {
        let count = retryCount[scoreId] ?? 0
        return count < APIConfig.syncMaxRetries
    }

    private func incrementRetryCount(for scoreId: UUID) {
        retryCount[scoreId] = (retryCount[scoreId] ?? 0) + 1
    }

    private func clearRetryCount(for scoreId: UUID) {
        retryCount.removeValue(forKey: scoreId)
    }

    // MARK: - State Updates

    private func updatePendingCount() {
        pendingCount = localService.pendingScoreCount
    }

    // MARK: - Convenience

    /// Saves a score locally and attempts remote sync.
    ///
    /// This is the primary method for recording a game score.
    /// It saves locally first (offline-first) then attempts sync.
    ///
    /// - Parameter score: The LocalScore to save and sync
    /// - Returns: True if saved locally (sync may still be pending)
    ///
    @discardableResult
    func saveAndSync(_ score: LocalScore) async -> Bool {
        // Save locally first (always succeeds unless duplicate)
        let saved = localService.saveScore(score)

        guard saved else {
            return false
        }

        // Attempt remote sync (fire and forget)
        if !APIConfig.useLocalOnlyLeaderboards {
            Task {
                await syncScore(score)
            }
        }

        return true
    }

    // MARK: - Health Check

    /// Checks if remote sync is available.
    ///
    /// - Returns: True if server is reachable and sync is enabled
    ///
    func isRemoteSyncAvailable() async -> Bool {
        guard !APIConfig.useLocalOnlyLeaderboards else {
            return false
        }
        return await remoteService.isServerHealthy()
    }
}
