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
    @StateObject private var viewModel = ArticleDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                ArticleDetailLoadingView()
            case .loaded(let content):
                ArticleReadingView(content: content, colorScheme: colorScheme, onDismiss: { dismiss() })
            case .failed(let message):
                ArticleErrorView(message: message, colorScheme: colorScheme, onRetry: {
                    Task { await viewModel.load(article: article) }
                })
            }
        }
        .task {
            await viewModel.load(article: article)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Reading View

private struct ArticleReadingView: View {
    let content: ArticleContent
    let colorScheme: ColorScheme
    let onDismiss: () -> Void

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
                            } else {
                                Text(paragraph)
                                    .font(.system(size: 16))
                                    .lineSpacing(7)
                                    .foregroundColor(colorScheme == .dark ? Color(hex: "#cbd5e1") : Color(hex: "#1e293b"))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

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

                ShareLink(item: content.articleURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 52)
        }
    }

    // Returns true if the paragraph looks like a direct quote
    private func isQuote(_ text: String) -> Bool {
        let quoteStarters: [Character] = ["\"", "\u{201C}", "\u{2018}"] // ", ", '
        return quoteStarters.contains(where: { text.hasPrefix(String($0)) })
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
