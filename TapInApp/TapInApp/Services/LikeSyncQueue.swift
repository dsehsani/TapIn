//
//  LikeSyncQueue.swift
//  TapInApp
//
//  Persistent retry queue for failed like actions.
//  Stores pending actions in UserDefaults — survives app kill.
//  Drains on foreground return and after successful auth.
//

import Foundation

@MainActor
final class LikeSyncQueue {
    static let shared = LikeSyncQueue()
    private let defaultsKey = "pendingLikeActions"

    struct PendingAction: Codable {
        let contentType: String   // "article" or "event"
        let contentId: String
        let action: String        // "like" or "unlike"
        let enqueuedAt: Date
        var retryCount: Int = 0
    }

    /// Enqueue a pending like action. Persisted to UserDefaults — survives app kill.
    func enqueue(contentType: ContentType, contentId: String, action: String) {
        var queue = load()
        // Dedup: if there's already a pending action for this item, replace it with the latest intent
        queue.removeAll { $0.contentId == contentId && $0.contentType == contentType.rawValue }
        queue.append(PendingAction(
            contentType: contentType.rawValue,
            contentId: contentId,
            action: action,
            enqueuedAt: Date()
        ))
        save(queue)
    }

    /// Drain the queue — call on app foreground and after successful auth.
    func drain() async {
        let queue = load()
        guard !queue.isEmpty else { return }

        var remaining: [PendingAction] = []
        for var item in queue {
            // Expire actions older than 48 hours
            if Date().timeIntervalSince(item.enqueuedAt) > 172_800 { continue }

            do {
                let (liked, count) = try await SocialService.shared.setLike(
                    contentType: ContentType(rawValue: item.contentType) ?? .article,
                    contentId: item.contentId,
                    action: item.action
                )
                // Success — update cache with confirmed server state
                if let ct = ContentType(rawValue: item.contentType) {
                    SocialService.shared.updateCache(
                        contentType: ct, contentId: item.contentId,
                        status: LikeStatus(liked: liked, likeCount: count)
                    )
                }
            } catch SocialError.rejected {
                // Server rejected — discard, don't retry
            } catch {
                // Still failing — keep in queue, cap at 5 retries
                item.retryCount += 1
                if item.retryCount < 5 {
                    remaining.append(item)
                }
            }
        }
        save(remaining)
    }

    private func load() -> [PendingAction] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let queue = try? JSONDecoder().decode([PendingAction].self, from: data) else { return [] }
        return queue
    }

    private func save(_ queue: [PendingAction]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(queue), forKey: defaultsKey)
    }
}
