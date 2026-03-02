//
//  ContentView.swift
//  TapInApp
//
//  MARK: - Main Content View
//  Primary container for the app - MVVM Architecture
//  Views: Multiple view screens (NewsView, CampusView, etc.)
//  ViewModels: Each view has its own ViewModel for state/logic
//  ARCHITECTURE: Uses native TabView for navigation between main sections
//

import SwiftUI

struct ContentView: View {
    // MARK: - State Properties
    @State private var selectedTab: TabItem = .news
    @State private var showProfile = false
    @State private var tabSearchText = ""

    // MARK: - ViewModels (MVVM - create once and pass to views)
    // These ViewModels are where ALL your data logic lives
    @StateObject private var newsViewModel = NewsViewModel()
    @StateObject private var campusViewModel = CampusViewModel()
    @StateObject private var gamesViewModel = GamesViewModel()
    @StateObject private var savedViewModel = SavedViewModel()
    @StateObject private var profileViewModel = ProfileViewModel()
    @StateObject private var notificationsViewModel = NotificationsViewModel()

    @Environment(\.colorScheme) var colorScheme

    // MARK: - Body
    var body: some View {
        Group {
            if #available(iOS 26, *) {
                ios26TabView
            } else {
                legacyTabView
            }
        }
        .ignoresSafeArea(.keyboard)
        .task {
            // Wire notification callbacks
            savedViewModel.onEventSaved = { [weak notificationsViewModel] event in
                notificationsViewModel?.markEventAsUnseen(event)
            }
            savedViewModel.onEventRemoved = { [weak notificationsViewModel] event in
                notificationsViewModel?.removeFromUnseen(event)
            }
            // Re-schedule notifications for all saved upcoming events on launch
            for event in savedViewModel.upcomingEvents {
                await NotificationService.shared.scheduleReminders(for: event)
            }
        }
    }

    // MARK: - iOS 26+ Native TabView (Liquid Glass)

    @available(iOS 26, *)
    private var ios26TabView: some View {
        TabView(selection: $selectedTab) {
            Tab("News", systemImage: "newspaper.fill", value: .news) {
                NewsView(
                    viewModel: newsViewModel,
                    savedViewModel: savedViewModel,
                    campusViewModel: campusViewModel,
                    notificationsViewModel: notificationsViewModel,
                    selectedTab: $selectedTab
                )
            }

            Tab("Events", systemImage: "building.2.fill", value: .campus) {
                CampusView(viewModel: campusViewModel, savedViewModel: savedViewModel)
            }

            Tab("Games", systemImage: "puzzlepiece.extension.fill", value: .games) {
                GamesView(viewModel: gamesViewModel, selectedTab: $selectedTab)
            }

            Tab("Saved", systemImage: "bookmark.fill", value: .saved) {
                SavedView(viewModel: savedViewModel, selectedTab: $selectedTab)
            }

            Tab(value: .search, role: .search) {
                NavigationStack {
                    SearchView(
                        searchText: $tabSearchText,
                        savedViewModel: savedViewModel
                    )
                    .navigationTitle("Search")
                }
                .searchable(text: $tabSearchText, prompt: "Search UC Davis News")
            }
        }
        .tint(colorScheme == .dark ? Color.accentOrange : Color.accentCoral)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .profile {
                selectedTab = .news
                showProfile = true
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(
                viewModel: profileViewModel,
                savedViewModel: savedViewModel,
                gamesViewModel: gamesViewModel,
                selectedTab: $selectedTab
            )
        }
    }

    // MARK: - Legacy Tab View (iOS 17–25) — matches iOS 26+ design

    private var legacyTabView: some View {
        ZStack {
            NewsView(
                viewModel: newsViewModel,
                savedViewModel: savedViewModel,
                campusViewModel: campusViewModel,
                notificationsViewModel: notificationsViewModel,
                selectedTab: $selectedTab
            )
            .opacity(selectedTab == .news ? 1 : 0)
            .allowsHitTesting(selectedTab == .news)

            CampusView(viewModel: campusViewModel, savedViewModel: savedViewModel)
                .opacity(selectedTab == .campus ? 1 : 0)
                .allowsHitTesting(selectedTab == .campus)

            GamesView(viewModel: gamesViewModel, selectedTab: $selectedTab)
                .opacity(selectedTab == .games ? 1 : 0)
                .allowsHitTesting(selectedTab == .games)

            SavedView(viewModel: savedViewModel, selectedTab: $selectedTab)
                .opacity(selectedTab == .saved ? 1 : 0)
                .allowsHitTesting(selectedTab == .saved)

            SearchView(searchText: $tabSearchText, savedViewModel: savedViewModel)
                .opacity(selectedTab == .search ? 1 : 0)
                .allowsHitTesting(selectedTab == .search)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            PillTabBar(selectedTab: $selectedTab, searchText: $tabSearchText)
        }
        .tint(colorScheme == .dark ? Color.accentOrange : Color.accentCoral)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .profile {
                selectedTab = .news
                showProfile = true
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(
                viewModel: profileViewModel,
                savedViewModel: savedViewModel,
                gamesViewModel: gamesViewModel,
                selectedTab: $selectedTab
            )
        }
        .overlay {
            // MARK: - Onboarding Dismiss Overlay
            if OnboardingManager.shared.activeTip != nil {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if let tip = OnboardingManager.shared.activeTip {
                            OnboardingManager.shared.dismissTip(tip)
                        }
                    }
            }
        }
        // MARK: - Onboarding Tooltip Overlay (floats above everything)
        .overlayPreferenceValue(OnboardingTipOverlayKey.self) { tipInfos in
            if let activeTip = OnboardingManager.shared.activeTip,
               let info = tipInfos[activeTip] {
                GeometryReader { proxy in
                    let rect = proxy[info.anchor]

                    OnboardingTipView(message: info.message, arrowEdge: info.arrowEdge)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 280)
                        .position(
                            x: proxy.size.width / 2,
                            y: info.arrowEdge == .top
                                ? rect.maxY + 44
                                : rect.minY - 44
                        )
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
