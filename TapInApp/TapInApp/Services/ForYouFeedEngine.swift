//
//  ForYouFeedEngine.swift
//  TapInApp
//
//  Created by Claude on 3/2/26.
//
//  MARK: - For You Feed Engine
//  Scores and assembles a personalized feed by interleaving articles and events
//  based on user interests, saved content, and read history.
//

import Foundation

// MARK: - Feed Result

struct ForYouFeedResult {
    let featured: NewsArticle?
    let articles: [NewsArticle]
    let topEvents: [CampusEvent]
}

// MARK: - Engine

class ForYouFeedEngine {

    // Interest → Category mapping
    private static let interestCategoryMap: [String: [String]] = [
        "Sports": ["Sports"],
        "Arts & Entertainment": ["Arts & Culture", "Features"],
        "Science & Tech": ["Science & Tech"],
        "Campus Life": ["Campus", "Features"],
        "Politics": ["Opinion", "Editorial", "City"],
        "Health & Wellness": ["Features", "Science & Tech"],
        "Food & Dining": ["Features", "City"]
    ]

    // Interest keywords for fuzzy event matching
    private static let interestKeywords: [String: [String]] = [
        "Sports": ["sport", "athletic", "game", "match", "tournament", "basketball", "football", "soccer", "baseball", "tennis", "volleyball", "swim", "track", "field", "gym", "fitness", "recreation"],
        "Arts & Entertainment": ["art", "music", "theater", "theatre", "dance", "film", "concert", "gallery", "exhibit", "performance", "comedy", "show", "creative", "painting", "sculpture"],
        "Science & Tech": ["science", "tech", "research", "lab", "stem", "engineering", "computer", "coding", "programming", "data", "ai", "robot", "physics", "chemistry", "biology", "math"],
        "Campus Life": ["campus", "student", "club", "organization", "social", "meeting", "mixer", "orientation", "welcome", "community"],
        "Politics": ["politic", "government", "election", "vote", "debate", "policy", "senate", "council", "activist", "protest", "rally"],
        "Health & Wellness": ["health", "wellness", "mental", "meditation", "yoga", "counseling", "therapy", "nutrition", "fitness", "wellbeing", "self-care"],
        "Food & Dining": ["food", "dining", "cook", "bake", "recipe", "restaurant", "cafe", "coffee", "pizza", "taco", "brunch", "lunch", "dinner", "potluck"]
    ]

    // MARK: - Build Feed

