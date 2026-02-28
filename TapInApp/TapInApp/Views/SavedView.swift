//
//  SavedView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct SavedView: View {
    @ObservedObject var viewModel: SavedViewModel
    @Binding var selectedTab: TabItem

    @State private var selectedSegment = 0
    @State private var selectedEventSegment = 0
    @State private var selectedEvent: CampusEvent?
    @State private var selectedArticle: NewsArticle?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Saved")
                        .font(.system(size: 34, weight: .black))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Segment Picker
                HStack(spacing: 0) {
                    segmentButton(title: "Articles", index: 0)
                    segmentButton(title: "Events", index: 1)
                }
                .padding(3)
                .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if selectedSegment == 0 {
                    articlesContent
                } else {
                    eventsContent
                }
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event, savedViewModel: viewModel)
        }
        .sheet(item: $selectedArticle) { article in
            ArticleDetailView(article: article, savedViewModel: viewModel)
        }
    }

    // MARK: - Segment Button

    private func segmentButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedSegment = index }
        }) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selectedSegment == index
                    ? (colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                    : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedSegment == index
                    ? (colorScheme == .dark ? Color(hex: "#2a2a3e") : .white)
                    : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Articles Content

    private var articlesContent: some View {
        Group {
            if viewModel.savedArticles.isEmpty {
                ActionableEmptyStateView(
                    icon: "bookmark",
                    title: "Your bookmarks is looking dry.",
                    message: "Go find some headlines.",
                    buttonTitle: "Explore News",
                    action: { selectedTab = .news }
                )
            } else {
                List {
                    ForEach(viewModel.savedArticles) { article in
                        SavedArticleRow(article: article, colorScheme: colorScheme)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .onTapGesture { selectedArticle = article }
                    }
                    .onDelete { offsets in
                        let articles = offsets.map { viewModel.savedArticles[$0] }
                        articles.forEach { viewModel.removeArticle($0) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Events Content

    private var eventsContent: some View {
        VStack(spacing: 0) {
            // Sub-tabs: Attending / Attended
            if #available(iOS 26, *) {
                Picker("", selection: $selectedEventSegment) {
                    Text("Attending").tag(0)
                    Text("Attended").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            } else {
                HStack(spacing: 0) {
                    eventSubTab(title: "Attending", index: 0)
                    eventSubTab(title: "Attended", index: 1)
                }
                .padding(3)
                .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"))
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            if selectedEventSegment == 0 {
                eventsList(
                    events: viewModel.upcomingEvents,
                    emptyIcon: "calendar.badge.clock",
                    emptyTitle: "No plans this weekend?",
                    emptyMessage: "Let's fix that.",
                    actionTitle: "Find Events",
                    action: { selectedTab = .campus }
                )
            } else {
                eventsList(
                    events: viewModel.attendedEvents,
                    emptyIcon: "clock.arrow.circlepath",
                    emptyTitle: "No attended events",
                    emptyMessage: "Past events you attended will appear here automatically"
                )
            }
        }
    }

    private func eventSubTab(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedEventSegment = index }
        }) {
            Text(title)
                .font(.system(size: 14, weight: selectedEventSegment == index ? .semibold : .medium))
                .foregroundColor(selectedEventSegment == index ? .white : (colorScheme == .dark ? .white : Color(hex: "#334155")))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedEventSegment == index ? Color.adaptiveAccent(colorScheme) : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func eventsList(events: [CampusEvent], emptyIcon: String, emptyTitle: String, emptyMessage: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        Group {
            if events.isEmpty {
                if let actionTitle = actionTitle, let action = action {
                    ActionableEmptyStateView(icon: emptyIcon, title: emptyTitle, message: emptyMessage, buttonTitle: actionTitle, action: action)
                } else {
                    EmptyStateView(icon: emptyIcon, title: emptyTitle, message: emptyMessage)
                }
            } else {
                List {
                    ForEach(events) { event in
                        SavedEventRow(event: event, colorScheme: colorScheme)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .onTapGesture { selectedEvent = event }
                    }
                    .onDelete { offsets in
                        let toRemove = offsets.map { events[$0] }
                        toRemove.forEach { viewModel.removeEvent($0) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

// MARK: - Saved Article Row (thumbnail card)

struct SavedArticleRow: View {
    let article: NewsArticle
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
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
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Text content
            VStack(alignment: .leading, spacing: 5) {
                Text(article.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                    .lineLimit(2)

                Text(article.category)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)

                Text(article.timestamp.timeAgoDisplay())
                    .font(.system(size: 11))
                    .foregroundColor(.textMuted)
            }

            Spacer(minLength: 0)

            // Bookmark indicator
            Image(systemName: "bookmark.fill")
                .font(.system(size: 16))
                .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
        }
        .padding(12)
        .background(colorScheme == .dark ? Color(hex: "#1a2033") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            Color(hex: colorScheme == .dark ? "#1e293b" : "#f1f5f9")
            Image(systemName: "newspaper.fill")
                .font(.system(size: 20))
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Saved Event Row (matches EventCard style from Campus tab)

struct SavedEventRow: View {
    let event: CampusEvent
    let colorScheme: ColorScheme

    private var isPast: Bool {
        event.date < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: organizer / type + date
            HStack {
                if let organizer = event.organizerName {
                    Text(organizer.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Color.ucdGold)
                        .lineLimit(1)
                } else {
                    Text(event.isOfficial ? "OFFICIAL" : "CLUB EVENT")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(event.isOfficial ? Color.ucdBlue : Color.ucdGold)
                }
                Spacer()
                if event.dateUrgency != .later {
                    Text(event.friendlyDateLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(event.dateUrgency.badgeColor, in: Capsule())
                } else {
                    Text(event.friendlyDateLabel)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }

            // Title
            Text(event.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                .lineLimit(2)

            // Description
            if !event.description.isEmpty {
                Text(event.description)
                    .font(.system(size: 14))
                    .foregroundColor(.textMuted)
                    .lineLimit(2)
            }

            // Bottom row: time + location + status badge
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.ucdBlue)
                    Text(event.date, style: .time)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }

                if !event.location.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.ucdBlue)
                        Text(event.location)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isPast {
                    Text("Attended")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#10b981"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#10b981").opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "#10b981"))
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Empty State

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

// MARK: - Actionable Empty State

struct ActionableEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

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

            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                    )
            }
            .padding(.top, 4)

            Spacer()
        }
    }
}

#Preview {
    SavedView(viewModel: SavedViewModel(), selectedTab: .constant(.saved))
}
