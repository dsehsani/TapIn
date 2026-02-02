//
//  AppError.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/31/26.
//
//  MARK: - App Error Types
//  Centralized error handling for consistent error management across the app.
//  Use these types for all error handling to maintain consistency.
//

import Foundation

// MARK: - App Error
/// Centralized error type for the TapInApp application.
/// Use this enum for all error handling to maintain consistency.
enum AppError: Error, LocalizedError, Equatable {
    // MARK: - Network Errors
    case networkUnavailable
    case serverError(statusCode: Int)
    case requestFailed(reason: String)
    case invalidResponse
    case decodingFailed
    case timeout

    // MARK: - Authentication Errors
    case notAuthenticated
    case invalidCredentials
    case sessionExpired
    case accountDisabled

    // MARK: - Data Errors
    case notFound
    case invalidData
    case saveFailed
    case loadFailed

    // MARK: - Game Errors
    case gameNotAvailable
    case leaderboardUnavailable
    case scoreSubmissionFailed

    // MARK: - General Errors
    case unknown(message: String)
    case permissionDenied

    // MARK: - Localized Description
    var errorDescription: String? {
        switch self {
        // Network
        case .networkUnavailable:
            return "No internet connection. Please check your network settings."
        case .serverError(let statusCode):
            return "Server error (code: \(statusCode)). Please try again later."
        case .requestFailed(let reason):
            return "Request failed: \(reason)"
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .decodingFailed:
            return "Failed to process server response."
        case .timeout:
            return "Request timed out. Please try again."

        // Authentication
        case .notAuthenticated:
            return "Please sign in to continue."
        case .invalidCredentials:
            return "Invalid email or password."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .accountDisabled:
            return "This account has been disabled."

        // Data
        case .notFound:
            return "The requested item was not found."
        case .invalidData:
            return "Invalid data provided."
        case .saveFailed:
            return "Failed to save data."
        case .loadFailed:
            return "Failed to load data."

        // Game
        case .gameNotAvailable:
            return "This game is currently unavailable."
        case .leaderboardUnavailable:
            return "Leaderboard is currently unavailable."
        case .scoreSubmissionFailed:
            return "Failed to submit score. Please try again."

        // General
        case .unknown(let message):
            return message
        case .permissionDenied:
            return "Permission denied."
        }
    }

    // MARK: - User-Friendly Title
    var title: String {
        switch self {
        case .networkUnavailable, .timeout:
            return "Connection Error"
        case .serverError, .requestFailed, .invalidResponse, .decodingFailed:
            return "Server Error"
        case .notAuthenticated, .invalidCredentials, .sessionExpired, .accountDisabled:
            return "Authentication Error"
        case .notFound, .invalidData, .saveFailed, .loadFailed:
            return "Data Error"
        case .gameNotAvailable, .leaderboardUnavailable, .scoreSubmissionFailed:
            return "Game Error"
        case .unknown, .permissionDenied:
            return "Error"
        }
    }

    // MARK: - Equatable
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}

// MARK: - Result Type Alias
/// Convenient type alias for Results with AppError
typealias AppResult<T> = Result<T, AppError>
