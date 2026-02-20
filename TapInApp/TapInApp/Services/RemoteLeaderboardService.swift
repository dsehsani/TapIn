//
//  RemoteLeaderboardService.swift
//  TapInApp
//
//  MARK: - Remote Leaderboard Service
//  Unified service for syncing scores with the remote server.
//  Works with all game types (Wordle, Echo, Crossword, Trivia).
//
//  Architecture:
//  - Uses async/await for network requests
//  - Singleton pattern for app-wide access
//  - Follows APIConfig for endpoint configuration
//  - Designed to work alongside LocalLeaderboardService
//
//  Integration Notes:
//  - Use LocalLeaderboardService as the primary source of truth
//  - Call syncScore() after saving locally to push to server
//  - Call fetchLeaderboard() to get global rankings
//

import Foundation
import Combine

// MARK: - Remote Leaderboard Service

/// Service for communicating with the unified Leaderboard API.
///
/// Provides methods for:
/// - Submitting scores for any game type
/// - Fetching leaderboards by game and date
/// - Batch syncing pending scores
///
@MainActor
class RemoteLeaderboardService: ObservableObject {

    // MARK: - Singleton

    static let shared = RemoteLeaderboardService()

    // MARK: - Configuration

    private let session: URLSession

    // MARK: - Published State

    @Published var isLoading: Bool = false
    @Published var lastError: AppError?

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Submit Score

    /// Submits a score to the remote leaderboard.
    ///
    /// - Parameter score: The LocalScore to submit
    /// - Returns: RemoteScoreResponse with server-assigned ID
    /// - Throws: AppError if the request fails
    ///
    func submitScore(_ score: LocalScore) async throws -> RemoteScoreResponse {
        guard !APIConfig.useLocalOnlyLeaderboards else {
            throw AppError.requestFailed(reason: "Remote leaderboards disabled")
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        guard let url = URL(string: APIConfig.submitScoreURL) else {
            throw AppError.requestFailed(reason: "Invalid URL")
        }

        // Create request body
        let requestBody = RemoteScoreRequest(
            game_type: score.gameType.rawValue,
            score: score.score,
            date: score.dateKey,
            username: score.username,
            metadata: convertMetadata(score.metadata, gameType: score.gameType)
        )

        // Configure request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AppError.requestFailed(reason: "Failed to encode request")
        }

        // Perform request
        return try await performRequest(request)
    }

    // MARK: - Fetch Leaderboard

    /// Fetches the leaderboard for a specific game and date.
    ///
    /// - Parameters:
    ///   - gameType: The type of game
    ///   - date: The date (as yyyy-MM-dd string)
    ///   - limit: Maximum entries to return (default 5)
    /// - Returns: Array of RemoteLeaderboardEntry
    /// - Throws: AppError if the request fails
    ///
    func fetchLeaderboard(
        gameType: GameType,
        date: String,
        limit: Int = 5
    ) async throws -> [RemoteLeaderboardEntry] {
        guard !APIConfig.useLocalOnlyLeaderboards else {
            throw AppError.requestFailed(reason: "Remote leaderboards disabled")
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let urlString = APIConfig.leaderboardURL(gameType: gameType.rawValue, date: date)
        guard var urlComponents = URLComponents(string: urlString) else {
            throw AppError.requestFailed(reason: "Invalid URL")
        }
        urlComponents.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        guard let url = urlComponents.url else {
            throw AppError.requestFailed(reason: "Invalid URL")
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorResponse = try? JSONDecoder().decode(RemoteAPIError.self, from: data) {
                    throw AppError.requestFailed(reason: errorResponse.error)
                }
                throw AppError.serverError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let leaderboardResponse = try decoder.decode(RemoteLeaderboardResponse.self, from: data)
            return leaderboardResponse.leaderboard

        } catch let error as AppError {
            lastError = error
            throw error
        } catch is URLError {
            let appError = AppError.networkUnavailable
            lastError = appError
            throw appError
        } catch is DecodingError {
            let appError = AppError.decodingFailed
            lastError = appError
            throw appError
        } catch {
            let appError = AppError.requestFailed(reason: error.localizedDescription)
            lastError = appError
            throw appError
        }
    }

    // MARK: - Batch Sync

    /// Syncs multiple scores at once.
    ///
    /// - Parameter scores: Array of LocalScore to sync
    /// - Returns: RemoteSyncResponse with results
    /// - Throws: AppError if the request fails
    ///
    func syncScores(_ scores: [LocalScore]) async throws -> RemoteSyncResponse {
        guard !APIConfig.useLocalOnlyLeaderboards else {
            throw AppError.requestFailed(reason: "Remote leaderboards disabled")
        }

        guard !scores.isEmpty else {
            return RemoteSyncResponse(success: true, synced_count: 0, results: [])
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        guard let url = URL(string: APIConfig.syncScoresURL) else {
            throw AppError.requestFailed(reason: "Invalid URL")
        }

        // Convert LocalScores to request format
        let scoreRequests = scores.map { score in
            RemoteScoreRequest(
                game_type: score.gameType.rawValue,
                score: score.score,
                date: score.dateKey,
                username: score.username,
                metadata: convertMetadata(score.metadata, gameType: score.gameType)
            )
        }

        let requestBody = RemoteSyncRequest(scores: scoreRequests)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AppError.requestFailed(reason: "Failed to encode request")
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorResponse = try? JSONDecoder().decode(RemoteAPIError.self, from: data) {
                    throw AppError.requestFailed(reason: errorResponse.error)
                }
                throw AppError.serverError(statusCode: httpResponse.statusCode)
            }

            return try JSONDecoder().decode(RemoteSyncResponse.self, from: data)

        } catch let error as AppError {
            lastError = error
            throw error
        } catch is URLError {
            let appError = AppError.networkUnavailable
            lastError = appError
            throw appError
        } catch is DecodingError {
            let appError = AppError.decodingFailed
            lastError = appError
            throw appError
        } catch {
            let appError = AppError.requestFailed(reason: error.localizedDescription)
            lastError = appError
            throw appError
        }
    }

