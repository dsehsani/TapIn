//
//  NewsViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - News ViewModel
//  Handles all news-related business logic and state
//  TODO: ADD YOUR WEB SCRAPING LOGIC HERE
//

import Foundation
import SwiftUI
import Combine

class NewsViewModel: ObservableObject {
    @Published var articles: [NewsArticle] = []
    @Published var featuredArticle: NewsArticle?
    @Published var latestArticles: [NewsArticle] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedCategory: String = "Top Stories"
    @Published var searchText: String = ""
    @Published var categories: [Category] = Category.allCategories

    init() {
        loadSampleData()
    }

    // TODO: REPLACE THIS WITH YOUR WEB SCRAPING IMPLEMENTATION
    func fetchArticles() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.loadSampleData()
            self.isLoading = false
        }
    }

    func fetchArticlesAsync() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        await MainActor.run {
            loadSampleData()
            isLoading = false
        }
    }

    func selectCategory(_ category: String) {
        selectedCategory = category
        categories = categories.map { cat in
            Category(id: cat.id, name: cat.name, icon: cat.icon, isSelected: cat.name == category)
        }

        if category == "Top Stories" {
            loadSampleData()
        } else {
            let filtered = NewsArticle.sampleData.filter { $0.category == category }
            articles = filtered
            featuredArticle = filtered.first { $0.isFeatured }
            latestArticles = filtered.filter { !$0.isFeatured }
        }
    }

    func searchArticles(_ query: String) {
        searchText = query
        if query.isEmpty {
            loadSampleData()
            return
        }
        let filtered = NewsArticle.sampleData.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.excerpt.localizedCaseInsensitiveContains(query)
        }
        articles = filtered
        featuredArticle = filtered.first { $0.isFeatured }
        latestArticles = filtered.filter { !$0.isFeatured }
    }

    func refreshArticles() async {
        await fetchArticlesAsync()
    }

    private func loadSampleData() {
        articles = NewsArticle.sampleData
        featuredArticle = NewsArticle.featuredArticle
        latestArticles = NewsArticle.latestArticles
    }
}
