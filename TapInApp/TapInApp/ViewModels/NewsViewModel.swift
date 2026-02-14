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

    private let newsService = NewsService()
    private var allFetchedArticles: [NewsArticle] = []

    init() {
        Task {
            await fetchArticles()
        }
    }

    // MARK: - Fetch Articles from RSS

    func fetchArticles() async {
        isLoading = true
        errorMessage = nil

        // Find the selected category
        let selectedCat = categories.first { $0.name == selectedCategory } ?? categories[0]
        let newsCategory = selectedCat.newsCategory

        do {
            let fetched = try await newsService.fetchArticles(category: newsCategory)
            allFetchedArticles = fetched
            processArticles(fetched)
            isLoading = false
        } catch {
            // Fallback to sample data on error
            errorMessage = error.localizedDescription
            loadSampleData()
            isLoading = false
        }
    }

    func selectCategory(_ category: String) {
        selectedCategory = category
        categories = categories.map { cat in
            Category(id: cat.id, name: cat.name, icon: cat.icon, isSelected: cat.name == category)
        }

        // Fetch articles for the new category
        Task {
            await fetchArticles()
        }
    }

    func searchArticles(_ query: String) {
        searchText = query
        if query.isEmpty {
            processArticles(allFetchedArticles)
            return
        }

        let filtered = allFetchedArticles.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.excerpt.localizedCaseInsensitiveContains(query) ||
            ($0.author?.localizedCaseInsensitiveContains(query) ?? false)
        }
        processArticles(filtered)
    }

    func refreshArticles() async {
        await fetchArticles()
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
