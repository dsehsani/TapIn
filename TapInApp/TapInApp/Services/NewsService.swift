//
//  NewsService.swift
//  TapInApp
//
//  Created by Claude on 2/14/26.
//
//  MARK: - News Service
//  Fetches RSS feeds from The Aggie (theaggie.org) and returns parsed NewsArticle models.
//

import Foundation

class NewsService {

    // MARK: - Caches
    private let parser = AggieArticleParser()
    private var contentCache: [String: ArticleContent] = [:]   // In-memory (session)
    private let diskCache = ArticleCacheService.shared         // FileManager (persistent)

    // MARK: - Feed URLs

    /// Base URL for The Aggie RSS feeds
    private static let baseURL = "https://theaggie.org"

    /// RSS feed paths for each category
    enum NewsCategory: String, CaseIterable {
        case all = ""
        case campus = "campus"
        case city = "city"
        case opinion = "opinion"
        case features = "features"
        case artsCulture = "arts-culture"
        case sports = "sports"
        case scienceTech = "science-technology"
        case editorial = "editorial"
        case column = "column"

        var feedURL: URL {
            if self == .all {
                return URL(string: "\(NewsService.baseURL)/feed/")!
            }
            return URL(string: "\(NewsService.baseURL)/category/\(self.rawValue)/feed/")!
        }

        var displayName: String {
            switch self {
            case .all: return "All News"
            case .campus: return "Campus"
            case .city: return "City"
            case .opinion: return "Opinion"
            case .features: return "Features"
            case .artsCulture: return "Arts & Culture"
            case .sports: return "Sports"
            case .scienceTech: return "Science & Tech"
            case .editorial: return "Editorial"
            case .column: return "Column"
            }
        }

        var icon: String {
            switch self {
            case .all: return "newspaper.fill"
            case .campus: return "building.2.fill"
            case .city: return "building.fill"
            case .opinion: return "text.bubble.fill"
            case .features: return "star.fill"
            case .artsCulture: return "paintpalette.fill"
            case .sports: return "sportscourt.fill"
            case .scienceTech: return "atom"
            case .editorial: return "doc.text.fill"
            case .column: return "quote.bubble.fill"
            }
        }
    }

    // MARK: - Errors

