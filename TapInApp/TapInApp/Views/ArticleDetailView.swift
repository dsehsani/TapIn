//
//  ArticleDetailView.swift
//  TapInApp
//
//  Full in-app article reading view.
//  Switches between loading skeleton, reading content, and error state.
//

import SwiftUI

struct ArticleDetailView: View {
    let article: NewsArticle
    var savedViewModel: SavedViewModel? = nil
    @StateObject private var viewModel = ArticleDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showComments = false

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                ArticleDetailLoadingView()
            case .loaded(let content):
                ArticleReadingView(
                    content: content,
                    colorScheme: colorScheme,
                    articleId: article.id.uuidString,
                    isSaved: savedViewModel?.isArticleSaved(article) ?? false,
                    showComments: $showComments,
                    onDismiss: { dismiss() },
                    onSave: { savedViewModel?.toggleArticleSaved(article) }
                )
            case .failed(let message):
                ArticleErrorView(message: message, colorScheme: colorScheme, onRetry: {
                    Task { await viewModel.load(article: article) }
                })
            }
        }
        .task {
            await viewModel.load(article: article)
        }
        .onDisappear {
            viewModel.cancelReadTracking()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showComments) {
            CommentsView(contentType: .article, contentId: article.id.uuidString)
                .presentationDetents([.medium, .large])
        }
        .overlay(alignment: .top) {
            if let svm = savedViewModel, svm.showToast {
                SavedToast(
                    message: svm.toastMessage,
                    icon: svm.toastIcon,
                    isSaved: svm.toastIsSaved
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
                .zIndex(100)
            }
        }
    }
}

// MARK: - Reading View

private struct ArticleReadingView: View {
    let content: ArticleContent
    let colorScheme: ColorScheme
    let articleId: String
    let onDismiss: () -> Void
    var onSave: () -> Void = {}
    @State private var isSaved: Bool
    @Binding var showComments: Bool

    init(content: ArticleContent, colorScheme: ColorScheme, articleId: String, isSaved: Bool, showComments: Binding<Bool>, onDismiss: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.content = content
        self.colorScheme = colorScheme
        self.articleId = articleId
        self.onDismiss = onDismiss
        self.onSave = onSave
        self._isSaved = State(initialValue: isSaved)
        self._showComments = showComments
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.adaptiveBackground(colorScheme).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // --- Featured Image ---
                    if let imageURL = content.thumbnailURL {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fill)
                            default:
                                imagePlaceholder
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipped()
                    } else {
                        imagePlaceholder
                            .aspectRatio(16/9, contentMode: .fit)
                    }

                    // --- Article Body ---
                    VStack(alignment: .leading, spacing: 16) {

                        // Category
                        Text(content.category.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                            .padding(.top, 24)

                        // Title
                        Text(content.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                            .fixedSize(horizontal: false, vertical: true)

                        // Byline row
                        HStack(spacing: 4) {
                            Text("By \(content.author)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textSecondary)
                            Spacer()
                            Text(content.publishDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 12))
                                .foregroundColor(.textMuted)
                        }

                        Divider()
                            .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#e2e8f0"))

                        // Body paragraphs
                        ForEach(Array(content.bodyParagraphs.enumerated()), id: \.offset) { _, paragraph in
                            if isQuote(paragraph) {
                                QuoteCalloutView(text: paragraph, colorScheme: colorScheme)
                            } else if isFullBold(paragraph) {
                                sectionHeader(strippingMarkers(from: paragraph), colorScheme: colorScheme)
                            } else {
                                bodyText(paragraph)
                            }
                        }

                        // Open in Browser button
                        Link(destination: content.articleURL) {
                            HStack(spacing: 8) {
                                Image(systemName: "safari")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Open in Browser")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue, lineWidth: 1.5)
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                        Spacer(minLength: 48)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .ignoresSafeArea(edges: .top)

            // --- Floating Nav Bar ---
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                }

                Spacer()

                HStack(spacing: 10) {
                    // Like button
                    LikeButton(contentType: .article, contentId: articleId)
                        .padding(10)
                        .background(.thinMaterial, in: Circle())

                    // Comments button
                    Button { showComments = true } label: {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(10)
                            .background(.thinMaterial, in: Circle())
                    }

                    Button(action: {
                        isSaved.toggle()
                        onSave()
                    }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isSaved ? (colorScheme == .dark ? Color.ucdGold : Color.ucdBlue) : .primary)
                            .padding(10)
                            .background(.thinMaterial, in: Circle())
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSaved)
                    }

                    ShareLink(item: content.articleURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(10)
                            .background(.thinMaterial, in: Circle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 52)
        }
    }

    // Renders a paragraph, interpreting **bold** markdown from the parser
    @ViewBuilder
    private func bodyText(_ paragraph: String) -> some View {
        let textColor: Color = colorScheme == .dark ? Color(hex: "#cbd5e1") : Color(hex: "#1e293b")
        if let attributed = try? AttributedString(
            markdown: paragraph,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.system(size: 16))
                .lineSpacing(7)
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(paragraph)
                .font(.system(size: 16))
                .lineSpacing(7)
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Returns true if the paragraph looks like a direct quote
    private func isQuote(_ text: String) -> Bool {
        let quoteStarters: [Character] = ["\"", "\u{201C}", "\u{2018}"] // ", ", '
        return quoteStarters.contains(where: { text.hasPrefix(String($0)) })
    }

    // Returns true if the ENTIRE paragraph is bold (acts as a section subheading)
    private func isFullBold(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("**") && t.hasSuffix("**") && t.count > 4
    }

    // Strips the leading/trailing ** markers from a full-bold paragraph
    private func strippingMarkers(from text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("**") { t = String(t.dropFirst(2)) }
        if t.hasSuffix("**") { t = String(t.dropLast(2)) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // H3-style section subheading for full-bold paragraphs
    @ViewBuilder
    private func sectionHeader(_ text: String, colorScheme: ColorScheme) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.ucdBlue.opacity(0.3), Color.ucdBlue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.4))
            )
    }
}

// MARK: - Quote Callout

private struct QuoteCalloutView: View {
    let text: String
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                .frame(width: 3)

            Text(text)
                .font(.system(size: 16, weight: .regular))
                .italic()
                .lineSpacing(7)
                .foregroundColor(colorScheme == .dark ? Color(hex: "#94a3b8") : Color(hex: "#475569"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.ucdBlue.opacity(0.12) : Color.ucdBlue.opacity(0.05))
        )
    }
}

// MARK: - Loading Skeleton

struct ArticleDetailLoadingView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image placeholder
            Rectangle()
                .fill(Color.ucdBlue.opacity(0.15))
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                skeletonBar(width: 70, height: 11)
                skeletonBar(width: .infinity, height: 22)
                skeletonBar(width: 220, height: 22)
                skeletonBar(width: 160, height: 13)

                Divider().padding(.vertical, 4)

                ForEach(0..<7, id: \.self) { i in
                    skeletonBar(width: i % 3 == 2 ? 260 : .infinity, height: 14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Spacer()
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }

    private func skeletonBar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#e2e8f0"))
            .frame(maxWidth: width == .infinity ? .infinity : width, minHeight: height, maxHeight: height)
    }
}

// MARK: - Error State

private struct ArticleErrorView: View {
    let message: String
    let colorScheme: ColorScheme
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 44))
                .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)

            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: onRetry) {
                Text("Try Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }
}
