//
//  ArticleReadTracker.swift
//  TapInApp
//
//  Created by Claude on 3/2/26.
//
//  MARK: - Article Read Tracker
//  Tracks which articles the user taps and builds category-level affinity scores.
//  Entirely client-side with UserDefaults persistence.
//

import Foundation

// MARK: - Models

struct ArticleReadRecord: Codable {
    let articleURL: String
    let category: String
    let timestamp: Date
}

struct ArticleCategoryAffinity: Codable {
    var categoryCounts: [String: Int] = [:]
    var totalReads: Int = 0
}

// MARK: - Tracker

class ArticleReadTracker {

    static let shared = ArticleReadTracker()

    private let historyKey = "articleReadHistory"
    private let affinityKey = "articleCategoryAffinity"
    private let maxRecords = 200

    private(set) var readHistory: [ArticleReadRecord] = []
    private(set) var affinity = ArticleCategoryAffinity()

    private var readURLs: Set<String> = []

    private init() {
        loadHistory()
        loadAffinity()
        readURLs = Set(readHistory.map { $0.articleURL })
    }

    // MARK: - Tracking

    func trackRead(article: NewsArticle) {
        guard let url = article.articleURL, !url.isEmpty else { return }

        // Dedup — don't record the same article twice
        guard !readURLs.contains(url) else { return }

        let record = ArticleReadRecord(
            articleURL: url,
            category: article.category,
            timestamp: Date()
        )

        readHistory.append(record)
        readURLs.insert(url)

        // Rolling window — keep only the most recent records
        if readHistory.count > maxRecords {
            let removed = readHistory.removeFirst()
            // Rebuild readURLs only if the removed URL doesn't appear elsewhere
            if !readHistory.contains(where: { $0.articleURL == removed.articleURL }) {
                readURLs.remove(removed.articleURL)
            }
            rebuildAffinity()
        } else {
            // Incremental update
            affinity.categoryCounts[article.category, default: 0] += 1
            affinity.totalReads += 1
        }

        saveHistory()
        saveAffinity()
    }

    func hasRead(articleURL: String?) -> Bool {
        guard let url = articleURL, !url.isEmpty else { return false }
        return readURLs.contains(url)
    }

    // MARK: - Scoring

    /// Normalized category score: count / maxCount across all categories. Returns 0.0–1.0.
    func categoryScore(for category: String) -> Double {
        guard let count = affinity.categoryCounts[category], count > 0 else { return 0.0 }
        let maxCount = affinity.categoryCounts.values.max() ?? 1
        guard maxCount > 0 else { return 0.0 }
        return Double(count) / Double(maxCount)
    }

    var hasHistory: Bool { !readHistory.isEmpty }

    // MARK: - Private

    private func rebuildAffinity() {
        var newAffinity = ArticleCategoryAffinity()
        for record in readHistory {
            newAffinity.categoryCounts[record.category, default: 0] += 1
            newAffinity.totalReads += 1
        }
        affinity = newAffinity
    }

    // MARK: - Persistence

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(readHistory) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([ArticleReadRecord].self, from: data) {
            readHistory = decoded
        }
    }

    private func saveAffinity() {
        if let data = try? JSONEncoder().encode(affinity) {
            UserDefaults.standard.set(data, forKey: affinityKey)
        }
    }

    private func loadAffinity() {
        if let data = UserDefaults.standard.data(forKey: affinityKey),
           let decoded = try? JSONDecoder().decode(ArticleCategoryAffinity.self, from: data) {
            affinity = decoded
        }
    }
}
