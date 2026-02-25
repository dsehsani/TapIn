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
                    savedViewModel: savedViewModel,
                    selectedTab: $selectedTab
                )

            case .campus:
                CampusView(viewModel: campusViewModel, savedViewModel: savedViewModel)

            case .games:
                GamesView(viewModel: gamesViewModel, selectedTab: $selectedTab)

            case .saved:
                SavedView(viewModel: savedViewModel, selectedTab: $selectedTab)

            case .profile:
                ProfileView(viewModel: profileViewModel, savedViewModel: savedViewModel, gamesViewModel: gamesViewModel, selectedTab: $selectedTab)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .safeAreaInset(edge: .bottom) {
            // MARK: - Custom Tab Bar (inserted within the safe area)
            CustomTabBar(selectedTab: $selectedTab)
                .pulsingHotspot(
                    tip: .navigationBar,
                    message: "Jump between News, Campus, Games & more.",
                    arrowEdge: .bottom,
                    highlightStyle: .topGlow
                )
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
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
