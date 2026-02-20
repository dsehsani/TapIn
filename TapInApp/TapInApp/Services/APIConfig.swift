//
//  APIConfig.swift
//  TapInApp
//
//  Created by Darius Ehsani on 2/12/26.
//
//  MARK: - Centralized API Configuration
//  Single source of truth for backend server URLs and settings.
//  Update baseURL when switching between local dev and production.
//

import Foundation

enum APIConfig {

    // MARK: - Base URL

    /// The backend server base URL.
    /// - Local development: "http://localhost:8080"
    /// - Google App Engine:  "https://YOUR_PROJECT.appspot.com"
    static let baseURL = "http://localhost:8080"

    // MARK: - Claude Endpoints

    /// POST - Summarize an event description
    static var summarizeURL: String { "\(baseURL)/api/claude/summarize" }

    /// POST - General-purpose Claude chat (future features)
    static var chatURL: String { "\(baseURL)/api/claude/chat" }

    /// GET - Claude proxy health check
    static var claudeHealthURL: String { "\(baseURL)/api/claude/health" }

    // MARK: - Leaderboard Endpoints

    /// Leaderboard API base path
    static var leaderboardBaseURL: String { "\(baseURL)/api/leaderboard" }

    /// POST - Submit a score for any game type
    /// Request: { game_type, score, date, user_id?, metadata }
    static var submitScoreURL: String { "\(leaderboardBaseURL)/score" }

    /// GET - Get leaderboard for a specific game and date
    /// Path: /api/leaderboard/{game_type}/{date}?limit=5
    static func leaderboardURL(gameType: String, date: String) -> String {
        "\(leaderboardBaseURL)/\(gameType)/\(date)"
    }

    /// POST - Sync multiple scores at once (batch upload)
    /// Request: { scores: [...] }
    static var syncScoresURL: String { "\(leaderboardBaseURL)/sync" }

    /// GET - Leaderboard health check
    static var leaderboardHealthURL: String { "\(leaderboardBaseURL)/health" }

    // MARK: - Auth Endpoints (Placeholder for friend's implementation)

    /// Auth API base path (will be implemented by friend)
    static var authBaseURL: String { "\(baseURL)/api/auth" }

    /// POST - Login
    static var loginURL: String { "\(authBaseURL)/login" }

    /// POST - Register
    static var registerURL: String { "\(authBaseURL)/register" }

    /// GET - Get current user profile
    static var profileURL: String { "\(authBaseURL)/profile" }

    // MARK: - Mock Mode

    /// Set to true to use fake summaries without needing the backend/API key.
    /// Set to false when your API key is ready.
    static let useMockSummaries = false

    /// Set to true to use local-only leaderboards (no remote sync)
    /// Set to false when backend is ready
    static let useLocalOnlyLeaderboards = true

    // MARK: - Summary Settings

    /// UserDefaults key for cached summaries
    static let summaryCacheKey = "cachedEventSummaries"

    /// Maximum number of cached summaries to keep in UserDefaults
    static let summaryCacheMaxSize = 200

    // MARK: - Sync Settings

    /// How often to attempt background sync (in seconds)
    static let syncIntervalSeconds: TimeInterval = 60

    /// Maximum number of scores to sync in a single batch
    static let syncBatchSize = 50

    /// Number of retry attempts for failed syncs
    static let syncMaxRetries = 3
}
