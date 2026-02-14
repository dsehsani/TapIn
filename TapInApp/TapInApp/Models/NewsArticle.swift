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
