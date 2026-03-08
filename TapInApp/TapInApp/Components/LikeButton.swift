//
//  LikeButton.swift
//  TapInApp
//
//  Reusable like button with optimistic updates and animation.
//  All like state is persisted server-side in Firestore.
//

import SwiftUI

struct LikeButton: View {
    let contentType: ContentType
    let contentId: String

    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var isAnimating = false
    @State private var hasLoaded = false

    var body: some View {
        Button {
            toggleLike()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isLiked ? .red : .secondary)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isAnimating)

                if likeCount > 0 {
                    Text("\(likeCount)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            guard !hasLoaded else { return }
            await fetchStatus()
        }
    }

    private func toggleLike() {
        // Optimistic update
        let wasLiked = isLiked
        let oldCount = likeCount
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        likeCount = max(0, likeCount)

        withAnimation { isAnimating = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isAnimating = false
        }

        Task {
            do {
                let (liked, count) = try await SocialService.shared.toggleLike(
                    contentType: contentType, contentId: contentId
                )
                isLiked = liked
                likeCount = count
            } catch {
                // Revert on failure
                isLiked = wasLiked
                likeCount = oldCount
            }
        }
    }

    private func fetchStatus() async {
        do {
            let status = try await SocialService.shared.likeStatus(
                contentType: contentType, contentId: contentId
            )
            isLiked = status.liked
            likeCount = status.likeCount
            hasLoaded = true
        } catch {
            // Silent — button shows 0 likes by default
        }
    }
}
