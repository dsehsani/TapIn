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
    static let baseURL = "https://tapin-backend-516122189377.us-west2.run.app/"

    // MARK: - Events Endpoint

    /// GET - All AI-processed campus events (with aiSummary + aiBulletPoints)
    static var eventsURL: String { "\(baseURL)/api/events" }

    // MARK: - Claude Endpoints

    /// POST - Summarize an event description
    static var summarizeURL: String { "\(baseURL)/api/claude/summarize" }

    /// POST - General-purpose Claude chat (future features)
    static var chatURL: String { "\(baseURL)/api/claude/chat" }

    /// GET - Claude proxy health check
    static var claudeHealthURL: String { "\(baseURL)/api/claude/health" }

    // MARK: - Mock Mode

    /// Set to true to use fake summaries without needing the backend/API key.
    /// Set to false when your API key is ready.
    static let useMockSummaries = false

    // MARK: - Summary Settings

    /// UserDefaults key for cached summaries
    static let summaryCacheKey = "cachedEventSummaries"

    /// Maximum number of cached summaries to keep in UserDefaults
    static let summaryCacheMaxSize = 200
}
