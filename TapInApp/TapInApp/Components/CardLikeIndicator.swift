//
//  CardLikeIndicator.swift
//  TapInApp
//
//  Compact tappable like button for feed cards.
//  Observes SocialService.likeCache for shared, reactive like state.
//

import SwiftUI

struct CardLikeIndicator: View {
    let contentType: ContentType
    let contentId: String

    @ObservedObject private var socialService = SocialService.shared
    @EnvironmentObject private var appState: AppState
    @State private var isAnimating = false
    @State private var isToggling = false
    @State private var showSignInPrompt = false

    private var cacheKey: String { socialService.cacheKey(contentType, contentId) }
    private var status: LikeStatus { socialService.likeCache[cacheKey] ?? LikeStatus(liked: false, likeCount: 0) }

    var body: some View {
        Button {
            toggleLike()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: status.liked ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(status.liked ? .red : .secondary)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isAnimating)

                Text("\(status.likeCount)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .alert("Sign In Required", isPresented: $showSignInPrompt) {
            Button("Sign In") {
                appState.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Create an account to like posts and access all features.")
        }
        .onAppear {
            if socialService.likeCache[cacheKey] == nil {
                Task {
                    let fetched = try? await SocialService.shared.likeStatus(
                        contentType: contentType, contentId: contentId
                    )
                    if let fetched {
                        socialService.updateCache(contentType: contentType, contentId: contentId, status: fetched)
                    }
                }
            }
        }
    }

    private func toggleLike() {
        if appState.isGuestMode {
            showSignInPrompt = true
            return
        }
        guard !isToggling else { return }
        isToggling = true

        let wasLiked = status.liked
        let oldCount = status.likeCount
        let newLiked = !wasLiked
        let newCount = max(0, oldCount + (newLiked ? 1 : -1))

        socialService.updateCache(
            contentType: contentType, contentId: contentId,
            status: LikeStatus(liked: newLiked, likeCount: newCount)
        )

        socialService.startToggleCooldown(contentType: contentType, contentId: contentId)

        withAnimation { isAnimating = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isAnimating = false }

        let action = newLiked ? "like" : "unlike"
        Task {
            do {
                let (liked, count) = try await SocialService.shared.setLike(
                    contentType: contentType, contentId: contentId, action: action
                )
                socialService.updateCache(
                    contentType: contentType, contentId: contentId,
                    status: LikeStatus(liked: liked, likeCount: count)
                )
            } catch SocialError.rejected {
                socialService.updateCache(
                    contentType: contentType, contentId: contentId,
                    status: LikeStatus(liked: wasLiked, likeCount: oldCount)
                )
            } catch {
                LikeSyncQueue.shared.enqueue(
                    contentType: contentType, contentId: contentId, action: action
                )
            }
            isToggling = false
        }
    }
}
