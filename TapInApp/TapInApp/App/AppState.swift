//
//  AppState.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/31/26.
//
//  MARK: - App State (Environment Object)
//  Centralized app-wide state management using @EnvironmentObject.
//  This is injected at the app level and accessible throughout the view hierarchy.
//
//  Usage in views:
//  @EnvironmentObject var appState: AppState
//

import Foundation
import SwiftUI
import Combine

// MARK: - App State
/// Centralized state management for app-wide data.
/// Injected as an EnvironmentObject at the app root.
@MainActor
class AppState: ObservableObject {

    // MARK: - Singleton (for non-SwiftUI access)
    static let shared = AppState()

    // MARK: - Authentication State
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var authError: AppError?

    // MARK: - App Settings
    @Published var notificationsEnabled: Bool = true

    // MARK: - Loading States
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String?

    // MARK: - Global Error State
    @Published var globalError: AppError?
    @Published var showErrorAlert: Bool = false

    // MARK: - Network State
    @Published var isOnline: Bool = true

    // MARK: - Computed Properties

    var userName: String {
        currentUser?.name ?? "Guest"
    }

    var userEmail: String {
        currentUser?.email ?? ""
    }

    var isGuest: Bool {
        currentUser == nil || !isAuthenticated
    }

    // MARK: - Initialization

    init() {
        loadPersistedState()
    }

    // MARK: - Authentication Methods

    /// Signs in a user (placeholder for actual implementation)
    func signIn(email: String, password: String) async throws {
        isLoading = true
        loadingMessage = "Signing in..."
        authError = nil

        defer {
            isLoading = false
            loadingMessage = nil
        }

        // TODO: Replace with actual authentication
        try await Task.sleep(nanoseconds: 500_000_000)

        // Simulate successful login
        currentUser = User(name: "Aggie Student", email: email)
        isAuthenticated = true
        persistState()
    }

    /// Signs out the current user
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        authError = nil
        persistState()
    }

    /// Registers a new user (placeholder for actual implementation)
    func register(name: String, email: String, password: String) async throws {
        isLoading = true
        loadingMessage = "Creating account..."
        authError = nil

        defer {
            isLoading = false
            loadingMessage = nil
        }

        // TODO: Replace with actual registration
        try await Task.sleep(nanoseconds: 500_000_000)

        currentUser = User(name: name, email: email)
        isAuthenticated = true
        persistState()
    }

    // MARK: - Error Handling

    /// Displays a global error alert
    func showError(_ error: AppError) {
        globalError = error
        showErrorAlert = true
    }

    /// Clears the current error
    func clearError() {
        globalError = nil
        showErrorAlert = false
    }

    // MARK: - Persistence

    private func persistState() {
        // Save authentication state
        UserDefaults.standard.set(isAuthenticated, forKey: "isAuthenticated")
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")

        // Save user data if authenticated
        if let user = currentUser, let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentUser")
        }
    }

    private func loadPersistedState() {
        isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")

        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
        }
    }

    // MARK: - Settings

    func toggleNotifications() {
        notificationsEnabled.toggle()
        persistState()
    }
}

// MARK: - Environment Key
/// Custom environment key for AppState
struct AppStateKey: EnvironmentKey {
    static let defaultValue: AppState = AppState.shared
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
