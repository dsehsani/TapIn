//
//  ClaudeAPIService.swift
//  TapInApp
//
//  Created by Darius Ehsani on 2/12/26.
//
//  MARK: - Claude API Service
//  Communicates with the TapIn Backend proxy (NOT Claude directly).
//  Handles event summary requests with UserDefaults caching.
//  Reusable for any future Claude-powered features.
//

import Foundation
import CryptoKit

// MARK: - Claude API Service

class ClaudeAPIService {

    static let shared = ClaudeAPIService()

    private init() {}

    // MARK: - Summary Cache (UserDefaults)

    /// Returns cached summary for a description, or nil if not cached.
    private func cachedSummary(for description: String) -> String? {
        guard let cache = UserDefaults.standard.dictionary(forKey: APIConfig.summaryCacheKey) as? [String: String] else {
            return nil
        }
        let key = cacheKey(for: description)
        return cache[key]
    }

    /// Stores a summary in the UserDefaults cache.
    private func cacheSummary(_ summary: String, for description: String) {
        var cache = (UserDefaults.standard.dictionary(forKey: APIConfig.summaryCacheKey) as? [String: String]) ?? [:]

        // Evict oldest entries if cache is full
        if cache.count >= APIConfig.summaryCacheMaxSize {
            let keysToRemove = Array(cache.keys.prefix(cache.count - APIConfig.summaryCacheMaxSize + 1))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }

        cache[cacheKey(for: description)] = summary
        UserDefaults.standard.set(cache, forKey: APIConfig.summaryCacheKey)
    }

    /// Creates a SHA256 hash key for a description string.
    private func cacheKey(for description: String) -> String {
        let data = Data(description.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    // MARK: - Summarize Event

    /// Fetches an AI summary for an event description.
    /// Returns cached result instantly if available, otherwise calls the backend.
    ///
    /// - Parameter description: The full event description text.
    /// - Returns: A short AI-generated summary string, or nil on failure.
    func summarizeEvent(description: String) async -> String? {
        // Mock mode — returns a fake summary for UI testing
        if APIConfig.useMockSummaries {
            return generateMockSummary(from: description)
        }

        // Check cache first
        if let cached = cachedSummary(for: description) {
            return cached
        }

        // Call backend proxy
        guard let url = URL(string: APIConfig.summarizeURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = ["description": description]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success,
                  let summary = json["summary"] as? String else {
                return nil
            }

            // Cache the result
            cacheSummary(summary, for: description)

            return summary
        } catch {
            return nil
        }
    }

    // MARK: - Mock Summary Generator

    /// Generates a fake summary by taking the first sentence of the description.
    /// Used for UI testing when no API key is available.
    private func generateMockSummary(from description: String) -> String {
        let cleaned = description
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Take first sentence or first 100 chars
        if let dotRange = cleaned.range(of: ". ") ?? cleaned.range(of: ".") {
            let firstSentence = String(cleaned[cleaned.startIndex..<dotRange.upperBound]).trimmingCharacters(in: .whitespaces)
            if firstSentence.count > 10 {
                return firstSentence
            }
        }

        // Fallback: truncate to ~100 chars at a word boundary
        if cleaned.count > 100 {
            let truncated = String(cleaned.prefix(100))
            if let lastSpace = truncated.lastIndex(of: " ") {
                return String(truncated[truncated.startIndex..<lastSpace]) + "..."
            }
            return truncated + "..."
        }

        return cleaned
    }

    // MARK: - Event Bullet Points

    /// Generates emoji bullet points for an event's About section.
    /// Returns cached result instantly if available, otherwise calls the backend.
    ///
    /// - Parameters:
    ///   - title: The event title.
    ///   - description: The full event description text.
    /// - Returns: An array of emoji bullet point strings, or nil on failure.
    func generateEventBulletPoints(title: String, description: String) async -> [String]? {
        let cacheStoreKey = "eventBullets_" + cacheKey(for: title + description)

        if let cached = UserDefaults.standard.array(forKey: cacheStoreKey) as? [String], !cached.isEmpty {
            return cached
        }

        if APIConfig.useMockSummaries {
            return generateMockBulletPoints(from: description)
        }

        let message = """
        Extract the 3 to 5 most important facts from this campus event. \
        Return ONLY emoji bullet points, one per line, with no extra text, headers, or markdown. \
        Each line must start with a relevant emoji followed by a space, then a brief phrase under 12 words. \
        Pick emojis that match the content (📍 location, 💰 cost, 🎓 academic, 🍕 food, 🎤 speaker, 🕐 time, 🔗 link, etc.).

        Event: \(title)

        \(description)
        """

        guard let response = await chat(message: message, maxTokens: 200) else {
            return nil
        }

        let lines = response
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        UserDefaults.standard.set(lines, forKey: cacheStoreKey)
        return lines
    }

    private func generateMockBulletPoints(from description: String) -> [String] {
        let cleaned = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentences = cleaned.components(separatedBy: ". ").filter { !$0.isEmpty }
        let emojis = ["📌", "🗓️", "📍", "🎯", "ℹ️"]
        return zip(emojis, sentences.prefix(4)).map { "\($0) \($1.trimmingCharacters(in: .whitespaces))" }
    }

    // MARK: - General Chat (Future Use)

    /// Sends a message to Claude via the backend proxy.
    /// Use this for future features like campus Q&A, study help, etc.
    /// Requires authentication — sends the backend JWT token.
    ///
    /// - Parameters:
    ///   - message: The user's message.
    ///   - maxTokens: Max response length (default 300, server caps at 1000).
    /// - Returns: Claude's response string, or nil on failure.
    func chat(message: String, maxTokens: Int = 300) async -> String? {
        guard let url = URL(string: APIConfig.chatURL) else { return nil }
        guard let token = await AppState.shared.backendToken else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "message": message,
            "max_tokens": maxTokens
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success,
                  let responseText = json["response"] as? String else {
                return nil
            }

            return responseText
        } catch {
            return nil
        }
    }
}
