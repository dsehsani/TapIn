//
//  SearchView.swift
//  TapInApp
//
//  Search content with category grid + inline results for iOS 26+
//

import SwiftUI

struct SearchView: View {
    @Binding var searchText: String
    @ObservedObject var savedViewModel: SavedViewModel

    @Environment(\.colorScheme) var colorScheme

    @State private var searchResults: [NewsArticle] = []
    @State private var isSearching = false
    @State private var selectedArticle: NewsArticle? = nil
    @State private var searchTask: Task<Void, Never>?
    @State private var debounceTask: Task<Void, Never>?

    private let newsService = NewsService()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var isActive: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if isActive {
                // MARK: - Search Results
                searchResultsView
            } else {
                // MARK: - Browse Topics
                topicsGridView
            }
        }
        .background(Color.adaptiveBackground(colorScheme))
        .onChange(of: searchText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                debounceTask?.cancel()
                searchTask?.cancel()
                searchResults = []
                isSearching = false
            } else {
                debouncedSearch(trimmed)
            }
        }
        .sheet(item: $selectedArticle) { article in
            ArticleDetailView(article: article, savedViewModel: savedViewModel)
        }
    }

    // MARK: - Topics Grid

    private var topicsGridView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Browse Topics")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.adaptiveText(colorScheme))
                .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(SearchCategory.allCategories) { category in
                    SearchCategoryCard(category: category, colorScheme: colorScheme) {
                        // Tap a card → search immediately (no debounce)
                        searchText = category.name
                        fireSearch(category.name)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 100)
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        VStack(spacing: 0) {
            if isSearching && searchResults.isEmpty {
                VStack(spacing: 16) {
                    Spacer().frame(height: 60)
                    ProgressView("Searching...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Spacer().frame(height: 60)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No articles found for '\(searchText)'")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            } else {
                HStack {
                    Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                LazyVStack(spacing: 12) {
                    ForEach(searchResults) { article in
                        ArticleRowCard(
                            article: article,
                            colorScheme: colorScheme,
                            isSaved: savedViewModel.isArticleSaved(article),
                            onTap: { selectedArticle = article },
                            onSave: { savedViewModel.toggleArticleSaved(article) }
                        )
                        .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Search Actions

    /// Debounces typed input — waits 0.3s after user stops typing before searching.
    private func debouncedSearch(_ query: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            fireSearch(query)
        }
    }

    /// Fires the backend search immediately. Cancels any in-flight request.
    private func fireSearch(_ query: String) {
        debounceTask?.cancel()
        searchTask?.cancel()
        isSearching = true
        searchTask = Task {
            let results = await newsService.searchArticles(query: query)
            guard !Task.isCancelled else { return }
            searchResults = results
            isSearching = false
        }
    }
}

// MARK: - Search Category Model

struct SearchCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let gradientStart: Color
    let gradientEnd: Color

    static let allCategories: [SearchCategory] = [
        SearchCategory(name: "Sports",        icon: "sportscourt.fill",      gradientStart: Color(hex: "#E8485A"), gradientEnd: Color(hex: "#F06B3F")),
        SearchCategory(name: "Politics",      icon: "building.columns.fill", gradientStart: Color(hex: "#6366F1"), gradientEnd: Color(hex: "#818CF8")),
        SearchCategory(name: "Business",      icon: "briefcase.fill",        gradientStart: Color(hex: "#F59E0B"), gradientEnd: Color(hex: "#FBBF24")),
        SearchCategory(name: "Entertainment", icon: "film.fill",             gradientStart: Color(hex: "#EC4899"), gradientEnd: Color(hex: "#F472B6")),
        SearchCategory(name: "Science",       icon: "atom",                  gradientStart: Color(hex: "#10B981"), gradientEnd: Color(hex: "#34D399")),
        SearchCategory(name: "Food & Dining", icon: "fork.knife",            gradientStart: Color(hex: "#F97316"), gradientEnd: Color(hex: "#FB923C")),
        SearchCategory(name: "Health",        icon: "heart.fill",            gradientStart: Color(hex: "#EF4444"), gradientEnd: Color(hex: "#F87171")),
        SearchCategory(name: "Arts",          icon: "paintpalette.fill",     gradientStart: Color(hex: "#8B5CF6"), gradientEnd: Color(hex: "#A78BFA")),
        SearchCategory(name: "Technology",    icon: "desktopcomputer",       gradientStart: Color(hex: "#3B82F6"), gradientEnd: Color(hex: "#60A5FA")),
        SearchCategory(name: "Campus Life",   icon: "graduationcap.fill",    gradientStart: Color(hex: "#14B8A6"), gradientEnd: Color(hex: "#2DD4BF"))
    ]
}

// MARK: - Category Card

struct SearchCategoryCard: View {
    let category: SearchCategory
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Gradient background
                LinearGradient(
                    colors: [category.gradientStart, category.gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Large icon watermark
                Image(systemName: category.icon)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white.opacity(0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(12)

                // Label
                Text(category.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: category.gradientStart.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
