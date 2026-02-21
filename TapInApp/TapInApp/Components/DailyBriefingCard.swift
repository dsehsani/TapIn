//
//  DailyBriefingCard.swift
//  TapInApp
//
//  MARK: - Daily AI Briefing Card
//  Displays an AI-generated summary of today's news from The Aggie.
//  Collapsed: Sparkle icon + title with animated Gemini-style glow border.
//  Expanded: Full summary + emoji bullet points with spring animation.
//
//  Glow pattern from AISummaryBadge.swift:
//  - AngularGradient border with continuous 6s rotation
//  - Breathing glow pulse behind the card (2.5s cycle)
//

import SwiftUI

struct DailyBriefingCard: View {
    @Environment(\.colorScheme) var colorScheme

    // Data
    let briefing: DailyBriefing?
    let isLoading: Bool
    let hasError: Bool

    // Expand/Collapse
    @State private var isExpanded: Bool = false

    // Animation state (matches AISummaryBadge)
    @State private var rotation: Double = 0
    @State private var glowOpacity: Double = 0.4

    // Same gradient colors as AISummaryBadge (Blue → Purple → Gold → Pink)
    private let gradientColors: [Color] = [
        Color(hex: "#3b82f6"),   // Blue
        Color(hex: "#8b5cf6"),   // Purple
        Color(hex: "#FFBF00"),   // UC Davis Gold
        Color(hex: "#ec4899"),   // Pink
        Color(hex: "#3b82f6")    // Blue (loop)
    ]

    var body: some View {
        Button(action: {
            guard briefing != nil else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Header Row (always visible)
                headerRow

                // MARK: - Expanded Content
                if isExpanded {
                    expandedContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark
                        ? Color(hex: "#1a1a2e").opacity(0.9)
                        : Color(hex: "#faf5ff").opacity(0.95))
            )
            // Rotating gradient border
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        AngularGradient(
                            colors: gradientColors,
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: 1.5
                    )
            )
            // Breathing glow behind card
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        AngularGradient(
                            colors: gradientColors,
                            center: .center,
                            angle: .degrees(rotation + 90)
                        )
                    )
                    .blur(radius: 12)
                    .opacity(glowOpacity)
                    .scaleEffect(1.03)
            )
            .shadow(color: Color(hex: "#8b5cf6").opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .onAppear {
            // Continuous rotation (same timing as AISummaryBadge)
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            // Breathing glow pulse
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.15
            }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 12) {
            // Sparkle icon with gradient
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#8b5cf6"), Color(hex: "#FFBF00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("What's Happening Today")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

                if !isExpanded {
                    Group {
                        if isLoading {
                            Text("Getting your summary...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        } else if hasError || briefing == nil {
                            Text("Check back soon")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Your daily campus catch-up")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Loading spinner or chevron
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else if briefing != nil {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        if let briefing = briefing {
            VStack(alignment: .leading, spacing: 12) {
                // Divider
                Rectangle()
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.08))
                    .frame(height: 1)
                    .padding(.top, 12)

                // Summary paragraph
                Text(briefing.summary)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(colorScheme == .dark
                        ? .white.opacity(0.9)
                        : Color(hex: "#1e293b"))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // Bullet points
                if !briefing.bulletPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(briefing.bulletPoints, id: \.self) { bullet in
                            Text(bullet)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(colorScheme == .dark
                                    ? .white.opacity(0.85)
                                    : Color(hex: "#334155"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // Footer — AI badge
                HStack(spacing: 6) {
                    AIBadgePill()
                    Text("\(briefing.articleCount) articles from The Aggie")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 6)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DailyBriefingCard(
            briefing: DailyBriefing(
                summary: "Big day on campus! UC Davis researchers announce a solar energy breakthrough while ASUCD prepares for spring elections.",
                bulletPoints: [
                    "☀️ New solar panel design boosts efficiency by 20%",
                    "🗳️ ASUCD spring election candidates announced",
                    "🏀 Aggies advance to conference semifinals",
                    "🎭 Mondavi Center hosts Grammy-winning jazz ensemble"
                ],
                articleCount: 10,
                generatedAt: "2026-02-20T12:00:00Z"
            ),
            isLoading: false,
            hasError: false
        )

        DailyBriefingCard(
            briefing: nil,
            isLoading: true,
            hasError: false
        )
    }
    .padding(.vertical, 20)
    .background(Color.backgroundLight)
}
