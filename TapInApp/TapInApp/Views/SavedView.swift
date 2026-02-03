//
//  SavedView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct SavedView: View {
    @ObservedObject var viewModel: SavedViewModel

    @State private var selectedSegment = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Saved")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)

                // Segment Control
                Picker("", selection: $selectedSegment) {
                    Text("Articles").tag(0)
                    Text("Events").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // Content
                if selectedSegment == 0 {
                    if viewModel.savedArticles.isEmpty {
                        EmptyStateView(
                            icon: "bookmark",
                            title: "No saved articles",
                            message: "Articles you bookmark will appear here"
                        )
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.savedArticles) { article in
                                    SavedArticleCard(
                                        article: article,
                                        colorScheme: colorScheme,
                                        onRemove: { viewModel.removeArticle(article) }
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                } else {
                    if viewModel.savedEvents.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.clock",
                            title: "No saved events",
                            message: "Events you save will appear here"
                        )
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.savedEvents) { event in
                                    SavedEventCard(
                                        event: event,
                                        colorScheme: colorScheme,
                                        onRemove: { viewModel.removeEvent(event) }
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.textSecondary)
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.textSecondary)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

struct SavedArticleCard: View {
    let article: NewsArticle
    let colorScheme: ColorScheme
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(article.category.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                Text(article.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                    .lineLimit(2)
                Text(article.timestamp.timeAgoDisplay())
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.ucdGold)
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"), lineWidth: 1)
        )
    }
}

struct SavedEventCard: View {
    let event: CampusEvent
    let colorScheme: ColorScheme
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.isOfficial ? "OFFICIAL" : "STUDENT EVENT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(event.isOfficial ? Color.ucdBlue : Color.ucdGold)
                Text(event.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(event.date, style: .date)
                        .font(.system(size: 10))
                }
                .foregroundColor(.textSecondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.ucdGold)
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"), lineWidth: 1)
        )
    }
}

#Preview {
    SavedView(viewModel: SavedViewModel())
}
