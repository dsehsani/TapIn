//
//  SocialService.swift
//  TapInApp
//
//  Service layer for likes and comments. All data is persisted
//  server-side in Firestore — nothing stored locally.
//

import Foundation

// MARK: - Models

enum ContentType: String, Codable {
    case article, event, comment
}

struct LikeStatus {
    let liked: Bool
    let likeCount: Int
}

struct Comment: Identifiable, Codable {
    let id: String
    let authorName: String
    let body: String
    var likeCount: Int
    var likedByMe: Bool
    let createdAt: String
    let isMine: Bool

    enum CodingKeys: String, CodingKey {
        case id = "comment_id"
        case authorName = "author_name"
        case body
        case likeCount = "like_count"
        case likedByMe = "liked_by_me"
        case createdAt = "created_at"
        case isMine = "is_mine"
    }
}

struct CommentsPage {
    let comments: [Comment]
    let total: Int
    let page: Int
    let hasMore: Bool
}

// MARK: - Social Service

@MainActor
final class SocialService {
    static let shared = SocialService()
    private init() {}

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

        let urlString = "\(APIConfig.socialLikeStatusURL)?content_type=\(contentType.rawValue)&content_id=\(contentId)"
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

    // MARK: - Comments

    /// Submit a new comment. Returns immediately — comment enters moderation.
    func postComment(contentType: ContentType, contentId: String, body: String) async throws {
        guard let token = AppState.shared.backendToken else {
            throw SocialError.notAuthenticated
        }

        let requestBody: [String: Any] = [
            "content_type": contentType.rawValue,
            "content_id": contentId,
            "body": body
        ]

        _ = try await post(url: APIConfig.socialCommentURL, token: token, body: requestBody)
    }

    /// Fetch approved comments for a piece of content.
    func fetchComments(contentType: ContentType, contentId: String, page: Int = 1) async throws -> CommentsPage {
        guard let token = AppState.shared.backendToken else {
            throw SocialError.notAuthenticated
        }

        let urlString = "\(APIConfig.socialCommentsURL)?content_type=\(contentType.rawValue)&content_id=\(contentId)&page=\(page)"
        let result = try await get(url: urlString, token: token)

        var comments: [Comment] = []
        if let data = try? JSONSerialization.data(withJSONObject: result["comments"] ?? []),
           let decoded = try? JSONDecoder().decode([Comment].self, from: data) {
            comments = decoded
        }

        return CommentsPage(
            comments: comments,
            total: result["total"] as? Int ?? 0,
            page: result["page"] as? Int ?? 1,
            hasMore: result["has_more"] as? Bool ?? false
        )
    }

    /// Delete own comment.
    func deleteComment(commentId: String, contentType: ContentType, contentId: String) async throws {
        guard let token = AppState.shared.backendToken else {
            throw SocialError.notAuthenticated
        }

        guard let requestURL = URL(string: "\(APIConfig.socialCommentURL)/\(commentId)") else {
            throw SocialError.invalidURL
        }

        let body: [String: Any] = [
            "content_type": contentType.rawValue,
            "content_id": contentId
        ]

        var request = URLRequest(url: requestURL)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SocialError.serverError
        }
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
            if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                throw SocialError.rateLimited
            }
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
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Please sign in to continue."
        case .invalidURL: return "Invalid request."
        case .serverError: return "Something went wrong. Please try again."
        case .rateLimited: return "Too many comments. Please wait a few minutes."
        }
    }
}