    enum ServiceError: LocalizedError {
        case invalidURL
        case networkFailure(Error)
        case emptyResponse
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid feed URL."
            case .networkFailure(let error):
                return "Network error: \(error.localizedDescription)"
            case .emptyResponse:
                return "The news feed returned no data."
            case .parsingFailed:
                return "Failed to parse the news feed."
            }
        }
    }

    // MARK: - Fetch Articles (two-layer cache: disk → backend → direct RSS)

    /// Fetches articles for a category.
    /// Layer 1: FileManager disk cache (30-min TTL, works offline)
    /// Layer 2: Backend /api/articles (Firestore-cached, shared across users)
    /// Layer 3: Direct Aggie RSS fallback (original behaviour)
    func fetchArticles(category: NewsCategory = .all) async throws -> [NewsArticle] {
        let slug = category.rawValue.isEmpty ? "all" : category.rawValue

        // Layer 1 — disk cache
        if let cached = diskCache.loadArticleList(category: slug) {
            return cached
        }

        // Layer 2 — backend
        if var backendArticles = await fetchFromBackend(category: slug) {
            // Backend articles don't include images — scrape them client-side
            backendArticles = await fetchArticleImages(for: backendArticles)
            diskCache.saveArticleList(backendArticles, category: slug)
            return backendArticles
        }

        // Layer 3 — direct RSS fallback
        return try await fetchDirectFromRSS(category: category)
    }

    // MARK: - Backend Fetch

    private func fetchFromBackend(category: String) async -> [NewsArticle]? {
        guard let url = URL(string: APIConfig.articlesURL(category: category)) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }

            let decoded = try JSONDecoder().decode(BackendArticlesResponse.self, from: data)
            return decoded.success ? decoded.articles : nil
        } catch {
            #if DEBUG
            print("NewsService: backend fetch failed, falling back to RSS — \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Direct RSS Fallback (original behaviour)

    private func fetchDirectFromRSS(category: NewsCategory) async throws -> [NewsArticle] {
        let url = category.feedURL
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw ServiceError.networkFailure(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.networkFailure(
                NSError(domain: "HTTP", code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Server returned status \(httpResponse.statusCode)"])
            )
        }

        guard let xmlString = String(data: data, encoding: .utf8), !xmlString.isEmpty else {
            throw ServiceError.emptyResponse
        }

        let articles = RSSParser.parse(xmlString, defaultCategory: category.displayName)
        if articles.isEmpty { throw ServiceError.parsingFailed }

        var sorted = articles.sorted { $0.timestamp > $1.timestamp }
        sorted = await fetchArticleImages(for: sorted)
        return sorted
    }

    /// Fetches articles from all categories and combines them.
    func fetchAllArticles() async throws -> [NewsArticle] {
        return try await fetchArticles(category: .all)
    }

    // MARK: - Article Content Fetching (in-memory → disk → backend → scrape)

    /// Fetches the full article body for in-app reading.
    /// Layer 1: In-memory cache (session)
    /// Layer 2: FileManager disk cache (permanent, per device)
    /// Layer 3: Backend API (Firestore-cached, shared across users)
    /// Layer 4: Live HTML scrape via AggieArticleParser (fallback)
    func fetchArticleContent(for article: NewsArticle) async throws -> ArticleContent {
        let cacheKey = article.articleURL ?? article.id.uuidString

        // Layer 1 — in-memory
        if let cached = contentCache[cacheKey] {
            return cached
        }

        // Layer 2 — disk
        if let cached = diskCache.loadArticleContent(articleURL: cacheKey) {
            contentCache[cacheKey] = cached
            return cached
        }

        // Layer 3 — backend API
        if let urlString = article.articleURL,
           let backendContent = await fetchContentFromBackend(articleURL: urlString, fallback: article) {
            contentCache[cacheKey] = backendContent
            diskCache.saveArticleContent(backendContent, articleURL: cacheKey)
            return backendContent
        }

        // Layer 4 — live scrape (fallback)
        guard let urlString = article.articleURL, let url = URL(string: urlString) else {
            throw AggieParserError.invalidURL
        }
        let content = try await parser.fetchAndParse(articleURL: url, fallback: article)
        contentCache[cacheKey] = content
        diskCache.saveArticleContent(content, articleURL: cacheKey)
        return content
    }

    // MARK: - Backend Content Fetch

    /// Hits GET /api/articles/content?url=... and converts the response to ArticleContent.
    private func fetchContentFromBackend(articleURL: String, fallback: NewsArticle) async -> ArticleContent? {
        guard let url = URL(string: APIConfig.articleContentURL(articleURL: articleURL)) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }

            let decoded = try JSONDecoder().decode(BackendArticleContentResponse.self, from: data)
            guard decoded.success, let content = decoded.content else { return nil }
            return content.toArticleContent(fallbackDate: fallback.timestamp)
        } catch {
            #if DEBUG
            print("NewsService: backend content fetch failed — \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Background Prefetch

    /// Silently pre-fetches article content for all articles in the background.
    /// Populates both in-memory and disk caches so tapping an article is instant.
    func prefetchContent(for articles: [NewsArticle]) {
        for article in articles {
            let cacheKey = article.articleURL ?? article.id.uuidString
            // Skip if already cached in memory
            if contentCache[cacheKey] != nil { continue }
            // Skip if already cached on disk
            if diskCache.loadArticleContent(articleURL: cacheKey) != nil { continue }

            Task {
                _ = try? await fetchArticleContent(for: article)
            }
        }
    }

    // MARK: - Image Scraping

    /// Fetches each article's webpage and extracts the featured image (first img inside <article>).
    private func fetchArticleImages(for articles: [NewsArticle]) async -> [NewsArticle] {
        await withTaskGroup(of: (Int, String).self) { group in
            for (index, article) in articles.enumerated() {
                guard let urlString = article.articleURL,
                      let url = URL(string: urlString) else { continue }

                group.addTask {
                    let imageURL = await self.scrapeImageURL(from: url)
                    return (index, imageURL)
                }
            }

            var updated = articles
            for await (index, imageURL) in group {
                guard !imageURL.isEmpty else { continue }
                let old = updated[index]
                updated[index] = NewsArticle(
                    id: old.id,
                    title: old.title,
                    excerpt: old.excerpt,
                    imageURL: imageURL,
                    category: old.category,
                    timestamp: old.timestamp,
                    author: old.author,
                    readTime: old.readTime,
                    isFeatured: old.isFeatured,
                    articleURL: old.articleURL
                )
            }
            return updated
        }
    }

    /// Scrapes the first image URL from inside the &lt;article&gt; tag of a webpage.
    private func scrapeImageURL(from url: URL) async -> String {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return "" }

            // Find content inside <article...>...</article>
            guard let articlePattern = try? NSRegularExpression(pattern: "<article[^>]*>(.*?)</article>", options: .dotMatchesLineSeparators),
                  let articleMatch = articlePattern.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let articleRange = Range(articleMatch.range(at: 1), in: html) else {
                return ""
            }

            let articleHTML = String(html[articleRange])

            // Extract first img src from the article content
            guard let imgPattern = try? NSRegularExpression(pattern: "<img[^>]+src\\s*=\\s*[\"']([^\"']+)[\"']", options: .caseInsensitive),
                  let imgMatch = imgPattern.firstMatch(in: articleHTML, range: NSRange(articleHTML.startIndex..., in: articleHTML)),
                  let srcRange = Range(imgMatch.range(at: 1), in: articleHTML) else {
                return ""
            }

            return String(articleHTML[srcRange])
        } catch {
            return ""
        }
    }
}

// MARK: - Backend Response Models

private struct BackendArticlesResponse: Decodable {
    let success: Bool
    let articles: [NewsArticle]
}

private struct BackendArticleContentResponse: Decodable {
    let success: Bool
    let content: BackendArticleContent?
    let cached: Bool?
}

private struct BackendArticleContent: Decodable {
    let title: String?
    let author: String?
    let authorEmail: String?
    let publishDate: String?
    let category: String?
    let thumbnailURL: String?
    let bodyParagraphs: [String]?
    let articleURL: String?

    func toArticleContent(fallbackDate: Date) -> ArticleContent? {
        guard let paragraphs = bodyParagraphs, !paragraphs.isEmpty,
              let urlString = articleURL, let url = URL(string: urlString) else {
            return nil
        }
        return ArticleContent(
            title: title ?? "",
            author: author ?? "The Aggie",
            authorEmail: authorEmail,
            publishDate: fallbackDate,
            category: category ?? "",
            thumbnailURL: thumbnailURL.flatMap { URL(string: $0) },
            bodyParagraphs: paragraphs,
            articleURL: url
        )
    }
}
