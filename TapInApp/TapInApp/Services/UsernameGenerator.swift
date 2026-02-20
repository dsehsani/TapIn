//
//  UsernameGenerator.swift
//  TapInApp
//
//  MARK: - Username Generator Service
//  Generates random display names for leaderboard entries.
//  Names are deterministic per user per day (same user gets same name each day).
//

import Foundation

/// Service for generating random display names for leaderboard entries.
///
/// Generates names in the format "AdjectiveNoun" (e.g., "SwiftFalcon", "BraveTiger").
/// Names are deterministic: the same user on the same day always gets the same name.
/// Supports up to 400 unique names per day (20 adjectives × 20 nouns).
///
class UsernameGenerator {

    // MARK: - Singleton

    static let shared = UsernameGenerator()

    // MARK: - Storage Key

    private let storageKeyPrefix = "generatedUsername_"

    // MARK: - Word Lists (20 × 20 = 400 combinations)

    private let adjectives: [String] = [
        "Swift", "Brave", "Clever", "Bold", "Mighty",
        "Noble", "Agile", "Fierce", "Cosmic", "Golden",
        "Silver", "Crystal", "Thunder", "Shadow", "Blazing",
        "Rapid", "Lucky", "Mystic", "Royal", "Epic"
    ]

    private let nouns: [String] = [
        "Falcon", "Tiger", "Phoenix", "Dragon", "Eagle",
        "Wolf", "Panther", "Hawk", "Lion", "Bear",
        "Fox", "Raven", "Shark", "Cobra", "Mustang",
        "Jaguar", "Viper", "Griffin", "Pegasus", "Titan"
    ]

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Gets or generates a display name for the current user for today.
    ///
    /// If a name was already generated today, returns the cached name.
    /// Otherwise, generates a new deterministic name based on user ID and date.
    ///
    /// - Returns: A display name like "SwiftFalcon"
    func getDisplayName() -> String {
        let dateKey = formatDateKey(Date())
        let storageKey = storageKeyPrefix + dateKey

        // Check if we already have a name for today
        if let cachedName = UserDefaults.standard.string(forKey: storageKey) {
            return cachedName
        }

        // Generate a new name
        let name = generateName(for: Date())

        // Cache it for today
        UserDefaults.standard.set(name, forKey: storageKey)

        // Clean up old cached names (keep only last 7 days)
        cleanupOldNames()

        return name
    }

    /// Gets the display name for a specific date.
    ///
    /// Useful for displaying historical scores with consistent names.
    ///
    /// - Parameter date: The date to get the name for
    /// - Returns: A display name
    func getDisplayName(for date: Date) -> String {
        let dateKey = formatDateKey(date)
        let storageKey = storageKeyPrefix + dateKey

        if let cachedName = UserDefaults.standard.string(forKey: storageKey) {
            return cachedName
        }

        // For past dates, generate deterministically but don't cache
        return generateName(for: date)
    }

    /// Generates a preview name (not cached).
    ///
    /// - Returns: Today's display name without caching
    func previewTodaysName() -> String {
        return generateName(for: Date())
    }

    // MARK: - Private Methods

    /// Generates a deterministic name based on date and device ID.
    private func generateName(for date: Date) -> String {
        // Create a seed from date + device identifier
        let dateString = formatDateKey(date)
        let deviceId = getDeviceIdentifier()
        let seed = "\(dateString)_\(deviceId)"

        // Use hash to get deterministic indices
        let hash = abs(seed.hashValue)
        let adjIndex = hash % adjectives.count
        let nounIndex = (hash / adjectives.count) % nouns.count

        return adjectives[adjIndex] + nouns[nounIndex]
    }

    /// Gets a stable device identifier.
    private func getDeviceIdentifier() -> String {
        let key = "deviceIdentifier"

        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }

        // Generate new identifier
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    /// Formats a date as yyyy-MM-dd.
    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Cleans up cached names older than 7 days.
    private func cleanupOldNames() {
        let calendar = Calendar.current
        let defaults = UserDefaults.standard

        let allKeys = defaults.dictionaryRepresentation().keys
        let usernameKeys = allKeys.filter { $0.hasPrefix(storageKeyPrefix) }

        let cutoffDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cutoffKey = storageKeyPrefix + formatDateKey(cutoffDate)

        for key in usernameKeys {
            if key < cutoffKey {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
