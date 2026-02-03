//
//  ProfileViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - Profile ViewModel
//  Manages user profile UI state and coordinates with AppState for auth.
//  Uses AppState (EnvironmentObject) for shared authentication state.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Local UI State
    @Published var darkModeEnabled: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: AppError?
    @Published var showError: Bool = false

    // MARK: - Computed Properties (from AppState)
    /// Access shared app state for user data
    /// Note: In views, prefer accessing AppState directly via @EnvironmentObject

    var userName: String {
        AppState.shared.userName
    }

    var userEmail: String {
        AppState.shared.userEmail
    }

    var isLoggedIn: Bool {
        AppState.shared.isAuthenticated
    }

    var user: User? {
        AppState.shared.currentUser
    }

    var notificationsEnabled: Bool {
        get { AppState.shared.notificationsEnabled }
        set { AppState.shared.notificationsEnabled = newValue }
    }

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    // MARK: - Authentication (delegates to AppState)

    func login(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            try await AppState.shared.signIn(email: email, password: password)
        } catch let appError as AppError {
            error = appError
            showError = true
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            showError = true
        }

        isLoading = false
    }

    func logout() {
        AppState.shared.signOut()
    }

    func signUp(name: String, email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            try await AppState.shared.register(name: name, email: email, password: password)
        } catch let appError as AppError {
            error = appError
            showError = true
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            showError = true
        }

        isLoading = false
    }

    // MARK: - Profile Updates

    func updateProfile(name: String, email: String) {
        guard var currentUser = AppState.shared.currentUser else { return }
        currentUser.name = name
        currentUser.email = email
        AppState.shared.currentUser = currentUser
    }

    // MARK: - Settings

    func toggleNotifications() {
        AppState.shared.toggleNotifications()
    }

    func toggleDarkMode() {
        darkModeEnabled.toggle()
        saveSettings()
    }

    // MARK: - Persistence

    private func loadSettings() {
        darkModeEnabled = UserDefaults.standard.bool(forKey: "darkModeEnabled")
    }

    private func saveSettings() {
        UserDefaults.standard.set(darkModeEnabled, forKey: "darkModeEnabled")
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
        showError = false
    }
}
