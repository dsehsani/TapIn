//
//  NewsViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - News ViewModel
//  Handles all news-related business logic and state
//  Fetches articles from The Aggie RSS feeds
//

import Foundation
import SwiftUI
import Combine

@MainActor
class NewsViewModel: ObservableObject {
    @Published var articles: [NewsArticle] = []
    @Published var featuredArticle: NewsArticle?
    @Published var latestArticles: [NewsArticle] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedCategory: String = "All News"
    @Published var searchText: String = ""
    @Published var categories: [Category] = Category.allCategories

    // Daily AI Briefing
    @Published var dailyBriefing: DailyBriefing?
    @Published var isBriefingLoading: Bool = false
    @Published var briefingError: Bool = false

    /// True when the user has typed something in the search bar
    var isSearchActive: Bool { !searchText.isEmpty }

    private let newsService = NewsService()
    private let briefingService = DailyBriefingService.shared
    private var allFetchedArticles: [NewsArticle] = []

    /// In-memory cache of articles per category for instant tab switching
    private var categoryCache: [String: [NewsArticle]] = [:]

    init() {
        Task {
            await fetchArticles()
            await fetchDailyBriefing()
            // Prefetch all other categories in the background so filter switches are instant
            await prefetchAllCategories()
        }
    }

    // MARK: - Fetch Articles from RSS

    func fetchArticles() async {
        errorMessage = nil

        // Find the selected category
        let selectedCat = categories.first { $0.name == selectedCategory } ?? categories[0]
        let newsCategory = selectedCat.newsCategory
        let cacheKey = selectedCat.name

        // Only show full loading spinner when we have nothing to display
        let hasCachedData = categoryCache[cacheKey] != nil
        if !hasCachedData {
            isLoading = true
        }

        do {
            let fetched = try await newsService.fetchArticles(category: newsCategory)
            allFetchedArticles = fetched
            categoryCache[cacheKey] = fetched
            processArticles(fetched)
            isLoading = false

            // Pre-fetch article content in the background so tapping is instant
            newsService.prefetchContent(for: fetched)
        } catch {
            // Only fall back to sample data if we have nothing cached
            if !hasCachedData {
                errorMessage = error.localizedDescription
                loadSampleData()
            }
            isLoading = false
        }
    }

    func selectCategory(_ category: String) {
        // Exit search mode when switching categories
        clearSearch()

        selectedCategory = category
        categories = categories.map { cat in
            Category(id: cat.id, name: cat.name, icon: cat.icon, isSelected: cat.name == category)
        }

        // Show cached articles instantly if available
        if let cached = categoryCache[category] {
            allFetchedArticles = cached
            processArticles(cached)
        }

        // Refresh in the background (won't show loading spinner if cache hit)
        Task {
            await fetchArticles()
        }
    }

    func searchArticles(_ query: String) {
        if query.isEmpty {
            // Restore current category view
            processArticles(allFetchedArticles)
            return
        }

        // Gather articles from ALL cached categories
        var seen = Set<String>()
        var allArticles: [NewsArticle] = []
        for (_, cached) in categoryCache {
            for article in cached {
                let key = article.articleURL ?? article.title
                if !seen.contains(key) {
                    seen.insert(key)
                    allArticles.append(article)
                }
            }
        }

        let filtered = allArticles.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.excerpt.localizedCaseInsensitiveContains(query) ||
            ($0.author?.localizedCaseInsensitiveContains(query) ?? false) ||
            $0.category.localizedCaseInsensitiveContains(query)
        }
        processArticles(filtered)
    }

    func clearSearch() {
        searchText = ""
        processArticles(allFetchedArticles)
    }

    func refreshArticles() async {
        await fetchArticles()
        await fetchDailyBriefing()
    }

    // MARK: - Daily Briefing

    func fetchDailyBriefing() async {
        isBriefingLoading = true
        briefingError = false

        let result = await briefingService.fetchBriefing()
        dailyBriefing = result
        briefingError = (result == nil)
        isBriefingLoading = false
    }

    // MARK: - Background Prefetch

    /// Fetches all categories concurrently in the background so that
    /// tapping any filter for the first time shows articles instantly.
    private func prefetchAllCategories() async {
        await withTaskGroup(of: (String, [NewsArticle]?).self) { group in
            for cat in categories where cat.name != selectedCategory {
                let newsCategory = cat.newsCategory
                let name = cat.name
                // Skip categories we already have cached
                if categoryCache[name] != nil { continue }

                group.addTask { [newsService] in
                    let articles = try? await newsService.fetchArticles(category: newsCategory)
                    return (name, articles)
                }
            }

            for await (name, articles) in group {
                if let articles = articles {
                    categoryCache[name] = articles
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func processArticles(_ fetchedArticles: [NewsArticle]) {
        // Mark the first article as featured
        var processed = fetchedArticles
        if !processed.isEmpty {
            let first = processed[0]
            processed[0] = NewsArticle(
                id: first.id,
                title: first.title,
                excerpt: first.excerpt,
                imageURL: first.imageURL,
                category: first.category,
                timestamp: first.timestamp,
                author: first.author,
                readTime: first.readTime,
                isFeatured: true,
                articleURL: first.articleURL
            )
        }

        articles = processed
        featuredArticle = processed.first
        latestArticles = Array(processed.dropFirst())
    }

    private func loadSampleData() {
        allFetchedArticles = NewsArticle.sampleData
        articles = NewsArticle.sampleData
        featuredArticle = NewsArticle.featuredArticle
        latestArticles = NewsArticle.latestArticles
    }
}
