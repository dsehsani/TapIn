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
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.ucdBlue.opacity(0.3), Color.ucdBlue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(16/10, contentMode: .fill)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.5))
                        )

                    // Featured Badge
                    if article.isFeatured {
                        Text("FEATURED")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.5)
                            .foregroundColor(Color.ucdBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.ucdGold)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
                        .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
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
