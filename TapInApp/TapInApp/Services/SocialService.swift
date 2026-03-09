//
//  SocialService.swift
//  TapInApp
//
//  Service layer for likes with shared in-memory cache.
//  All data is persisted server-side in Firestore.
//  Views observe likeCache via @Published for automatic updates.
//

import Foundation
import Combine

// MARK: - Models

enum ContentType: String, Codable {
    case article, event
}

struct LikeStatus: Equatable {
    let liked: Bool
    let likeCount: Int
}

// MARK: - Social Service

@MainActor
final class SocialService: ObservableObject {
    static let shared = SocialService()
    private init() {}

    /// Shared like cache — keyed by "<contentType>_<contentId>".
    /// Views observe this via @ObservedObject for automatic UI updates.
    @Published private(set) var likeCache: [String: LikeStatus] = [:]

    /// After a toggle, ignore refresh results for this key until the cooldown expires.
    /// This prevents stale Firestore reads from overwriting the optimistic/confirmed state.
    private var toggleCooldowns: [String: Date] = [:]

    /// How long to protect a key after a toggle (seconds).
    /// Gives Firestore transaction time to commit + propagate.
    private let cooldownDuration: TimeInterval = 5

    // MARK: - Cache Helpers

    func cacheKey(_ contentType: ContentType, _ contentId: String) -> String {
        "\(contentType.rawValue)_\(contentId)"
    }

    /// Update cache entry. All observers (LikeButton, CardLikeIndicator) update automatically.
    func updateCache(contentType: ContentType, contentId: String, status: LikeStatus) {
        likeCache[cacheKey(contentType, contentId)] = status
    }

    /// Start cooldown for a key — refresh results will be ignored until it expires.
    func startToggleCooldown(contentType: ContentType, contentId: String) {
        let key = cacheKey(contentType, contentId)
        toggleCooldowns[key] = Date().addingTimeInterval(cooldownDuration)
    }

    /// Check if a key is still in its cooldown window.
    private func isInCooldown(_ key: String) -> Bool {
        guard let expiry = toggleCooldowns[key] else { return false }
        if Date() < expiry {
            return true
        }
        // Cooldown expired — clean up
        toggleCooldowns.removeValue(forKey: key)
        return false
    }

    /// Prefetch and cache like status for a batch of items.
    /// Call this when a feed loads its items — replaces N individual calls with 1 batch call.
    /// Always fetches from server (no skip for cached items) to ensure fresh counts.
    func prefetchLikeStatus(items: [(ContentType, String)]) async {
        guard !items.isEmpty else { return }
        do {
            let statuses = try await batchLikeStatus(items: items)
            for (key, status) in statuses {
                // Don't overwrite items in cooldown (recently toggled)
                guard !isInCooldown(key) else { continue }
                likeCache[key] = status
            }
        } catch { /* silent */ }
    }

    /// Refresh cache for all currently-tracked items.
    /// Call on foreground return, pull-to-refresh, or a timer.
    func refreshAllCachedLikes() async {
        let items: [(ContentType, String)] = likeCache.keys.compactMap { key in
            // Skip items in cooldown
            guard !isInCooldown(key) else { return nil }
            // Key format: "article_<socialId>" or "event_<socialId>"
            guard let separatorIndex = key.firstIndex(of: "_") else { return nil }
            let typeStr = String(key[key.startIndex..<separatorIndex])
            let idStr = String(key[key.index(after: separatorIndex)...])
            guard let ct = ContentType(rawValue: typeStr) else { return nil }
            return (ct, idStr)
        }
        guard !items.isEmpty else { return }
        do {
            let statuses = try await batchLikeStatus(items: items)
            for (key, status) in statuses {
                // Double-check cooldown (might have started during the network call)
                guard !isInCooldown(key) else { continue }
                likeCache[key] = status
            }
        } catch { /* silent */ }
    }

    // MARK: - Likes

    /// Toggle like on/off. Returns (isLiked, likeCount).
    func toggleLike(contentType: ContentType, contentId: String) async throws -> (Bool, Int) {
        guard let token = AppState.shared.backendToken else {
            throw SocialError.notAuthenticated
        }

        let body: [String: Any] = [
            "content_type": contentType.rawValue,
            "content_id": contentId
        ]

        let result = try await post(url: APIConfig.socialLikeURL, token: token, body: body)
        let liked = result["liked"] as? Bool ?? false
        let count = result["like_count"] as? Int ?? 0
        return (liked, count)
    }

    /// Fetch like status for a single item.
    func likeStatus(contentType: ContentType, contentId: String) async throws -> LikeStatus {
        guard let token = AppState.shared.backendToken else {
            throw SocialError.notAuthenticated
        }

        let encodedType = contentType.rawValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? contentType.rawValue
        let encodedId = contentId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? contentId
        let urlString = "\(APIConfig.socialLikeStatusURL)?content_type=\(encodedType)&content_id=\(encodedId)"
        let result = try await get(url: urlString, token: token)
        return LikeStatus(
            liked: result["liked"] as? Bool ?? false,
            likeCount: result["like_count"] as? Int ?? 0
        )
    }

    /// Batch fetch like status for multiple items.
    func batchLikeStatus(items: [(ContentType, String)]) async throws -> [String: LikeStatus] {
        guard let token = AppState.shared.backendToken else {
            throw SocialError.notAuthenticated
        }

        let itemDicts = items.map { ["content_type": $0.0.rawValue, "content_id": $0.1] }
        let body: [String: Any] = ["items": itemDicts]
        let result = try await post(url: APIConfig.socialBatchLikeStatusURL, token: token, body: body)

        var statuses: [String: LikeStatus] = [:]
        if let results = result["results"] as? [String: [String: Any]] {
            for (key, value) in results {
                statuses[key] = LikeStatus(
                    liked: value["liked"] as? Bool ?? false,
                    likeCount: value["like_count"] as? Int ?? 0
                )
            }
        }
        return statuses
    }

    // MARK: - Private Helpers

    private func post(url: String, token: String, body: [String: Any]) async throws -> [String: Any] {
        guard let requestURL = URL(string: url) else { throw SocialError.invalidURL }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SocialError.serverError
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SocialError.serverError
        }
        return json
    }

    private func get(url: String, token: String) async throws -> [String: Any] {
        guard let requestURL = URL(string: url) else { throw SocialError.invalidURL }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SocialError.serverError
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SocialError.serverError
        }
        return json
    }
}

// MARK: - Errors

enum SocialError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case serverError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Please sign in to continue."
        case .invalidURL: return "Invalid request."
        case .serverError: return "Something went wrong. Please try again."
        }
    }
}
