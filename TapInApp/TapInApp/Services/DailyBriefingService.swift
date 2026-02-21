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

    private let cacheKey = "cachedDailyBriefing"
    private let cacheDateKey = "cachedDailyBriefingDate"

    // MARK: - Fetch Briefing

    /// Fetches today's daily briefing. Checks local cache first, then backend.
    func fetchBriefing() async -> DailyBriefing? {
        // Check local cache (same-day only)
        let today = Self.todayString()
        if let cached = loadCachedBriefing(), cached.cacheDate == today {
            return cached.briefing
        }

        // Fetch from backend
        guard let url = URL(string: APIConfig.dailyBriefingURL) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return nil
            }

            let decoded = try JSONDecoder().decode(DailyBriefingResponse.self, from: data)
            guard decoded.success, let briefing = decoded.briefing else { return nil }

            // Cache locally
            saveBriefing(briefing, date: today)
            return briefing
        } catch {
            #if DEBUG
            print("DailyBriefingService: fetch failed — \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Local Cache

    private func loadCachedBriefing() -> (briefing: DailyBriefing, cacheDate: String)? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let date = UserDefaults.standard.string(forKey: cacheDateKey),
              let briefing = try? JSONDecoder().decode(DailyBriefing.self, from: data) else {
            return nil
        }
        return (briefing, date)
    }

    private func saveBriefing(_ briefing: DailyBriefing, date: String) {
        if let data = try? JSONEncoder().encode(briefing) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(date, forKey: cacheDateKey)
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

struct DailyBriefing: Codable {
    let summary: String
    let bulletPoints: [String]
    let articleCount: Int
    let generatedAt: String
}
