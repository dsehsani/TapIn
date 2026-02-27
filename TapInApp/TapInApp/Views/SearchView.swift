//
//  SearchView.swift
//  TapInApp
//
//  Search content with category grid for iOS 26+
//

import SwiftUI

@available(iOS 26, *)
struct SearchView: View {
    @Binding var selectedTab: TabItem
    @Binding var newsSearchText: String

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismissSearch) var dismissSearch

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Browse Topics")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.adaptiveText(colorScheme))

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(SearchCategory.allCategories) { category in
                        SearchCategoryCard(category: category, colorScheme: colorScheme) {
                            performSearch(category.name)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.adaptiveBackground(colorScheme))
    }

    // MARK: - Search Action

    private func performSearch(_ query: String) {
        newsSearchText = query
        selectedTab = .news
        dismissSearch()
    }
}

// MARK: - Search Category Model

struct SearchCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color

    static let allCategories: [SearchCategory] = [
        SearchCategory(name: "Sports", icon: "sportscourt.fill", color: Color(hex: "#E8485A")),
        SearchCategory(name: "Politics", icon: "building.columns.fill", color: Color(hex: "#6366F1")),
        SearchCategory(name: "Business", icon: "briefcase.fill", color: Color(hex: "#F59E0B")),
        SearchCategory(name: "Entertainment", icon: "film.fill", color: Color(hex: "#EC4899")),
        SearchCategory(name: "Science", icon: "atom", color: Color(hex: "#10B981")),
        SearchCategory(name: "Food & Dining", icon: "fork.knife", color: Color(hex: "#F97316")),
        SearchCategory(name: "Health", icon: "heart.fill", color: Color(hex: "#EF4444")),
        SearchCategory(name: "Arts", icon: "paintpalette.fill", color: Color(hex: "#8B5CF6")),
        SearchCategory(name: "Technology", icon: "desktopcomputer", color: Color(hex: "#3B82F6")),
        SearchCategory(name: "Campus Life", icon: "graduationcap.fill", color: Color(hex: "#14B8A6"))
    ]
}

// MARK: - Category Card

@available(iOS 26, *)
struct SearchCategoryCard: View {
    let category: SearchCategory
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(category.color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(category.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.adaptiveText(colorScheme))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
