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
        return articles.sorted { $0.timestamp > $1.timestamp }
    }

    /// Fetches articles from all categories and combines them.
    func fetchAllArticles() async throws -> [NewsArticle] {
        return try await fetchArticles(category: .all)
    }
}
