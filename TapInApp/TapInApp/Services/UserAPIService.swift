//
//  UserAPIService.swift
//  TapInApp
//
//  iOS client for the TapIn backend user authentication API.
//  Handles Apple Sign-In, Phone auth, and email/password flows,
//  returning a backend JWT for subsequent authenticated requests.
//

import Foundation

struct AuthResponse: Codable {
    let success: Bool
    let token: String?
    let user: BackendUser?
    let isNewUser: Bool?
    let error: String?
}

struct BackendUser: Codable {
    let id: String
    let username: String
    let email: String
    let authProvider: String
    let createdAt: String?
    let updatedAt: String?
}

enum UserAPIError: LocalizedError {
    case serverError(String)
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .serverError(let msg): return msg
        case .networkError(let err): return err.localizedDescription
        case .invalidResponse: return "Invalid server response"
        }
    }
}

class UserAPIService {
    static let shared = UserAPIService()
    private init() {}

    // MARK: - Apple Sign-In

    /// Sends the Apple identity token to the backend for verification.
    /// Returns the backend JWT and user profile.
    func authenticateWithApple(
        identityToken: String,
        appleUserId: String,
        displayName: String = "",
        email: String = ""
    ) async throws -> AuthResponse {
        let body: [String: Any] = [
            "identityToken": identityToken,
            "appleUserId": appleUserId,
            "displayName": displayName,
            "email": email
        ]
        return try await post(url: APIConfig.authAppleURL, body: body)
    }

    // MARK: - Google Sign-In

    /// Sends the Google ID token to the backend for verification.
    /// Returns the backend JWT and user profile.
    func authenticateWithGoogle(
        idToken: String,
        googleUserId: String,
        displayName: String = "",
        email: String = ""
    ) async throws -> AuthResponse {
        let body: [String: Any] = [
            "idToken": idToken,
            "googleUserId": googleUserId,
            "displayName": displayName,
            "email": email
        ]
        return try await post(url: APIConfig.authGoogleURL, body: body)
    }

    // MARK: - Phone Auth

    /// Sends the SMS auth token to the backend for verification.
    /// Returns the backend JWT and user profile.
    func authenticateWithPhone(
        phoneNumber: String,
        smsToken: String,
        displayName: String = ""
    ) async throws -> AuthResponse {
        let body: [String: Any] = [
            "phoneNumber": phoneNumber,
            "smsToken": smsToken,
            "displayName": displayName
        ]
        return try await post(url: APIConfig.authPhoneURL, body: body)
    }

    // MARK: - Email/Password

    func register(username: String, email: String, password: String) async throws -> AuthResponse {
        let body: [String: Any] = [
            "username": username,
            "email": email,
            "password": password
        ]
        return try await post(url: APIConfig.registerURL, body: body)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        return try await post(url: APIConfig.loginURL, body: body)
    }

    // MARK: - Profile

    /// Fetches the current user's profile using the backend JWT.
    func fetchProfile(token: String) async throws -> BackendUser {
        var request = URLRequest(url: URL(string: APIConfig.meURL)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw UserAPIError.invalidResponse
        }

        struct ProfileResponse: Codable {
            let success: Bool
            let user: BackendUser?
            let error: String?
        }

        let result = try JSONDecoder().decode(ProfileResponse.self, from: data)
        if http.statusCode == 200, let user = result.user {
            return user
        }
        throw UserAPIError.serverError(result.error ?? "Failed to fetch profile")
    }

    // MARK: - Update Profile

    /// Updates the current user's profile fields (email, username).
    /// Requires a valid backend JWT.
    func updateProfile(token: String, email: String? = nil, username: String? = nil) async throws {
        guard let requestURL = URL(string: APIConfig.meURL) else {
            throw UserAPIError.invalidResponse
        }

        var body: [String: Any] = [:]
        if let email = email { body["email"] = email }
        if let username = username { body["username"] = username }

        guard !body.isEmpty else { return }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw UserAPIError.invalidResponse
        }

        struct UpdateResponse: Codable {
            let success: Bool
            let error: String?
        }

        let result = try JSONDecoder().decode(UpdateResponse.self, from: data)
        if !result.success {
            throw UserAPIError.serverError(result.error ?? "Failed to update profile (HTTP \(http.statusCode))")
        }
    }

    // MARK: - Private

    private func post(url: String, body: [String: Any]) async throws -> AuthResponse {
        guard let requestURL = URL(string: url) else {
            throw UserAPIError.invalidResponse
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw UserAPIError.invalidResponse
        }

        let result = try JSONDecoder().decode(AuthResponse.self, from: data)

        if result.success, result.token != nil {
            return result
        }

        throw UserAPIError.serverError(result.error ?? "Authentication failed (HTTP \(http.statusCode))")
    }
}