    // MARK: - Health Check

    /// Checks if the leaderboard server is reachable.
    ///
    /// - Returns: True if the server is healthy
    func isServerHealthy() async -> Bool {
        guard let url = URL(string: APIConfig.leaderboardHealthURL) else {
            return false
        }

        do {
            let (_, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorResponse = try? JSONDecoder().decode(RemoteAPIError.self, from: data) {
                    throw AppError.requestFailed(reason: errorResponse.error)
                }
                throw AppError.serverError(statusCode: httpResponse.statusCode)
            }

            return try JSONDecoder().decode(T.self, from: data)

        } catch let error as AppError {
            lastError = error
            throw error
        } catch is URLError {
            let appError = AppError.networkUnavailable
            lastError = appError
            throw appError
        } catch is DecodingError {
            let appError = AppError.decodingFailed
            lastError = appError
            throw appError
        } catch {
            let appError = AppError.requestFailed(reason: error.localizedDescription)
            lastError = appError
            throw appError
        }
    }

    private func convertMetadata(_ metadata: GameMetadata, gameType: GameType) -> [String: String] {
        var result: [String: String] = [:]

        switch gameType {
        case .wordle:
            if let guesses = metadata.guesses {
                result["guesses"] = String(guesses)
            }
            if let time = metadata.timeSeconds {
                result["time_seconds"] = String(time)
            }
        case .echo:
            if let totalScore = metadata.totalScore {
                result["total_score"] = String(totalScore)
            }
            if let roundScores = metadata.roundScores {
                result["round_scores"] = roundScores.map(String.init).joined(separator: ",")
            }
            if let perfectRounds = metadata.perfectRounds {
                result["perfect_rounds"] = String(perfectRounds)
            }
            if let totalAttempts = metadata.totalAttempts {
                result["total_attempts"] = String(totalAttempts)
            }
            if let roundsSolved = metadata.roundsSolved {
                result["rounds_solved"] = String(roundsSolved)
            }
        case .crossword:
            if let time = metadata.completionTimeSeconds {
                result["completion_time_seconds"] = String(time)
            }
            if let hints = metadata.hintsUsed {
                result["hints_used"] = String(hints)
            }
        case .trivia:
            if let correct = metadata.correctAnswers {
                result["correct_answers"] = String(correct)
            }
            if let total = metadata.totalQuestions {
                result["total_questions"] = String(total)
            }
        }

        return result
    }
}

// MARK: - Request Models

/// Request body for submitting a single score
struct RemoteScoreRequest: Codable {
    let game_type: String
    let score: Int
    let date: String
    let username: String?
    let metadata: [String: String]
}

/// Request body for batch sync
struct RemoteSyncRequest: Codable {
    let scores: [RemoteScoreRequest]
}

// MARK: - Response Models

/// Response from submitting a score
struct RemoteScoreResponse: Codable {
    let success: Bool
    let id: String
    let rank: Int?
    let username: String?
}

/// Individual leaderboard entry from server
struct RemoteLeaderboardEntry: Codable, Identifiable {
    let id: String
    let rank: Int
    let username: String
    let score: Int
    let game_type: String
    let date: String
    let metadata: [String: String]?

    /// Formatted score display based on game type
    var scoreDisplay: String {
        guard let gameType = GameType(rawValue: game_type) else {
            return "\(score)"
        }

        switch gameType {
        case .wordle:
            if let guesses = metadata?["guesses"] {
                return "\(guesses)/6"
            }
            return "\(score)"
        case .echo:
            return "\(score) pts"
        case .crossword:
            if let timeStr = metadata?["completion_time_seconds"],
               let time = Int(timeStr) {
                let minutes = time / 60
                let seconds = time % 60
                return String(format: "%d:%02d", minutes, seconds)
            }
            return "\(score)"
        case .trivia:
            if let correct = metadata?["correct_answers"],
               let total = metadata?["total_questions"] {
                return "\(correct)/\(total)"
            }
            return "\(score)"
        }
    }

    /// Secondary display info (time for Wordle, rounds for Echo)
    var secondaryDisplay: String? {
        guard let gameType = GameType(rawValue: game_type) else {
            return nil
        }

        switch gameType {
        case .wordle:
            if let timeStr = metadata?["time_seconds"],
               let time = Int(timeStr) {
                let minutes = time / 60
                let seconds = time % 60
                return String(format: "%d:%02d", minutes, seconds)
            }
        case .echo:
            if let rounds = metadata?["rounds_solved"] {
                return "\(rounds)/5 rounds"
            }
        case .crossword, .trivia:
            return nil
        }
        return nil
    }
}

/// Response from fetching leaderboard
struct RemoteLeaderboardResponse: Codable {
    let success: Bool
    let game_type: String
    let date: String
    let leaderboard: [RemoteLeaderboardEntry]
}

/// Response from batch sync
struct RemoteSyncResponse: Codable {
    let success: Bool
    let synced_count: Int
    let results: [RemoteSyncResult]
}

/// Individual sync result
struct RemoteSyncResult: Codable {
    let local_id: String?
    let remote_id: String
    let success: Bool
    let error: String?
}

/// Error response from server
struct RemoteAPIError: Codable {
    let success: Bool
    let error: String
}
