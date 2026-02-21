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

    func updateProfile(name: String, email: String, year: String, imageData: Data?) async {
        guard var currentUser = AppState.shared.currentUser else { return }

        currentUser.name = name
        currentUser.email = email
        currentUser.year = year.isEmpty ? nil : year
        AppState.shared.currentUser = currentUser

        // Persist profile image
        if let imageData {
            UserDefaults.standard.set(imageData, forKey: "profileImageData")
        }

        // Update local profile cache (survives sign-out)
        updateLocalProfileCache(name: name, email: email, year: year)

        // Persist AppState to UserDefaults
        AppState.shared.persistStatePublic()

        // Sync name/email to backend (best-effort)
        if let token = AppState.shared.backendToken {
            try? await UserAPIService.shared.updateProfile(
                token: token,
                email: email.isEmpty ? nil : email,
                username: name.isEmpty ? nil : name
            )
        }
    }

    /// Updates the localProfiles cache so edits survive sign-out/re-sign-in.
    private func updateLocalProfileCache(name: String, email: String, year: String) {
        let providerKey = UserDefaults.standard.string(forKey: "appleUserId")
            ?? AppState.shared.smsUserId
            ?? ""
        guard !providerKey.isEmpty else { return }

        var profiles = UserDefaults.standard.dictionary(forKey: "localProfiles") as? [String: [String: String]] ?? [:]
        profiles[providerKey] = [
            "name": name,
            "email": email,
            "year": year,
            "providerKey": providerKey
        ]
        UserDefaults.standard.set(profiles, forKey: "localProfiles")
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
