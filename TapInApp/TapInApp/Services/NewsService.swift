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

    // MARK: - Article Content Cache
    private let parser = AggieArticleParser()
    private var contentCache: [String: ArticleContent] = [:]

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

    // MARK: - Fetch Articles

    /// Fetches and parses articles from The Aggie RSS feed for a specific category.
    func fetchArticles(category: NewsCategory = .all) async throws -> [NewsArticle] {
        let url = category.feedURL

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw ServiceError.networkFailure(error)
        }

        // Verify we got a valid HTTP response
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

        if articles.isEmpty {
            throw ServiceError.parsingFailed
        }

        // Sort by date, newest first
        var sorted = articles.sorted { $0.timestamp > $1.timestamp }

        // Fetch featured images from article pages in parallel
        sorted = await fetchArticleImages(for: sorted)

        return sorted
    }

    /// Fetches articles from all categories and combines them.
    func fetchAllArticles() async throws -> [NewsArticle] {
        return try await fetchArticles(category: .all)
    }

    // MARK: - Article Content Fetching

    /// Fetches and parses the full article body for in-app reading.
    /// Results are cached in memory to avoid re-fetching opened articles.
    func fetchArticleContent(for article: NewsArticle) async throws -> ArticleContent {
        let cacheKey = article.articleURL ?? article.id.uuidString
        if let cached = contentCache[cacheKey] {
            return cached
        }
        guard let urlString = article.articleURL, let url = URL(string: urlString) else {
            throw AggieParserError.invalidURL
        }
        let content = try await parser.fetchAndParse(articleURL: url, fallback: article)
        contentCache[cacheKey] = content
        return content
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

    /// Scrapes the first image URL from inside the <article> tag of a webpage.
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
