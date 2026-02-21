//
//  NewsView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct NewsView: View {
    @ObservedObject var viewModel: NewsViewModel
    @ObservedObject var savedViewModel: SavedViewModel
    @Binding var selectedTab: TabItem

    @Environment(\.colorScheme) var colorScheme
    @State private var selectedArticle: NewsArticle? = nil

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            // Main Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Spacer for header
                    Color.clear.frame(height: 64)

                    // Category Pills
                    CategoryPillsView(
                        selectedCategory: $viewModel.selectedCategory,
                        categories: viewModel.categories,
                        onCategoryTap: { category in
                            viewModel.selectCategory(category)
                        }
                    )
                    .padding(.vertical, 12)

                    if viewModel.isSearchActive {
                        // Search Results
                        if viewModel.articles.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Spacer().frame(height: 60)
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("No articles found for '\(viewModel.searchText)'")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 0) {
                                // Results header
                                HStack {
                                    Text("\(viewModel.articles.count) result\(viewModel.articles.count == 1 ? "" : "s") for '\(viewModel.searchText)'")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)

                                // Search result list (all articles, no featured split)
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.articles) { article in
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
                            }
                        }
                    } else {
                        // Normal view — AI Daily Briefing
                        DailyBriefingCard(
                            briefing: viewModel.dailyBriefing,
                            isLoading: viewModel.isBriefingLoading,
                            hasError: viewModel.briefingError
                        )
                        .padding(.bottom, 24)

                        // Featured Article
                        if let featured = viewModel.featuredArticle {
                            FeaturedArticleCard(
                                article: featured,
                                onTap: {
                                    selectedArticle = featured
                                }
                            )
                            .padding(.bottom, 24)
                        }

                        // Top Stories Section
                        VStack(spacing: 0) {
                            // Section Header
                            HStack {
                                Text("Top Stories")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)

                            // Article List
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.latestArticles) { article in
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
                        }
                    }

                    Spacer(minLength: 0)
                        .frame(height: 8)
                }
            }
            .refreshable {
                await viewModel.refreshArticles()
            }
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.searchArticles(newValue)
            }
            .sheet(item: $selectedArticle) { article in
                ArticleDetailView(article: article, savedViewModel: savedViewModel)
            }

            // Sticky Header
            VStack(spacing: 0) {
                TopNavigationBar(
                    searchText: $viewModel.searchText,
                    onSettingsTap: { selectedTab = .profile }
                )

                Rectangle()
                    .fill(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#e2e8f0"))
                    .frame(height: 1)
            }

            // Loading Overlay — only shown on first load when there are no articles
            if viewModel.isLoading && viewModel.articles.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Loading articles...")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(hex: "#1e293b") : .white)
                                .shadow(radius: 8)
                        )
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Article Row Card (Apple News style)
struct ArticleRowCard: View {
    let article: NewsArticle
    let colorScheme: ColorScheme
    var isSaved: Bool = false
    var onTap: () -> Void
    var onSave: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                // Publisher row — top left, Apple News style
                HStack(spacing: 5) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                    Text("THE CALIFORNIA AGGIE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.4)
                        .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // Content row — title left, thumbnail right
                HStack(alignment: .top, spacing: 12) {
                    Text(article.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    thumbnailView
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 14)

                // Metadata row — category · time · read time + bookmark
                HStack(spacing: 4) {
                    Text(article.category)
                        .font(.system(size: 11, weight: .medium))
                    Text("·")
                    Text(article.timestamp.timeAgoDisplay())
                        .font(.system(size: 11))
                    if let readTime = article.readTime {
                        Text("·")
                        Text("\(readTime) min read")
                            .font(.system(size: 11))
                    }
                    Spacer()
                    Button(action: {
                        onSave()
                    }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isSaved ? (colorScheme == .dark ? Color.ucdGold : Color.ucdBlue) : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var thumbnailView: some View {
        Group {
            if let url = URL(string: article.imageURL), !article.imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.ucdBlue.opacity(0.25), Color.ucdBlue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: article.categoryIcon)
                .font(.system(size: 22))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

#Preview {
    NewsView(
        viewModel: NewsViewModel(),
        savedViewModel: SavedViewModel(),
        selectedTab: .constant(.news)
    )
}

