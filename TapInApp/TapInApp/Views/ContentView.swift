//
//  ContentView.swift
//  TapInApp
//
//  MARK: - Main Content View
//  Primary container for the app - MVVM Architecture
//  Views: Multiple view screens (NewsView, CampusView, etc.)
//  ViewModels: Each view has its own ViewModel for state/logic
//  ARCHITECTURE: Uses custom tab bar for navigation between main sections
//

import SwiftUI

struct ContentView: View {
    // MARK: - State Properties
    @State private var selectedTab: TabItem = .news

    // MARK: - ViewModels (MVVM - create once and pass to views)
    // These ViewModels are where ALL your data logic lives
    @StateObject private var newsViewModel = NewsViewModel()
    @StateObject private var campusViewModel = CampusViewModel()
    @StateObject private var gamesViewModel = GamesViewModel()
    @StateObject private var savedViewModel = SavedViewModel()
    @StateObject private var profileViewModel = ProfileViewModel()

    @Environment(\.colorScheme) var colorScheme

    // MARK: - Body
    var body: some View {
        Group {
            switch selectedTab {
            case .news:
                NewsView(
                    viewModel: newsViewModel,
                    gamesViewModel: gamesViewModel,
                    selectedTab: $selectedTab
                )

            case .campus:
                CampusView(viewModel: campusViewModel, savedViewModel: savedViewModel)

            case .games:
                GamesView(viewModel: gamesViewModel)

            case .saved:
                SavedView(viewModel: savedViewModel)

            case .profile:
                ProfileView(viewModel: profileViewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            // MARK: - Custom Tab Bar (inserted within the safe area)
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
