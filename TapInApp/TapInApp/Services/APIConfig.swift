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

    // MARK: - Articles Endpoint

    /// GET /api/articles?category=xxx — Firestore-cached Aggie article list
    static func articlesURL(category: String) -> String {
        "\(baseURL)api/articles?category=\(category)"
    }

    // MARK: - Article Search Endpoint

    /// GET /api/articles/search?q=<query> — Full-text search across all archived articles
    static func articleSearchURL(query: String) -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return "\(baseURL)api/articles/search?q=\(encoded)"
    }

    // MARK: - Article Content Endpoint

    /// GET /api/articles/content?url=<encoded_url> — Scraped article body (Firestore-cached)
    static func articleContentURL(articleURL: String) -> String {
        let encoded = articleURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? articleURL
        return "\(baseURL)api/articles/content?url=\(encoded)"
    }

    // MARK: - Daily Briefing Endpoint

    /// GET /api/articles/daily-briefing — Today's AI news summary
    static var dailyBriefingURL: String { "\(baseURL)api/articles/daily-briefing" }

    // MARK: - Pipes Game Endpoint

    /// GET - Daily pipes puzzle (AI-generated or fallback)
    static var pipesDailyURL: String { "\(baseURL)api/pipes/daily" }

    // MARK: - Claude Endpoints

    /// POST - Summarize an event description
    static var summarizeURL: String { "\(baseURL)/api/claude/summarize" }

    /// POST - General-purpose Claude chat (future features)
    static var chatURL: String { "\(baseURL)/api/claude/chat" }

    /// GET - Claude proxy health check
    static var claudeHealthURL: String { "\(baseURL)/api/claude/health" }

    // MARK: - User Auth Endpoints

    /// POST - Apple Sign-In (sends identityToken + appleUserId)
    static var authAppleURL: String { "\(baseURL)api/users/auth/apple" }

    /// POST - Google Sign-In (sends idToken + googleUserId)
    static var authGoogleURL: String { "\(baseURL)api/users/auth/google" }

    /// POST - Phone auth (sends phoneNumber + smsToken)
    static var authPhoneURL: String { "\(baseURL)api/users/auth/phone" }

    /// POST - Email/password registration
    static var registerURL: String { "\(baseURL)api/users/register" }

    /// POST - Email/password login
    static var loginURL: String { "\(baseURL)api/users/login" }

    /// GET - Current user profile (requires Bearer token)
    static var meURL: String { "\(baseURL)api/users/me" }

    /// PATCH - Update game stats
    static func gameStatsURL(gameType: String) -> String {
        "\(baseURL)api/users/me/games/\(gameType)"
    }

    /// PATCH/GET - Wordle per-date progress
    static var wordleProgressURL: String { "\(baseURL)api/users/me/wordle-progress" }

    /// GET/POST - Saved articles
    static var savedArticlesURL: String { "\(baseURL)api/users/me/articles/saved" }

    /// DELETE - Unsave article
    static func unsaveArticleURL(articleId: String) -> String {
        let encoded = articleId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? articleId
        return "\(baseURL)api/users/me/articles/saved/\(encoded)"
    }

    /// GET/POST - Event RSVPs
    static var eventRSVPsURL: String { "\(baseURL)api/users/me/events" }

    /// DELETE - Cancel RSVP
    static func cancelRSVPURL(eventId: String) -> String {
        let encoded = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventId
        return "\(baseURL)api/users/me/events/\(encoded)"
    }

    /// GET - User health check
    static var usersHealthURL: String { "\(baseURL)api/users/health" }

    // MARK: - Legal Pages

    /// Privacy Policy web page
    static var privacyURL: URL { URL(string: "\(baseURL)privacy")! }

    /// Terms of Service web page
    static var termsURL: URL { URL(string: "\(baseURL)terms")! }

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
