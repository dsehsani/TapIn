//
//  SMSAuthService.swift
//  TapInApp
//
//  Handles SMS authentication via the ECS191 SMS auth API.
//  Endpoints: send_sms_code, verify_code, user (token validation).
//

import Foundation

struct SMSAuthService {
    static let shared = SMSAuthService()

    private static let baseURL = "https://ecs191-sms-authentication.uc.r.appspot.com"
    private static let appID = "tapin_ios_app"

    // Ephemeral session on Simulator to avoid HTTP/3 (QUIC) issues with App Engine
    private static let urlSession: URLSession = {
        #if targetEnvironment(simulator)
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: config)
        #else
        return URLSession.shared
        #endif
    }()

    // MARK: - Send SMS Code

    func sendCode(phoneNumber: String) async throws {
        let url = URL(string: "\(Self.baseURL)/v1/send_sms_code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "phone_number": phoneNumber,
            "app_id": Self.appID
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await Self.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SMSAuthError.networkError
        }

        if http.statusCode != 200 {
            if let err = try? JSONDecoder().decode(SMSErrorResponse.self, from: data) {
                throw SMSAuthError.serverError(err.error)
            }
            throw SMSAuthError.serverError("Failed to send code (\(http.statusCode))")
        }
    }

    // MARK: - Verify Code

    func verifyCode(phoneNumber: String, code: String) async throws -> SMSVerifyResponse {
        let url = URL(string: "\(Self.baseURL)/v1/verify_code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "phone_number": phoneNumber,
            "app_id": Self.appID,
            "code": code
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await Self.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SMSAuthError.networkError
        }

        if http.statusCode == 401 {
            if let err = try? JSONDecoder().decode(SMSErrorResponse.self, from: data) {
                throw SMSAuthError.invalidCode(err.error)
            }
            throw SMSAuthError.invalidCode("Invalid or expired code")
        }

        if http.statusCode != 200 {
            if let err = try? JSONDecoder().decode(SMSErrorResponse.self, from: data) {
                throw SMSAuthError.serverError(err.error)
            }
            throw SMSAuthError.serverError("Verification failed (\(http.statusCode))")
        }

        return try JSONDecoder().decode(SMSVerifyResponse.self, from: data)
    }

    // MARK: - Validate Token

    func validateToken(_ token: String) async throws -> SMSUserResponse {
        let url = URL(string: "\(Self.baseURL)/v1/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await Self.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SMSAuthError.networkError
        }

        if http.statusCode != 200 {
            throw SMSAuthError.invalidToken
        }

        return try JSONDecoder().decode(SMSUserResponse.self, from: data)
    }
}

// MARK: - Response Types

struct SMSVerifyResponse: Decodable {
    let success: Bool
    let token: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case success, token
        case userId = "user_id"
    }
}

struct SMSUserResponse: Decodable {
    let userId: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

private struct SMSErrorResponse: Decodable {
    let error: String
}

// MARK: - Errors

enum SMSAuthError: LocalizedError {
    case networkError
    case serverError(String)
    case invalidCode(String)
    case invalidToken

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error. Check your connection and try again."
        case .serverError(let msg):
            return msg
        case .invalidCode(let msg):
            return msg
        case .invalidToken:
            return "Session expired. Please sign in again."
        }
    }
}
