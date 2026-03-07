//
//  AppUpdateService.swift
//  TapInApp
//
//  Checks the App Store version against the installed version on launch.
//  If the App Store has a newer version, signals that a force update is needed.
//

import Foundation

@MainActor
final class AppUpdateService {
    static let shared = AppUpdateService()
    private init() {}

    private let bundleID = "DariusEhsani.TapInApp"

    /// The App Store URL to open when the user taps "Update Now".
    /// Populated after a successful version check.
    private(set) var appStoreURL: URL?

    /// Checks the App Store version. Returns true if the installed version is outdated.
    func isUpdateRequired() async -> Bool {
        guard let installedVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return false
        }

        guard let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)") else {
            return false
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: lookupURL)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                let first = results.first,
                let storeVersion = first["version"] as? String
            else { return false }

            // Build App Store deep link from the numeric app ID
            if let trackId = first["trackId"] as? Int {
                appStoreURL = URL(string: "https://apps.apple.com/app/id\(trackId)")
            }

            return isVersion(installedVersion, olderThan: storeVersion)
        } catch {
            return false
        }
    }

    /// Semantic version comparison: returns true if `a` is strictly older than `b`.
    private func isVersion(_ a: String, olderThan b: String) -> Bool {
        let lhs = a.split(separator: ".").compactMap { Int($0) }
        let rhs = b.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(lhs.count, rhs.count)
        for i in 0..<maxLen {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l < r { return true }
            if l > r { return false }
        }
        return false
    }
}
