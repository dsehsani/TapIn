//
//  DailyBriefingService.swift
//  TapInApp
//
//  MARK: - Daily Briefing Service
//  Fetches the AI daily news briefing from the backend.
//  Includes local UserDefaults caching so the briefing persists across app launches.
//

import Foundation

class DailyBriefingService {

    static let shared = DailyBriefingService()
    private init() {}

    // MARK: - Fetch Briefing

    /// Fetches today's daily briefing. Checks local cache first, then backend.
    /// When interests are provided, the cache is scoped per interest set and
    /// the backend receives them as a query param for personalized generation.
    func fetchBriefing(interests: [String] = []) async -> DailyBriefing? {
        let cacheKey = self.cacheKey(for: interests)
        let dateKey = cacheKey + "_date"

        // Check local cache (same-day only)
        let today = Self.todayString()
        if let cached = loadCachedBriefing(cacheKey: cacheKey, dateKey: dateKey), cached.cacheDate == today {
            return cached.briefing
        }

        // Build URL with optional interests query param
        guard var components = URLComponents(string: APIConfig.dailyBriefingURL) else { return nil }
        if !interests.isEmpty {
            components.queryItems = [URLQueryItem(name: "interests", value: interests.joined(separator: ","))]
        }
        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return nil
            }

            let decoded = try JSONDecoder().decode(DailyBriefingResponse.self, from: data)
            guard decoded.success, let briefing = decoded.briefing else { return nil }

            // Cache locally (scoped by interests)
            saveBriefing(briefing, cacheKey: cacheKey, dateKey: dateKey, date: today)
            return briefing
        } catch {
            #if DEBUG
            print("DailyBriefingService: fetch failed — \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Cache Key Scoping

    private func cacheKey(for interests: [String]) -> String {
        if interests.isEmpty { return "cachedDailyBriefing" }
        let suffix = interests.sorted().joined(separator: ",").lowercased()
        return "cachedDailyBriefing_\(suffix.hashValue)"
    }

    // MARK: - Local Cache

    private func loadCachedBriefing(cacheKey: String, dateKey: String) -> (briefing: DailyBriefing, cacheDate: String)? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let date = UserDefaults.standard.string(forKey: dateKey),
              let briefing = try? JSONDecoder().decode(DailyBriefing.self, from: data) else {
            return nil
        }
        return (briefing, date)
    }

    private func saveBriefing(_ briefing: DailyBriefing, cacheKey: String, dateKey: String, date: String) {
        if let data = try? JSONEncoder().encode(briefing) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(date, forKey: dateKey)
        }
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: Date())
    }
}

// MARK: - Response Models

struct DailyBriefingResponse: Decodable {
    let success: Bool
    let briefing: DailyBriefing?
}

struct BriefingItem: Codable, Identifiable {
    let type: String        // "article" or "event"
    let title: String
    let subtitle: String
    let emoji: String
    let imageURL: String?
    let linkURL: String?

    var id: String { "\(type)_\(title)" }
}

struct DailyBriefing: Codable {
    let summary: String
    let bulletPoints: [String]
    let articleCount: Int
    let generatedAt: String
    let heroTitle: String?
    let items: [BriefingItem]?
}
