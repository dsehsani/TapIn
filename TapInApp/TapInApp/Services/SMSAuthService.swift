//
//  SMSAuthService.swift
//  TapInApp
//
//  Handles SMS authentication via Firebase Phone Auth.
//  Uses PhoneAuthProvider for OTP send and Firebase Auth for sign-in.
//

import Foundation
import FirebaseAuth

struct SMSAuthService {
    static let shared = SMSAuthService()

    // Stores the verification ID returned by Firebase after sending the OTP.
    // Needed to create the credential when the user enters the code.
    private static var storedVerificationID: String?

    // MARK: - Send SMS Code

    func sendCode(phoneNumber: String) async throws {
        do {
            let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(
                phoneNumber,
                uiDelegate: nil
            )
            Self.storedVerificationID = verificationID
        } catch {
            throw SMSAuthError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Verify Code & Sign In

    /// Verifies the OTP code, signs in with Firebase, and returns the Firebase ID token.
    func verifyCode(phoneNumber: String, code: String) async throws -> SMSVerifyResponse {
        guard let verificationID = Self.storedVerificationID else {
            throw SMSAuthError.serverError("No verification ID found. Please request a new code.")
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )

        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            let user = authResult.user

            // Get the Firebase ID token to send to our backend
            let idToken = try await user.getIDToken()

            return SMSVerifyResponse(
                success: true,
                token: idToken,
                userId: user.uid
            )
        } catch let error as NSError {
            // Firebase Auth error codes for invalid verification code
            if error.code == AuthErrorCode.invalidVerificationCode.rawValue {
                throw SMSAuthError.invalidCode("Invalid code. Please try again.")
            }
            if error.code == AuthErrorCode.sessionExpired.rawValue {
                throw SMSAuthError.invalidCode("Code expired. Please request a new one.")
            }
            throw SMSAuthError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Validate Token (refreshes Firebase ID token)

    func validateToken(_ token: String) async throws -> SMSUserResponse {
        guard let user = Auth.auth().currentUser else {
            throw SMSAuthError.invalidToken
        }

        do {
            // Force-refresh the ID token to ensure it's still valid
            let freshToken = try await user.getIDToken(forcingRefresh: true)
            return SMSUserResponse(
                userId: user.uid,
                token: freshToken
            )
        } catch {
            throw SMSAuthError.invalidToken
        }
    }
}

// MARK: - Response Types

struct SMSVerifyResponse: Decodable {
    let success: Bool
    let token: String      // Firebase ID token
    let userId: String     // Firebase UID
}

struct SMSUserResponse: Decodable {
    let userId: String
    let token: String      // Refreshed Firebase ID token
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
