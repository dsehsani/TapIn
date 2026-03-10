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
import FirebaseFirestore

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

    /// How long to protect a key's `liked` state after a toggle (seconds).
    /// During cooldown, refreshes can still update likeCount but NOT the liked boolean.
    private let cooldownDuration: TimeInterval = 10

    /// Active Firestore real-time listeners for like_count updates.
    private var likeListeners: [String: ListenerRegistration] = [:]

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
    func isInCooldown(_ key: String) -> Bool {
        guard let expiry = toggleCooldowns[key] else { return false }
        if Date() < expiry {
            return true
        }
        // Cooldown expired — clean up
        toggleCooldowns.removeValue(forKey: key)
        return false
    }

    /// Merge a server status into the cache, respecting cooldown.
    /// During cooldown: update likeCount but preserve the user's optimistic `liked` state.
    /// After cooldown: full overwrite with server truth.
    private func mergeStatus(key: String, serverStatus: LikeStatus) {
        if isInCooldown(key), let current = likeCache[key] {
            // Protect liked state, but accept the latest count
            likeCache[key] = LikeStatus(liked: current.liked, likeCount: serverStatus.likeCount)
        } else {
            likeCache[key] = serverStatus
        }
    }

    /// Prefetch and cache like status for a batch of items.
    /// Call this when a feed loads its items — replaces N individual calls with 1 batch call.
    /// Always fetches from server (no skip for cached items) to ensure fresh counts.
    func prefetchLikeStatus(items: [(ContentType, String)]) async {
        guard !items.isEmpty else { return }
        do {
            let statuses = try await batchLikeStatus(items: items)
            for (key, status) in statuses {
                mergeStatus(key: key, serverStatus: status)
            }
        } catch {
            print("[SocialService] prefetchLikeStatus error: \(error)")
        }
    }

    /// Refresh cache for all currently-tracked items.
    /// Call on foreground return, pull-to-refresh, or a timer.
    func refreshAllCachedLikes() async {
        let items: [(ContentType, String)] = likeCache.keys.compactMap { key in
            guard let separatorIndex = key.firstIndex(of: "_") else { return nil }
            let typeStr = String(key[key.startIndex..<separatorIndex])
            let idStr = String(key[key.index(after: separatorIndex)...])
            guard let ct = ContentType(rawValue: typeStr) else { return nil }
            return (ct, idStr)
        }
        guard !items.isEmpty else { return }
        do {
            let statuses = try await batchLikeStatus(items: items)
            print("[SocialService] refreshAllCachedLikes got \(statuses.count) items")
            for (key, status) in statuses {
                mergeStatus(key: key, serverStatus: status)
            }
        } catch {
            print("[SocialService] refreshAllCachedLikes error: \(error)")
        }
    }

    // MARK: - Likes

    /// Idempotent like/unlike (Instagram-style). Returns (isLiked, likeCount).
    /// action: "like" or "unlike" — sending the same action twice is a safe no-op.
    func setLike(contentType: ContentType, contentId: String, action: String) async throws -> (Bool, Int) {
        guard let token = AppState.shared.backendToken else {
            throw SocialError.notAuthenticated
        }

        let body: [String: Any] = [
            "content_type": contentType.rawValue,
            "content_id": contentId,
            "action": action
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

        // Use a restricted character set that encodes &, ?, =, # which would break query params
        var queryValueAllowed = CharacterSet.urlQueryAllowed
        queryValueAllowed.remove(charactersIn: "&=+?#")
        let encodedType = contentType.rawValue.addingPercentEncoding(withAllowedCharacters: queryValueAllowed) ?? contentType.rawValue
        let encodedId = contentId.addingPercentEncoding(withAllowedCharacters: queryValueAllowed) ?? contentId
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

    // MARK: - Real-Time Listeners (Bug 4)

    /// Subscribe to real-time like_count updates for an item.
    /// The count updates instantly on all devices when any user likes/unlikes.
    /// Call this when opening a detail view. Call stopListening() on dismiss.
    func startListening(contentType: ContentType, contentId: String) {
        let key = cacheKey(contentType, contentId)
        guard likeListeners[key] == nil else { return }   // already listening

        let collectionName = contentType == .article ? "articles" : "events"
        let docRef = Firestore.firestore().collection(collectionName).document(contentId)

        let listener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            guard let data = snapshot?.data() else { return }
            let serverCount = data["like_count"] as? Int ?? 0

            Task { @MainActor in
                let currentStatus = self.likeCache[key]
                let updatedStatus = LikeStatus(
                    liked: currentStatus?.liked ?? false,
                    likeCount: serverCount
                )
                self.mergeStatus(key: key, serverStatus: updatedStatus)
            }
        }
        likeListeners[key] = listener
    }

    /// Stop listening. Call when leaving the detail view.
    func stopListening(contentType: ContentType, contentId: String) {
        let key = cacheKey(contentType, contentId)
        likeListeners[key]?.remove()
        likeListeners.removeValue(forKey: key)
    }

    // MARK: - Private Helpers

    private func post(url: String, token: String, body: [String: Any]) async throws -> [String: Any] {
        guard let requestURL = URL(string: url) else { throw SocialError.invalidURL }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30   // handles slow cold starts
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw SocialError.serverError(0) }

            if (400...499).contains(http.statusCode) {
                throw SocialError.rejected(statusCode: http.statusCode)
            }
            if !(200...299).contains(http.statusCode) {
                throw SocialError.serverError(http.statusCode)
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw SocialError.serverError(http.statusCode)
            }
            return json
        } catch let error as SocialError {
            throw error   // re-throw typed errors as-is
        } catch {
            throw SocialError.networkFailure(error)   // URLError.timedOut, no connection, etc.
        }
    }

    private func get(url: String, token: String) async throws -> [String: Any] {
        guard let requestURL = URL(string: url) else { throw SocialError.invalidURL }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw SocialError.serverError(0) }

            if (400...499).contains(http.statusCode) {
                throw SocialError.rejected(statusCode: http.statusCode)
            }
            if !(200...299).contains(http.statusCode) {
                throw SocialError.serverError(http.statusCode)
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw SocialError.serverError(http.statusCode)
            }
            return json
        } catch let error as SocialError {
            throw error
        } catch {
            throw SocialError.networkFailure(error)
        }
    }
}

// MARK: - Errors

enum SocialError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case rejected(statusCode: Int)    // 4xx — server said no, revert
    case networkFailure(Error)        // timeout, no connection — retry, don't revert
    case serverError(Int)             // 5xx — retry, don't revert

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Please sign in to continue."
        case .invalidURL: return "Invalid request."
        case .rejected: return "Request was rejected."
        case .networkFailure: return "Network error. Your action will be retried."
        case .serverError: return "Something went wrong. Please try again."
        }
    }
}
