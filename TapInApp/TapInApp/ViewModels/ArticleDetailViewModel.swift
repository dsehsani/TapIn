//
//  ArticleDetailViewModel.swift
//  TapInApp
//
//  Drives the article reading view. Loads full article body via NewsService
//  and exposes a clean state enum to the view.
//

import Foundation
import Combine

enum ArticleLoadState {
    case idle
    case loading
    case loaded(ArticleContent)
    case failed(String)
}

@MainActor
final class ArticleDetailViewModel: ObservableObject {
    @Published var loadState: ArticleLoadState = .idle

    private let newsService = NewsService()

    func load(article: NewsArticle) async {
        loadState = .loading
        do {
            let content = try await newsService.fetchArticleContent(for: article)
            loadState = .loaded(content)
            AnalyticsTracker.shared.track(.articleRead)
        } catch AggieParserError.contentNotFound {
            loadState = .failed("Article content could not be found.")
        } catch AggieParserError.invalidURL {
            loadState = .failed("This article has an invalid URL.")
        } catch {
            loadState = .failed("Failed to load article. Check your connection.")
        }
    }
}
