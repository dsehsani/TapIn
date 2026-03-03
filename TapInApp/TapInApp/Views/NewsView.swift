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
    @ObservedObject var campusViewModel: CampusViewModel
    @ObservedObject var notificationsViewModel: NotificationsViewModel
    @Binding var selectedTab: TabItem

    @Environment(\.colorScheme) var colorScheme
    @State private var selectedArticle: NewsArticle? = nil
    @State private var selectedEvent: CampusEvent? = nil
    @State private var showBellSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            // Main Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    TopNavigationBar(
                        onSettingsTap: { selectedTab = .profile },
                        onBellTap: { showBellSheet = true },
                        hasUnseenNotifications: notificationsViewModel.hasUnseenNotifications
                    )
                    .padding(.bottom, 12)

                    // Category Pills
                    CategoryPillsView(
                        selectedCategory: $viewModel.selectedCategory,
                        categories: viewModel.categories,
                        onCategoryTap: { category in
                            viewModel.selectCategory(category)
                            if category == "For You" {
                                rebuildForYouFeed()
                            }
                        }
                    )
                    .pulsingHotspot(
                        tip: .categoryPills,
                        message: "Filter stories by what matters to you.",
                        arrowEdge: .top,
                        cornerRadius: 20
                    )
                    .padding(.bottom, 16)

                    if viewModel.isForYouSelected {
                        forYouFeedContent
                    } else {
                        standardFeedContent
                    }

                    Spacer(minLength: 0)
                        .frame(height: 8)
                }
            }
            .onAppear {
                rebuildForYouFeed()
            }
            .onChange(of: viewModel.articles.count) { _, _ in
                if viewModel.isForYouSelected {
                    rebuildForYouFeed()
                }
            }
            .onChange(of: campusViewModel.allEvents.count) { _, _ in
                if viewModel.isForYouSelected {
                    rebuildForYouFeed()
                }
            }
            .refreshable {
                await viewModel.refreshArticles()
                if viewModel.isForYouSelected {
                    rebuildForYouFeed()
                }
            }
            .sheet(item: $selectedArticle) { article in
                ArticleDetailView(article: article, savedViewModel: savedViewModel)
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event, savedViewModel: savedViewModel)
            }
            .sheet(isPresented: $showBellSheet) {
                NotificationBellSheet(
                    savedViewModel: savedViewModel,
                    notificationsViewModel: notificationsViewModel,
                    campusViewModel: campusViewModel
                )
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

    // MARK: - For You Feed

    @ViewBuilder
    private var forYouFeedContent: some View {
        let hasInterests = !(AppState.shared.currentUser?.interests ?? []).isEmpty
        let hasReadHistory = ArticleReadTracker.shared.hasHistory

        // Cold-start hint
        if !hasInterests && !hasReadHistory {
            coldStartHint
        }

        // Featured Article — first thing you see
        if let featured = viewModel.featuredArticle {
            FeaturedArticleCard(
                article: featured,
                onTap: {
                    ArticleReadTracker.shared.trackRead(article: featured)
                    selectedArticle = featured
                }
            )
            .padding(.bottom, 20)
        }

        // Events carousel — right below the featured article
        if !viewModel.forYouEvents.isEmpty {
            eventsCarousel
                .padding(.bottom, 24)
        }

        // "Picked For You" articles
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.ucdGold)
                Text("Picked For You")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            LazyVStack(spacing: 12) {
                ForEach(viewModel.forYouArticles) { article in
                    ArticleRowCard(
                        article: article,
                        colorScheme: colorScheme,
                        isSaved: savedViewModel.isArticleSaved(article),
                        onTap: {
                            ArticleReadTracker.shared.trackRead(article: article)
                            selectedArticle = article
                        },
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

    private var eventsCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.ucdGold)
                Text("Events For You")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.forYouEvents) { event in
                        ForYouEventCard(
                            event: event,
                            savedViewModel: savedViewModel,
                            onTap: { selectedEvent = event }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
        }
    }

    private var coldStartHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 20))
                .foregroundColor(Color.ucdGold)

            VStack(alignment: .leading, spacing: 2) {
                Text("Personalize your feed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                Text("Set your interests in Profile to get tailored stories and events.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f8fafc"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.ucdGold.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Standard Feed (non-For You categories)

    @ViewBuilder
    private var standardFeedContent: some View {
        // Featured Article
        if let featured = viewModel.featuredArticle {
            FeaturedArticleCard(
                article: featured,
                onTap: {
                    ArticleReadTracker.shared.trackRead(article: featured)
                    selectedArticle = featured
                }
            )
            .padding(.bottom, 24)
        }

        // Top Stories Section
        VStack(spacing: 0) {
            HStack {
                Text("Top Stories")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            LazyVStack(spacing: 12) {
                ForEach(viewModel.latestArticles) { article in
                    ArticleRowCard(
                        article: article,
                        colorScheme: colorScheme,
                        isSaved: savedViewModel.isArticleSaved(article),
                        onTap: {
                            ArticleReadTracker.shared.trackRead(article: article)
                            selectedArticle = article
                        },
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

    // MARK: - Helpers

    private func rebuildForYouFeed() {
        viewModel.buildForYouFeed(
            savedArticles: savedViewModel.savedArticles,
            savedEvents: savedViewModel.savedEvents,
            allEvents: campusViewModel.allEvents
        )
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
        campusViewModel: CampusViewModel(),
        notificationsViewModel: NotificationsViewModel(),
        selectedTab: .constant(.news)
    )
}

