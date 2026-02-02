//
//  NewsView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct NewsView: View {
    @ObservedObject var viewModel: NewsViewModel
    @ObservedObject var gamesViewModel: GamesViewModel
    @Binding var selectedTab: TabItem

    @Environment(\.colorScheme) var colorScheme

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

                    // Games Banner
                    GamesBannerView(onPlayTap: {
                        selectedTab = .games
                    })
                    .padding(.bottom, 24)

                    // Featured Article
                    if let featured = viewModel.featuredArticle {
                        FeaturedArticleCard(
                            article: featured,
                            onTap: {
                                // TODO: Navigate to article detail
                            }
                        )
                        .padding(.bottom, 24)
                    }

                    // Latest Updates Section
                    VStack(spacing: 16) {
                        // Section Header
                        HStack {
                            Text("Latest Updates")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

                            Spacer()

                            Button(action: {}) {
                                Text("See all")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Article List
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.latestArticles) { article in
                                ArticleRowCard(
                                    article: article,
                                    colorScheme: colorScheme,
                                    onTap: {
                                        // TODO: Navigate to article detail
                                    }
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                        .frame(height: 8)
                }
            }
            .refreshable {
                await viewModel.refreshArticles()
            }

            // Sticky Header
            VStack(spacing: 0) {
                TopNavigationBar(
                    searchText: $viewModel.searchText,
                    onSettingsTap: {}
                )

                Rectangle()
                    .fill(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#e2e8f0"))
                    .frame(height: 1)
            }

            // Loading Overlay
            if viewModel.isLoading {
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

// MARK: - Article Row Card (inline for simplicity)
struct ArticleRowCard: View {
    let article: NewsArticle
    let colorScheme: ColorScheme
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.category.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)

                    Text(article.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(article.timestamp.timeAgoDisplay())
                        if let readTime = article.readTime {
                            Text("•")
                            Text("\(readTime) min read")
                        }
                    }
                    .font(.system(size: 10))
                    .italic()
                    .foregroundColor(.textSecondary)
                    .padding(.top, 4)
                }

                Spacer()

                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.ucdBlue.opacity(0.2), Color.ucdBlue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
            .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NewsView(
        viewModel: NewsViewModel(),
        gamesViewModel: GamesViewModel(),
        selectedTab: .constant(.news)
    )
}

