//
//  LeaderboardService.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/31/26.
//
//  MARK: - Leaderboard API Service
//  This service handles all communication with the Wordle Leaderboard backend.
//
//  Architecture:
//  - Uses async/await for network requests
//  - Singleton pattern for app-wide access
//  - Communicates with Flask server running locally or deployed
//
//  Endpoints:
//  - POST /api/leaderboard/score - Submit a score
//  - GET /api/leaderboard/<date> - Get leaderboard for a date
//
//  Integration Notes:
//  - Call submitScore() from GameViewModel when game ends
//  - Call fetchLeaderboard() to display rankings
//  - Uses AppError for consistent error handling
//

import Foundation
import Combine

// MARK: - Leaderboard Service

/// Service class for communicating with the Wordle Leaderboard API.
///
/// Provides methods for:
/// - Submitting scores after game completion
/// - Fetching daily leaderboards
///
/// Usage:
/// ```swift
/// // Submit a score
/// let response = try await LeaderboardService.shared.submitScore(
///     guesses: 4,
///     timeSeconds: 120,
///     puzzleDate: "2026-02-02"
/// )
///
/// // Fetch leaderboard
/// let entries = try await LeaderboardService.shared.fetchLeaderboard(for: "2026-02-02")
/// ```
///
@MainActor
class LeaderboardService: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide access
    static let shared = LeaderboardService()

    // MARK: - Configuration

    /// Base URL for the leaderboard API
    /// Change this when deploying to Google App Engine
    private let baseURL: String

    /// URL session for network requests
    private let session: URLSession

    // MARK: - Published State

    /// Whether a network request is in progress
    @Published var isLoading: Bool = false

    /// Last error encountered (if any)
    @Published var lastError: AppError?

    // MARK: - Initialization

    private init() {
        // Use localhost for development
        // TODO: Update to App Engine URL when deployed
        self.baseURL = "http://localhost:8080/api/leaderboard"

        // Configure URL session with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Submit Score

    /// Submits a score to the leaderboard API.
    ///
    /// - Parameters:
    ///   - guesses: Number of guesses taken (1-6)
    ///   - timeSeconds: Time taken to complete the puzzle in seconds
    ///   - puzzleDate: The date of the puzzle (YYYY-MM-DD format)
    ///
    /// - Returns: The submitted score response from the server
    /// - Throws: AppError if the request fails
    ///
    /// Example:
    /// ```swift
    /// do {
    ///     let response = try await LeaderboardService.shared.submitScore(
    ///         guesses: 4,
    ///         timeSeconds: 120,
    ///         puzzleDate: "2026-02-02"
    ///     )
    ///     print("Score submitted! Username: \(response.score.username)")
    /// } catch {
    ///     print("Failed to submit score: \(error)")
    /// }
    /// ```
    func submitScore(guesses: Int, timeSeconds: Int, puzzleDate: String) async throws -> ScoreSubmissionResponse {
        isLoading = true
        lastError = nil

        defer { isLoading = false }

        // Build request URL
        guard let url = URL(string: "\(baseURL)/score") else {
            throw AppError.requestFailed(reason: "Invalid URL")
        }

        // Create request body
        let requestBody = ScoreSubmissionRequest(
            guesses: guesses,
            time_seconds: timeSeconds,
            puzzle_date: puzzleDate
        )

        // Configure request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encode request body
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AppError.requestFailed(reason: "Failed to encode request")
        }

        // Perform request
        do {
            let (data, response) = try await session.data(for: request)

            // Check HTTP status code
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error message from server
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw AppError.requestFailed(reason: errorResponse.error)
                }
                throw AppError.serverError(statusCode: httpResponse.statusCode)
            }

            // Decode response
            let decoder = JSONDecoder()
            return try decoder.decode(ScoreSubmissionResponse.self, from: data)

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

    // MARK: - Fetch Leaderboard

    /// Fetches the leaderboard for a specific puzzle date.
    ///
    /// - Parameters:
    ///   - puzzleDate: The date in YYYY-MM-DD format
    ///   - limit: Maximum number of entries (default: 5, max: 10)
    ///
    /// - Returns: Array of leaderboard entries sorted by rank
    /// - Throws: AppError if the request fails
    ///
    /// Example:
    /// ```swift
    /// do {
    ///     let entries = try await LeaderboardService.shared.fetchLeaderboard(for: "2026-02-02")
    ///     for entry in entries {
    ///         print("\(entry.rank). \(entry.username) - \(entry.guessesDisplay)")
    ///     }
    /// } catch {
    ///     print("Failed to fetch leaderboard: \(error)")
    /// }
    /// ```
    func fetchLeaderboard(for puzzleDate: String, limit: Int = 5) async throws -> [LeaderboardEntryResponse] {
        isLoading = true
        lastError = nil

        defer { isLoading = false }

        // Build request URL with query parameter
        guard var urlComponents = URLComponents(string: "\(baseURL)/\(puzzleDate)") else {
            throw AppError.requestFailed(reason: "Invalid URL")
        }
        urlComponents.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        guard let url = urlComponents.url else {
            throw AppError.requestFailed(reason: "Invalid URL")
        }

        // Perform request
        do {
            let (data, response) = try await session.data(from: url)

            // Check HTTP status code
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw AppError.requestFailed(reason: errorResponse.error)
                }
                throw AppError.serverError(statusCode: httpResponse.statusCode)
            }

            // Decode response
            let decoder = JSONDecoder()
            let leaderboardResponse = try decoder.decode(LeaderboardResponse.self, from: data)
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

    // MARK: - Health Check

    /// Checks if the leaderboard server is reachable.
    ///
    /// - Returns: True if the server is healthy
    func isServerHealthy() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
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
}

// MARK: - Request/Response Models

/// Request body for submitting a score
struct ScoreSubmissionRequest: Codable {
    let guesses: Int
    let time_seconds: Int
    let puzzle_date: String
}

/// Response from submitting a score
struct ScoreSubmissionResponse: Codable {
    let success: Bool
    let score: ScoreResponse
}

/// Score data returned from server
struct ScoreResponse: Codable {
    let id: String
    let username: String
    let guesses: Int
    let time_seconds: Int
    let puzzle_date: String
}

/// Response from fetching leaderboard
struct LeaderboardResponse: Codable {
    let success: Bool
    let puzzle_date: String
    let leaderboard: [LeaderboardEntryResponse]
}

/// Individual leaderboard entry
struct LeaderboardEntryResponse: Codable, Identifiable {
    let rank: Int
    let username: String
    let guesses: Int
    let guesses_display: String
    let time_seconds: Int

    /// Computed ID for SwiftUI lists
    var id: String { "\(rank)-\(username)" }

    /// Alias for guesses_display to match Swift naming conventions
    var guessesDisplay: String { guesses_display }

    /// Alias for time_seconds to match Swift naming conventions
    var timeSeconds: Int { time_seconds }
}

/// Error response from server
struct APIErrorResponse: Codable {
    let success: Bool
    let error: String
}