    func buildFeed(
        articles: [NewsArticle],
        events: [CampusEvent],
        userInterests: [String],
        savedArticles: [NewsArticle],
        savedEvents: [CampusEvent]
    ) -> ForYouFeedResult {
        let readTracker = ArticleReadTracker.shared
        let prefEngine = EventPreferenceEngine.shared

        // Build saved-article category counts for affinity signal
        let savedCategoryCounts = buildSavedCategoryCounts(savedArticles)

        // Score and sort articles
        let scoredArticles = articles.map { article -> (NewsArticle, Double) in
            let score = scoreArticle(
                article,
                userInterests: userInterests,
                savedCategoryCounts: savedCategoryCounts,
                readTracker: readTracker
            )
            return (article, score)
        }
        .sorted { $0.1 > $1.1 }

        // Score and sort events, cap at 15
        let now = Date()
        let upcomingEvents = events.filter { $0.date >= Calendar.current.startOfDay(for: now) }
        let scoredEvents = upcomingEvents.map { event -> (CampusEvent, Double) in
            let score = scoreEvent(
                event,
                userInterests: userInterests,
                prefEngine: prefEngine
            )
            return (event, score)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(15)
        .map { $0.0 }

        // Extract featured article (highest scored)
        let featured: NewsArticle?
        let remainingArticles: [NewsArticle]
        if let topArticle = scoredArticles.first {
            let a = topArticle.0
            featured = NewsArticle(
                id: a.id,
                title: a.title,
                excerpt: a.excerpt,
                imageURL: a.imageURL,
                category: a.category,
                timestamp: a.timestamp,
                author: a.author,
                readTime: a.readTime,
                isFeatured: true,
                articleURL: a.articleURL
            )
            remainingArticles = Array(scoredArticles.dropFirst().map { $0.0 })
        } else {
            featured = nil
            remainingArticles = []
        }

        return ForYouFeedResult(
            featured: featured,
            articles: remainingArticles,
            topEvents: Array(scoredEvents)
        )
    }

    // MARK: - Article Scoring

    private func scoreArticle(
        _ article: NewsArticle,
        userInterests: [String],
        savedCategoryCounts: [String: Int],
        readTracker: ArticleReadTracker
    ) -> Double {
        var score = 0.0

        // Signal 1: User interests (40%)
        let interestScore = interestMatchScore(for: article.category, interests: userInterests)
        score += interestScore * 0.40

        // Signal 2: Saved content affinity (35%)
        let savedScore = savedCategoryScore(for: article.category, counts: savedCategoryCounts)
        score += savedScore * 0.35

        // Signal 3: Read history affinity (25%)
        let readScore = readTracker.categoryScore(for: article.category)
        score += readScore * 0.25

        // Recency boost: +0.15 max, linear decay over 24h
        let hoursSincePublish = Date().timeIntervalSince(article.timestamp) / 3600.0
        if hoursSincePublish < 24 {
            score += 0.15 * (1.0 - hoursSincePublish / 24.0)
        }

        // Already-read penalty
        if readTracker.hasRead(articleURL: article.articleURL) {
            score *= 0.5
        }

        return min(score, 1.0)
    }

    private func interestMatchScore(for category: String, interests: [String]) -> Double {
        for interest in interests {
            if let mappedCategories = Self.interestCategoryMap[interest] {
                if mappedCategories.contains(category) {
                    return 1.0
                }
            }
        }
        return 0.0
    }

    private func savedCategoryScore(for category: String, counts: [String: Int]) -> Double {
        guard let count = counts[category], count > 0 else { return 0.0 }
        let maxCount = counts.values.max() ?? 1
        guard maxCount > 0 else { return 0.0 }
        return Double(count) / Double(maxCount)
    }

    private func buildSavedCategoryCounts(_ savedArticles: [NewsArticle]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for article in savedArticles {
            counts[article.category, default: 0] += 1
        }
        return counts
    }

    // MARK: - Event Scoring

    private func scoreEvent(
        _ event: CampusEvent,
        userInterests: [String],
        prefEngine: EventPreferenceEngine
    ) -> Double {
        var score = 0.0

        // Signal 1: EventPreferenceEngine (50%)
        let prefScore = prefEngine.score(event: event)
        score += prefScore * 0.50

        // Signal 2: User interest keyword match (30%)
        let keywordScore = eventInterestKeywordScore(event: event, interests: userInterests)
        score += keywordScore * 0.30

        // Signal 3: Urgency (20%)
        let urgencyScore: Double
        switch event.dateUrgency {
        case .today: urgencyScore = 1.0
        case .tomorrow: urgencyScore = 0.7
        case .thisWeek: urgencyScore = 0.4
        case .later: urgencyScore = 0.1
        }
        score += urgencyScore * 0.20

        return min(score, 1.0)
    }

    private func eventInterestKeywordScore(event: CampusEvent, interests: [String]) -> Double {
        guard !interests.isEmpty else { return 0.0 }

        let searchableText = [
            event.title,
            event.eventType ?? "",
            event.organizerName ?? "",
            event.tags.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        var matchCount = 0
        for interest in interests {
            guard let keywords = Self.interestKeywords[interest] else { continue }
            for keyword in keywords {
                if searchableText.contains(keyword) {
                    matchCount += 1
                    break // One match per interest is enough
                }
            }
        }

        guard !interests.isEmpty else { return 0.0 }
        return Double(matchCount) / Double(interests.count)
    }
}
