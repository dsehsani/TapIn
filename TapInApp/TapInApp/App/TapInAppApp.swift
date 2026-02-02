//
//  TapInAppApp.swift
//  TapInApp
//
//  Main entry point for the TapIn UC Davis News App
//  MVVM Architecture with SwiftUI
//

import SwiftUI

@main
struct TapInAppApp: App {
    // MARK: - App State (Environment Object)
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .alert(
                    appState.globalError?.title ?? "Error",
                    isPresented: $appState.showErrorAlert,
                    presenting: appState.globalError
                ) { _ in
                    Button("OK") {
                        appState.clearError()
                    }
                } message: { error in
                    Text(error.errorDescription ?? "An unknown error occurred.")
                }
        }
    }
}
