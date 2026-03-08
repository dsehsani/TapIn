//
//  CommentsView.swift
//  TapInApp
//
//  Bottom sheet for viewing and posting comments on articles/events.
//  All comments are persisted server-side — AI moderated before display.
//

import SwiftUI

struct CommentsView: View {
    let contentType: ContentType
    let contentId: String
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [Comment] = []
    @State private var totalCount = 0
    @State private var currentPage = 1
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var showPendingBanner = false
    @State private var errorMessage: String?
    @State private var commentToDelete: Comment?

    private let maxChars = 500

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Comments list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if comments.isEmpty && !isLoading {
                            Text("No comments yet. Be the first!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        }

                        ForEach(comments) { comment in
                            CommentCell(
                                comment: comment,
                                contentType: contentType,
                                contentId: contentId,
                                onDelete: {
                                    commentToDelete = comment
                                }
                            )
                            Divider().padding(.horizontal)
                        }

                        if hasMore && !isLoading {
                            Button("Load more") {
                                Task { await loadMore() }
                            }
                            .font(.subheadline)
                            .padding()
                        }

                        if isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                }

                // Pending banner
                if showPendingBanner {
                    HStack {
                        Image(systemName: "clock")
                        Text("Your comment has been submitted for review.")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                }

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }

                Divider()

                // Input bar
                HStack(spacing: 8) {
                    TextField("Write a comment...", text: $commentText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .font(.subheadline)

                    if commentText.count > 400 {
                        Text("\(maxChars - commentText.count)")
                            .font(.caption2)
                            .foregroundColor(commentText.count > maxChars ? .red : .secondary)
                    }

                    Button {
                        Task { await submitComment() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(canSubmit ? .accentColor : .gray)
                    }
                    .disabled(!canSubmit)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Comments (\(totalCount))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .task { await loadComments() }
            .alert("Delete Comment", isPresented: .init(
                get: { commentToDelete != nil },
                set: { if !$0 { commentToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { commentToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let comment = commentToDelete {
                        Task { await deleteComment(comment) }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this comment?")
            }
        }
    }

    private var canSubmit: Bool {
        !isSubmitting && !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && commentText.count <= maxChars
    }

    private func loadComments() async {
        isLoading = true
        errorMessage = nil
        do {
            let page = try await SocialService.shared.fetchComments(
                contentType: contentType, contentId: contentId, page: 1
            )
            comments = page.comments
            totalCount = page.total
            currentPage = 1
            hasMore = page.hasMore
        } catch {
            errorMessage = "Failed to load comments."
        }
        isLoading = false
    }

    private func loadMore() async {
        let nextPage = currentPage + 1
        isLoading = true
        do {
            let page = try await SocialService.shared.fetchComments(
                contentType: contentType, contentId: contentId, page: nextPage
            )
            comments.append(contentsOf: page.comments)
            currentPage = nextPage
            hasMore = page.hasMore
            totalCount = page.total
        } catch {
            // Silent
        }
        isLoading = false
    }

    private func submitComment() async {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= maxChars else { return }

        isSubmitting = true
        errorMessage = nil
        do {
            try await SocialService.shared.postComment(
                contentType: contentType, contentId: contentId, body: text
            )
            commentText = ""
            showPendingBanner = true

            // Re-fetch after a delay to pick up approved comments
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
            await loadComments()
        } catch let error as SocialError where error == .rateLimited {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to post comment. Please try again."
        }
        isSubmitting = false
    }

    private func deleteComment(_ comment: Comment) async {
        do {
            try await SocialService.shared.deleteComment(
                commentId: comment.id,
                contentType: contentType,
                contentId: contentId
            )
            comments.removeAll { $0.id == comment.id }
            totalCount = max(0, totalCount - 1)
        } catch {
            errorMessage = "Failed to delete comment."
        }
        commentToDelete = nil
    }
}

// MARK: - Comment Cell

private struct CommentCell: View {
    let comment: Comment
    let contentType: ContentType
    let contentId: String
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.authorName)
                    .font(.subheadline.bold())

                Text(timeAgo(comment.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                LikeButton(
                    contentType: .comment,
                    contentId: comment.id
                )
            }

            Text(comment.body)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contextMenu {
            if comment.isMine {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Comment", systemImage: "trash")
                }
            }
        }
    }

    private func timeAgo(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString)
                ?? ISO8601DateFormatter().date(from: isoString) else {
            return ""
        }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}
