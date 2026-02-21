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
import GoogleSignIn

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
    @Published var authToken: String?      // SMS auth service token
    @Published var smsUserId: String?
    @Published var backendToken: String?   // TapIn backend JWT

    // MARK: - App Settings
    @Published var notificationsEnabled: Bool = true
    @Published var darkModeEnabled: Bool = false

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
        authToken = nil
        smsUserId = nil
        backendToken = nil
        GIDSignIn.sharedInstance.signOut()
        UserDefaults.standard.removeObject(forKey: "profileImageData")
        UserDefaults.standard.removeObject(forKey: "appleUserId")
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
        UserDefaults.standard.set(darkModeEnabled, forKey: "darkModeEnabled")

        // Save auth token
        if let token = authToken {
            UserDefaults.standard.set(token, forKey: "authToken")
        } else {
            UserDefaults.standard.removeObject(forKey: "authToken")
        }
        if let uid = smsUserId {
            UserDefaults.standard.set(uid, forKey: "smsUserId")
        } else {
            UserDefaults.standard.removeObject(forKey: "smsUserId")
        }
        if let bToken = backendToken {
            UserDefaults.standard.set(bToken, forKey: "backendToken")
        } else {
            UserDefaults.standard.removeObject(forKey: "backendToken")
        }

        // Save user data if authenticated
        if let user = currentUser, let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentUser")
        }

        // Force immediate write to disk (prevents data loss on force-quit)
        UserDefaults.standard.synchronize()
    }

    private func loadPersistedState() {
        isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        darkModeEnabled = UserDefaults.standard.bool(forKey: "darkModeEnabled")
        authToken = UserDefaults.standard.string(forKey: "authToken")
        smsUserId = UserDefaults.standard.string(forKey: "smsUserId")
        backendToken = UserDefaults.standard.string(forKey: "backendToken")

        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
        }
    }

    // MARK: - Public Persistence (called from onboarding)
    func persistStatePublic() {
        persistState()
    }

    // MARK: - Session Restoration

    /// Validates the saved backend token on app launch and restores the session.
    /// Called from TapInAppApp on startup — if UserDefaults was wiped (e.g. Xcode
    /// rebuild) but the backend still has the account, this restores access.
    func restoreSession() async {
        // Already authenticated from UserDefaults — nothing to do
        if isAuthenticated && currentUser != nil { return }

        // Have a backend token but lost isAuthenticated — validate and restore
        if let token = backendToken {
            if let user = try? await UserAPIService.shared.fetchProfile(token: token) {
                currentUser = User(name: user.username, email: user.email, year: nil)
                isAuthenticated = true
                persistState()
            }
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
