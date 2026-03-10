//
//  NewsArticle.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import Foundation

struct NewsArticle: Identifiable {
    let id: UUID
    let title: String
    let excerpt: String
    let imageURL: String
    let category: String
    let timestamp: Date
    let author: String?
    let readTime: Int?
    let isFeatured: Bool
    let articleURL: String?

    init(
        id: UUID = UUID(),
        title: String,
        excerpt: String,
        imageURL: String = "",
        category: String,
        timestamp: Date = Date(),
        author: String? = nil,
        readTime: Int? = nil,
        isFeatured: Bool = false,
        articleURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.imageURL = imageURL
        self.category = category
        self.timestamp = timestamp
        self.author = author
        self.readTime = readTime
        self.isFeatured = isFeatured
        self.articleURL = articleURL
    }
}

// MARK: - Stable Social ID
extension NewsArticle {
    /// Deterministic ID for likes/comments — same across all devices.
    /// Uses articleURL (stable from backend) instead of the random UUID.
    /// IMPORTANT: Do NOT change this format — existing Firestore data depends on it.
    var socialId: String {
        guard let url = articleURL, !url.isEmpty else { return id.uuidString }

        var cleaned = url
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")

        // Strip query string and fragment
        if let idx = cleaned.firstIndex(of: "?") { cleaned = String(cleaned[..<idx]) }
        if let idx = cleaned.firstIndex(of: "#") { cleaned = String(cleaned[..<idx]) }

        // Strip trailing slashes
        while cleaned.hasSuffix("/") { cleaned = String(cleaned.dropLast()) }

        // Replace all characters that are invalid or unsafe in Firestore document IDs
        cleaned = cleaned.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_"
                ? String(scalar)
                : "_"
        }.joined()

        // Collapse repeated underscores
        while cleaned.contains("__") {
            cleaned = cleaned.replacingOccurrences(of: "__", with: "_")
        }

        // Firestore doc IDs max 1500 bytes — cap at 200 for safety
        if cleaned.count > 200 { cleaned = String(cleaned.prefix(200)) }

        return cleaned.isEmpty ? id.uuidString : cleaned
    }
}

// MARK: - Helpers
extension NewsArticle {
    /// Returns an SF Symbol name matching the article's category, used as a fallback when no image is available.
    var categoryIcon: String {
        switch category {
        case "Campus": return "building.2.fill"
        case "City": return "building.fill"
        case "Opinion": return "text.bubble.fill"
        case "Features": return "star.fill"
        case "Arts & Culture": return "paintpalette.fill"
        case "Sports": return "sportscourt.fill"
        case "Science & Tech": return "atom"
        case "Editorial": return "doc.text.fill"
        case "Column": return "quote.bubble.fill"
        default: return "newspaper.fill"
        }
    }
}

// MARK: - Sample Data (Where we populate our data)
extension NewsArticle {
    static let sampleData: [NewsArticle] = [
        NewsArticle(
            title: "New Solar Research on West Campus Breakthrough",
            excerpt: "UC Davis researchers unveil a revolutionary solar panel design that increases efficiency by 20% in agricultural settings.",
            imageURL: "solar_research",
            category: "Research",
            timestamp: Date().addingTimeInterval(-7200),
            author: "Dr. Elena Vance",
            readTime: 5,
            isFeatured: true
        ),
        NewsArticle(
            title: "Picnic Day 2024 Schedule Announced",
            excerpt: "The annual UC Davis celebration returns with exciting new events and activities for the whole family.",
            imageURL: "picnic_day",
            category: "Campus Life",
            timestamp: Date().addingTimeInterval(-14400),
            readTime: 3,
            isFeatured: false
        ),
        NewsArticle(
            title: "Aggies Win Big in Conference Finals",
            excerpt: "The UC Davis football team secured a decisive victory against rivals in Saturday's championship game.",
            imageURL: "athletics",
            category: "Athletics",
            timestamp: Date().addingTimeInterval(-21600),
            readTime: 5,
            isFeatured: false
        )
    ]

    static var featuredArticle: NewsArticle? {
        sampleData.first { $0.isFeatured }
    }

    static var latestArticles: [NewsArticle] {
        sampleData.filter { !$0.isFeatured }
    }
}
