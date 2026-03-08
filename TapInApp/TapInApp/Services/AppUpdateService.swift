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

    /// Custom session with a short timeout so a slow network doesn't stall launch.
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 8
        return URLSession(configuration: config)
    }()

    /// Checks whether the installed version is outdated.
    /// 1. Tries the backend `/api/config/min-version` endpoint (instant, you control it).
    /// 2. Falls back to the iTunes Lookup API if the backend is unreachable.
    /// Returns `false` (fail-open) if both checks fail — never blocks on a bad network.
    func isUpdateRequired() async -> Bool {
        guard let installedVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return false
        }

        // Try backend first — this is the source of truth you control
        if let backendResult = await checkBackendMinVersion(installed: installedVersion) {
            return backendResult
        }

        // Fallback: iTunes Lookup API
        return await checkiTunesVersion(installed: installedVersion)
    }

    /// Asks the TapIn backend for the minimum required version.
    private func checkBackendMinVersion(installed: String) async -> Bool? {
        guard let url = URL(string: APIConfig.minVersionURL) else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let minVersion = json["minVersion"] as? String
            else { return nil }
            return isVersion(installed, olderThan: minVersion)
        } catch {
            return nil  // backend unreachable — fall through to iTunes
        }
    }

    /// Checks the public iTunes Lookup API as a fallback.
    private func checkiTunesVersion(installed: String) async -> Bool {
        guard let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)") else {
            return false
        }
        do {
            let (data, _) = try await session.data(from: lookupURL)
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

            return isVersion(installed, olderThan: storeVersion)
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
