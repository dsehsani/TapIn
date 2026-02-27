//
//  LiquidGlassTabBar.swift
//  TapInApp
//
//  Floating liquid glass tab bar with matched geometry search morph for iOS 26+
//  Uses .glassEffect() for native liquid glass rendering identical to system tab bar.
//

import SwiftUI

@available(iOS 26, *)
struct LiquidGlassTabBar: View {
    @Binding var selectedTab: TabItem
    @Binding var isSearchActive: Bool
    @Binding var searchText: String
    var onSearchSubmit: () -> Void

    @Namespace private var namespace
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            if !isSearchActive {
                // ── STATE A: Navigation Pill + Search Circle ──
                navPill
                searchCircle
            } else {
                // ── STATE B: Condensed Circle + Expanded Search Bar ──
                condensedNavCircle
                expandedSearchBar
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isSearchActive)
    }

    // MARK: - State A: Navigation Pill

    private var navPill: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.pillTabs, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: selectedTab == tab ? tab.iconFilled : tab.icon)
                            .font(.system(size: 18))
                            .symbolEffect(.bounce, value: selectedTab == tab)
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(
                        selectedTab == tab
                            ? Color.adaptiveAccent(colorScheme)
                            : .secondary
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .matchedGeometryEffect(id: "navElement", in: namespace)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - State A: Search Circle

    private var searchCircle: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                isSearchActive = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isSearchFocused = true
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.adaptiveAccent(colorScheme))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .matchedGeometryEffect(id: "searchElement", in: namespace)
        .glassEffect(.regular, in: .circle)
    }

    // MARK: - State B: Condensed Nav Circle (shows previous tab icon)

    private var condensedNavCircle: some View {
        Button {
            isSearchFocused = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                isSearchActive = false
                searchText = ""
            }
        } label: {
            Image(systemName: selectedTab.iconFilled)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.adaptiveAccent(colorScheme))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .matchedGeometryEffect(id: "navElement", in: namespace)
        .glassEffect(.regular, in: .circle)
    }

    // MARK: - State B: Expanded Search Bar

    private var expandedSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search UC Davis News", text: $searchText)
                .font(.system(size: 16))
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit {
                    if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        onSearchSubmit()
                    }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .matchedGeometryEffect(id: "searchElement", in: namespace)
        .glassEffect(.regular, in: .capsule)
    }
}
