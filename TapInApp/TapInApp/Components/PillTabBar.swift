//
//  PillTabBar.swift
//  TapInApp
//
//  Custom floating pill tab bar for legacy iOS (17–25).
//  Visually mirrors the iOS 26+ Liquid Glass tab bar using .ultraThinMaterial.
//  Search button expands into an inline search field; tabs collapse to a single circle.
//

import SwiftUI

struct PillTabBar: View {
    @Binding var selectedTab: TabItem
    @Binding var searchText: String

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var tabBarNamespace
    @FocusState private var isSearchFieldFocused: Bool

    @State private var isSearchExpanded = false
    @State private var previousTab: TabItem = .news

    /// The four main tabs shown inside the capsule pill.
    private static let pillTabs: [TabItem] = [.news, .campus, .games, .saved]

    private var accentColor: Color {
        colorScheme == .dark ? .accentOrange : .accentCoral
    }

    var body: some View {
        HStack(spacing: 12) {
            if !isSearchExpanded {
                // MARK: - Full Pill (4 tabs)
                fullPill
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.4, anchor: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.4, anchor: .trailing).combined(with: .opacity)
                    ))
            } else {
                // MARK: - Collapsed Circle (previous tab icon)
                collapsedCircle
                    .transition(.scale.combined(with: .opacity))
            }

            if !isSearchExpanded {
                // MARK: - Search Circle
                searchCircle
            } else {
                // MARK: - Expanded Search Field
                expandedSearchField
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
        .onChange(of: isSearchExpanded) { _, expanded in
            if expanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isSearchFieldFocused = true
                }
            } else {
                isSearchFieldFocused = false
            }
        }
    }

    // MARK: - Full Pill (4 tabs)

    private var fullPill: some View {
        HStack(spacing: 0) {
            ForEach(Self.pillTabs, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: selectedTab == tab ? tab.iconFilled : tab.icon)
                            .font(.system(size: 18))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(selectedTab == tab ? accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .matchedGeometryEffect(id: "pillShape", in: tabBarNamespace)
        )
    }

    // MARK: - Collapsed Circle (previous tab icon)

    private var collapsedCircle: some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                isSearchExpanded = false
                selectedTab = previousTab
                searchText = ""
            }
        } label: {
            Image(systemName: previousTab.iconFilled)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .background(
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .matchedGeometryEffect(id: "pillShape", in: tabBarNamespace)
        )
    }

    // MARK: - Search Circle (default state)

    private var searchCircle: some View {
        Button {
            previousTab = selectedTab
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                isSearchExpanded = true
                selectedTab = .search
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .matchedGeometryEffect(id: "searchShape", in: tabBarNamespace)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Search Field

    private var expandedSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            TextField("Search UC Davis News", text: $searchText)
                .font(.system(size: 17))
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .tint(accentColor)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .matchedGeometryEffect(id: "searchShape", in: tabBarNamespace)
        )
    }
}

#Preview {
    ZStack {
        Color.backgroundLight.ignoresSafeArea()
        VStack {
            Spacer()
            PillTabBar(selectedTab: .constant(.news), searchText: .constant(""))
        }
    }
}
