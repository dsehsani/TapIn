//
//  DateWordGenerator.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/22/26.
//
//  MARK: - Service Layer (MVVM)
//  This utility struct provides deterministic word selection based on date.
//  It ensures all users get the same word on the same day.
//
//  Architecture:
//  - Static methods for stateless utility operations
//  - Uses a fixed reference date for day index calculation
//  - Provides date formatting utilities for UI
//
//  Integration Notes:
//  - Call wordForDate() to get the daily word
//  - Call dateKey() to get a unique key for storage
//  - Use today property for current date operations
//
//  How Daily Words Work:
//  1. Calculate days since reference date (Jan 1, 2026)
//  2. Use modulo to cycle through answer word list
//  3. Same date always produces same index = same word
//

import Foundation

// MARK: - Date Word Generator
/// Utility struct for deterministic daily word generation.
///
/// Provides:
/// - Daily word selection (same word for all users on same day)
/// - Date key generation for storage
/// - Date formatting for display
///
/// The algorithm uses a fixed reference date and counts days since then.
/// This index is used to select a word from the answer list, ensuring:
/// - Consistency: Same date = same word everywhere
/// - Offline support: No network required
/// - Predictability: Past dates can be replayed
///
/// Example:
/// ```swift
/// let word = DateWordGenerator.wordForDate(date, from: answerWords)
/// let key = DateWordGenerator.dateKey(for: date) // "2026-01-22"
/// ```
///
struct DateWordGenerator {

    // MARK: - Reference Date

    /// Reference date for calculating day index (app launch date)
    /// All day calculations are relative to this date
    private static let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()

    // MARK: - Word Generation

    /// Generates a deterministic word for a given date
    ///
    /// Algorithm:
    /// 1. Calculate days between reference date and target date
    /// 2. Use absolute value (supports dates before reference)
    /// 3. Modulo by word list length to get index
    /// 4. Return word at that index
    ///
    /// - Parameters:
    ///   - date: The date to generate a word for
    ///   - wordList: The list of possible answer words
    /// - Returns: A word from the list, determined by the date
    static func wordForDate(_ date: Date, from wordList: [String]) -> String {
        guard !wordList.isEmpty else { return "AGGIE" }

        let daysSinceReference = daysBetween(referenceDate, and: date)
        let index = abs(daysSinceReference) % wordList.count
        return wordList[index]
    }

    // MARK: - Date Calculations

    /// Calculates the number of days between two dates
    ///
    /// Time components are ignored (uses start of day for both)
    ///
    /// - Parameters:
    ///   - startDate: The starting date
    ///   - endDate: The ending date
    /// - Returns: Number of days (positive if end > start)
    private static func daysBetween(_ startDate: Date, and endDate: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let components = calendar.dateComponents([.day], from: start, to: end)
        return components.day ?? 0
    }

    // MARK: - Date Properties

    /// Today's date with time stripped (start of day)
    /// Use this for consistent "today" comparisons
    static var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    // MARK: - Date Formatting

    /// Formats a date for display (medium style)
    ///
    /// Example output: "Jan 22, 2026"
    ///
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Formats a date with short style
    ///
    /// Example output: "Jan 22"
    ///
    /// - Parameter date: The date to format
    /// - Returns: Short formatted date string
    static func shortFormatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// Generates a unique key string for storing data per date
    ///
    /// Format: "yyyy-MM-dd" (e.g., "2026-01-22")
    /// Used as dictionary key for GameStorage
    ///
    /// - Parameter date: The date to generate a key for
    /// - Returns: Date key string
    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
