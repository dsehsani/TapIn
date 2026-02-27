//
//  DailyBriefingCard.swift
//  TapInApp
//
//  MARK: - Daily AI Briefing Card
//  Instagram story-style swipeable cards for today's personalized briefing.
//  Each card shows an article/event image with text overlay. Tap to read.
//
//  Collapsed: Sparkle icon + hero title with animated glow border.
//  Expanded: Horizontal swipeable story cards with page dots.
//

import SwiftUI

struct DailyBriefingCard: View {
    @Environment(\.colorScheme) var colorScheme

    // Data
    let briefing: DailyBriefing?
    let isLoading: Bool
    let hasError: Bool
    var onBulletTap: ((String) -> Void)? = nil
    var onItemTap: ((BriefingItem) -> Void)? = nil

    // Expand/Collapse
    @State private var isExpanded: Bool = false

    // Story card navigation
    @State private var currentIndex: Int = 0

    // Animation state
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
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header Row (always visible, tappable)
            headerRow
                .contentShape(Rectangle())
                .onTapGesture {
                    guard briefing != nil else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }

            // MARK: - Expanded Content
            if isExpanded {
                expandedContent
                    .transition(.opacity)
            }
        }
        .padding(16)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.15
            }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 12) {
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
                Text(briefing?.heroTitle ?? "What's Happening Today")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                    .lineLimit(2)

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
                            Text("Tap to see what's new")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

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
            VStack(spacing: 12) {
                Rectangle()
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.08))
                    .frame(height: 1)
                    .padding(.top, 8)

                // Story cards or fallback to text bullets
                if let items = briefing.items, !items.isEmpty {
                    storyCardsSection(items: items)
                } else if !briefing.bulletPoints.isEmpty {
                    // Fallback for cached briefings without items
                    bulletsFallback(bullets: briefing.bulletPoints)
                }

                // Footer
                HStack(spacing: 6) {
                    AIBadgePill()
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Story Cards (tap left/right navigation)

    private func storyCardsSection(items: [BriefingItem]) -> some View {
        VStack(spacing: 8) {
            ZStack {
                // Current card
                storyCard(item: items[currentIndex])
                    .id(currentIndex)

                // Tap zones: left third = back, right third = forward, center = open
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Left tap zone — go back
                        Color.clear
                            .frame(width: geo.size.width * 0.3)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentIndex = max(0, currentIndex - 1)
                                }
                            }

                        // Center tap zone — open article/event
                        Color.clear
                            .frame(width: geo.size.width * 0.4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onItemTap?(items[currentIndex])
                            }

                        // Right tap zone — go forward
                        Color.clear
                            .frame(width: geo.size.width * 0.3)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentIndex = min(items.count - 1, currentIndex + 1)
                                }
                            }
                    }
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Instagram-style progress bars
            if items.count > 1 {
                HStack(spacing: 4) {
                    ForEach(0..<items.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentIndex
                                ? Color.white.opacity(0.9)
                                : Color.white.opacity(0.3))
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .onChange(of: briefing?.items?.count) { _, _ in
            currentIndex = 0
        }
    }

    private func storyCard(item: BriefingItem) -> some View {
        ZStack(alignment: .leading) {
            // Background image or gradient fallback
            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                    default:
                        storyCardGradient(item: item)
                    }
                }
            } else {
                storyCardGradient(item: item)
            }

            // Dark gradient overlay for text readability
            LinearGradient(
                colors: [.black.opacity(0.3), .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Single layout: badge top-left, title bottom-left
            VStack(alignment: .leading, spacing: 0) {
                // Type badge
                Text(item.type == "event" ? "EVENT" : "ARTICLE")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial.opacity(0.6), in: Capsule())

                Spacer()

                // Subtitle (main headline)
                Text(item.subtitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 2)

                // Source title
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func storyCardGradient(item: BriefingItem) -> some View {
        let colors: [Color] = item.type == "event"
            ? [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")]
            : [Color(hex: "#0f172a"), Color(hex: "#1e3a5f")]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Bullets Fallback (for cached data without items)

    private func bulletsFallback(bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(bullets, id: \.self) { bullet in
                Button {
                    onBulletTap?(bullet)
                } label: {
                    HStack(spacing: 8) {
                        Text(bullet)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(colorScheme == .dark
                                ? .white.opacity(0.85)
                                : Color(hex: "#334155"))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark
                                ? Color.white.opacity(0.05)
                                : Color.black.opacity(0.03))
                    )
                }
                .buttonStyle(BriefingButtonStyle())
            }
        }
    }
}

private struct BriefingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        DailyBriefingCard(
            briefing: DailyBriefing(
                summary: "",
                bulletPoints: [],
                articleCount: 20,
                generatedAt: "2026-02-27T12:00:00Z",
                heroTitle: "Free Food at Late Night Cafe!",
                items: [
                    BriefingItem(type: "event", title: "Late Night Study Cafe", subtitle: "Free snacks & coffee tonight", emoji: "☕", imageURL: nil, linkURL: nil),
                    BriefingItem(type: "article", title: "Men's Basketball vs UCSB", subtitle: "Aggies crush UCSB 85-75", emoji: "🏀", imageURL: nil, linkURL: nil),
                    BriefingItem(type: "event", title: "Fashion & Design Market", subtitle: "Student market at MU Feb 22", emoji: "👗", imageURL: nil, linkURL: nil),
                ]
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
