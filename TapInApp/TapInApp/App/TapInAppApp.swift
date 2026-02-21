//
//  TapInAppApp.swift
//  TapInApp
//
//  Main entry point for the TapIn UC Davis News App
//  MVVM Architecture with SwiftUI
//

import SwiftUI
import GoogleSignIn

@main
struct TapInAppApp: App {
    // Use AppState.shared so the onboarding ViewModel and the
    // app gate both observe the exact same instance.
    @StateObject private var appState = AppState.shared
    @State private var isCheckingSession = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingSession {
                    // Brief splash while validating session
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        ProgressView()
                    }
                } else if appState.isAuthenticated {
                    ContentView()
                        .environmentObject(appState)
                } else {
                    OnboardingView()
                        .environmentObject(appState)
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .task {
                await appState.restoreSession()
                isCheckingSession = false
            }
            .alert(
                appState.globalError?.title ?? "Error",
                isPresented: $appState.showErrorAlert,
                presenting: appState.globalError
            ) { _ in
                Button("OK") { appState.clearError() }
            } message: { error in
                Text(error.errorDescription ?? "An unknown error occurred.")
            }
        }
    }
}
