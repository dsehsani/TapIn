//
//  FeaturedArticleCard.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct FeaturedArticleCard: View {
    let article: NewsArticle
    var onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image Section
                ZStack(alignment: .topLeading) {
                    if let url = URL(string: article.imageURL), !article.imageURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(16/10, contentMode: .fill)
                            case .failure(_):
                                categoryPlaceholder
                            case .empty:
                                categoryPlaceholder
                                    .overlay(ProgressView())
                            @unknown default:
                                categoryPlaceholder
                            }
                        }
                        .aspectRatio(16/10, contentMode: .fill)
                    } else {
                        categoryPlaceholder
                    }

                    // Featured Badge
                    if article.isFeatured {
                        Text("FEATURED")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.5)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.accentCoral)
                            .clipShape(Capsule())
                            .shadow(color: Color.accentCoral.opacity(0.3), radius: 4, x: 0, y: 2)
                            .padding(16)
                    }
                }
                .clipped()

                // Content Section
                VStack(alignment: .leading, spacing: 12) {
                    // Category and Timestamp
                    HStack(spacing: 8) {
                        Text(article.category.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)

                        Text("•")
                            .foregroundColor(.textSecondary)

                        Text(article.timestamp.timeAgoDisplay())
                            .font(.system(size: 12))
                            .foregroundColor(.textMuted)
                    }

                    // Title
                    Text(article.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    // Excerpt
                    Text(article.excerpt)
                        .font(.system(size: 14))
                        .foregroundColor(colorScheme == .dark ? Color(hex: "#94a3b8") : Color(hex: "#475569"))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    // Footer
                    HStack {
                        if let author = article.author {
                            Text("By \(author)")
                                .font(.system(size: 12))
                                .italic()
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("Read More")
                                .font(.system(size: 14, weight: .bold))

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .overlay(
                    Rectangle()
                        .fill(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f8fafc"))
                        .frame(height: 1),
                    alignment: .top
                )
            }
            .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
    }

    private var categoryPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.navyDeep.opacity(0.6), Color.accentPurple.opacity(0.3)]
                        : [Color.accentOrange.opacity(0.3), Color.accentCoral.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(16/10, contentMode: .fill)
            .overlay(
                Image(systemName: article.categoryIcon)
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
}

// Date Extension for Time Ago
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    ScrollView {
        FeaturedArticleCard(
            article: NewsArticle.sampleData[0],
            onTap: {}
        )
    }
    .background(Color.backgroundLight)
}
