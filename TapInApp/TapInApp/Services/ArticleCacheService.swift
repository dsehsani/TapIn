//
//  ArticleCacheService.swift
//  TapInApp
//
//  MARK: - iOS Disk Cache (Layer 2)
//  Persists article lists and parsed article content to Library/Caches/TapIn/
//  so the app works offline and avoids redundant network fetches.
//
//  Article lists:   30-minute TTL (matches backend Firestore cache)
//  Article content: No TTL — permanently cached until app reinstall
//

import Foundation

final class ArticleCacheService {

    static let shared = ArticleCacheService()

    private let fileManager = FileManager.default
    private let listTTL: TimeInterval = 30 * 60  // 30 minutes

    private var cacheDirectory: URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("TapIn", isDirectory: true)
    }

    private init() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // --------------------------------------------------------------------------
    // MARK: - Article List Cache (TTL: 30 min)
    // --------------------------------------------------------------------------

    /// Loads cached article list for a category. Returns nil if missing or stale.
    func loadArticleList(category: String) -> [NewsArticle]? {
        let url = listCacheURL(category: category)
        guard let data = try? Data(contentsOf: url) else { return nil }

        // Check TTL via file modification date
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
           let modified = attrs[.modificationDate] as? Date {
            if Date().timeIntervalSince(modified) > listTTL {
                return nil  // Stale
            }
        }

        return try? JSONDecoder().decode(CachedArticleList.self, from: data).articles
    }

    /// Loads cached article list ignoring TTL. Returns whatever is on disk, even if stale.
    /// Used for instant display on launch before a network refresh completes.
    func loadArticleListIgnoringTTL(category: String) -> [NewsArticle]? {
        let url = listCacheURL(category: category)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedArticleList.self, from: data).articles
    }

    /// Saves article list for a category to disk.
    func saveArticleList(_ articles: [NewsArticle], category: String) {
        guard let data = try? JSONEncoder().encode(CachedArticleList(articles: articles)) else { return }
        try? data.write(to: listCacheURL(category: category), options: .atomic)
    }

    /// Deletes all article list cache files so the next fetch hits the backend.
    func clearAllArticleLists() {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory,
                                                                includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix("articles_") {
            try? fileManager.removeItem(at: file)
        }
    }

    // --------------------------------------------------------------------------
    // MARK: - Article Content Cache (No TTL)
    // --------------------------------------------------------------------------

    /// Loads permanently cached ArticleContent for a given article URL string.
    func loadArticleContent(articleURL: String) -> ArticleContent? {
        let url = contentCacheURL(articleURL: articleURL)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedArticleContent.self, from: data).toArticleContent()
    }

    /// Saves parsed ArticleContent to disk permanently.
    func saveArticleContent(_ content: ArticleContent, articleURL: String) {
        let cached = CachedArticleContent(from: content)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: contentCacheURL(articleURL: articleURL), options: .atomic)
    }

    // --------------------------------------------------------------------------
    // MARK: - Private Helpers
    // --------------------------------------------------------------------------

    private func listCacheURL(category: String) -> URL {
        let safe = category.replacingOccurrences(of: "/", with: "-")
        return cacheDirectory.appendingPathComponent("articles_\(safe).json")
    }

    private func contentCacheURL(articleURL: String) -> URL {
        // Use a short hash of the URL as the filename
        let hash = articleURL.hash
        return cacheDirectory.appendingPathComponent("content_\(hash).json")
    }
}

// --------------------------------------------------------------------------
// MARK: - Codable Wrappers
// --------------------------------------------------------------------------

// NewsArticle wrapper — matches JSON shape from /api/articles backend response
private struct CachedArticleList: Codable {
    let articles: [NewsArticle]
}

extension NewsArticle: Codable {
    enum CodingKeys: String, CodingKey {
        case title, excerpt, imageURL, category, author, readTime, articleURL
        case publishDate
    }

    private static let iso8601 = ISO8601DateFormatter()

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title       = try c.decode(String.self, forKey: .title)
        self.excerpt     = try c.decode(String.self, forKey: .excerpt)
        self.imageURL    = try c.decodeIfPresent(String.self, forKey: .imageURL) ?? ""
        self.category    = try c.decode(String.self, forKey: .category)
        self.author      = try c.decodeIfPresent(String.self, forKey: .author)
        self.readTime    = try c.decodeIfPresent(Int.self, forKey: .readTime)
        self.articleURL  = try c.decodeIfPresent(String.self, forKey: .articleURL)
        self.isFeatured  = false

        let dateStr = try c.decodeIfPresent(String.self, forKey: .publishDate) ?? ""
        self.timestamp = NewsArticle.iso8601.date(from: dateStr) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title,      forKey: .title)
        try c.encode(excerpt,    forKey: .excerpt)
        try c.encode(imageURL,   forKey: .imageURL)
        try c.encode(category,   forKey: .category)
        try c.encodeIfPresent(author,     forKey: .author)
        try c.encodeIfPresent(readTime,   forKey: .readTime)
        try c.encodeIfPresent(articleURL, forKey: .articleURL)
        try c.encode(NewsArticle.iso8601.string(from: timestamp), forKey: .publishDate)
    }
}

private let sharedISO8601 = ISO8601DateFormatter()

// ArticleContent wrapper for disk persistence
private struct CachedArticleContent: Codable {
    let title: String
    let author: String
    let authorEmail: String?
    let publishDate: String    // ISO 8601
    let category: String
    let thumbnailURL: String?
    let bodyParagraphs: [String]
    let articleURL: String

    init(from content: ArticleContent) {
        self.title          = content.title
        self.author         = content.author
        self.authorEmail    = content.authorEmail
        self.publishDate    = sharedISO8601.string(from: content.publishDate)
        self.category       = content.category
        self.thumbnailURL   = content.thumbnailURL?.absoluteString
        self.bodyParagraphs = content.bodyParagraphs
        self.articleURL     = content.articleURL.absoluteString
    }

    func toArticleContent() -> ArticleContent? {
        guard let url = URL(string: articleURL) else { return nil }
        return ArticleContent(
            title:          title,
            author:         author,
            authorEmail:    authorEmail,
            publishDate:    sharedISO8601.date(from: publishDate) ?? Date(),
            category:       category,
            thumbnailURL:   thumbnailURL.flatMap { URL(string: $0) },
            bodyParagraphs: bodyParagraphs,
            articleURL:     url
        )
    }
}
