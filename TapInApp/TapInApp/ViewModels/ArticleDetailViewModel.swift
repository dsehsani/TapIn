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

    // Minimum seconds a user must spend reading before counting as a DAU event
    private static let minReadSeconds: UInt64 = 30
    private var readTask: Task<Void, Never>?

    func load(article: NewsArticle) async {
        loadState = .loading
        do {
            let content = try await newsService.fetchArticleContent(for: article)
            loadState = .loaded(content)
            startReadTimer()
        } catch AggieParserError.contentNotFound {
            loadState = .failed("Article content could not be found.")
        } catch AggieParserError.invalidURL {
            loadState = .failed("This article has an invalid URL.")
        } catch {
            loadState = .failed("Failed to load article. Check your connection.")
        }
    }

    /// Call when the article view disappears so we don't count a quick glance.
    func cancelReadTracking() {
        readTask?.cancel()
        readTask = nil
    }

    // MARK: - Private

    private func startReadTimer() {
        readTask?.cancel()
        readTask = Task {
            try? await Task.sleep(nanoseconds: Self.minReadSeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            AnalyticsTracker.shared.track(.articleRead)
        }
    }
}
