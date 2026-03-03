//
//  ForYouEventCard.swift
//  TapInApp
//
//  Created by Claude on 3/2/26.
//
//  Tall vertical card for horizontal scroll carousels in the "For You" feed.
//

import SwiftUI

struct ForYouEventCard: View {
    let event: CampusEvent
    @ObservedObject var savedViewModel: SavedViewModel
    var onTap: () -> Void = {}

    @Environment(\.colorScheme) var colorScheme

    private var urgencyGradient: [Color] {
        switch event.dateUrgency {
        case .today:
            return [Color.red.opacity(0.85), Color.red.opacity(0.6)]
        case .tomorrow:
            return [Color.orange.opacity(0.85), Color.orange.opacity(0.6)]
        case .thisWeek:
            return [Color.indigo.opacity(0.85), Color.indigo.opacity(0.6)]
        case .later:
            return [Color(hex: "#64748b").opacity(0.85), Color(hex: "#64748b").opacity(0.6)]
        }
    }

    private var urgencyLabel: String? {
        switch event.dateUrgency {
        case .today: return "TODAY"
        case .tomorrow: return "TOMORROW"
        case .thisWeek: return nil
        case .later: return nil
        }
    }

    /// Big themed emoji based on event keywords
    private var eventEmoji: String {
        let text = [
            event.title,
            event.eventType ?? "",
            event.organizerName ?? "",
            event.tags.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        if text.contains("sport") || text.contains("athletic") || text.contains("basketball") || text.contains("football") || text.contains("soccer") { return "🏆" }
        if text.contains("music") || text.contains("concert") || text.contains("band") { return "🎵" }
        if text.contains("art") || text.contains("exhibit") || text.contains("gallery") || text.contains("painting") { return "🎨" }
        if text.contains("dance") || text.contains("ballet") { return "💃" }
        if text.contains("theater") || text.contains("theatre") || text.contains("drama") || text.contains("comedy") { return "🎭" }
        if text.contains("film") || text.contains("movie") || text.contains("screen") { return "🎬" }
        if text.contains("food") || text.contains("dining") || text.contains("cook") || text.contains("potluck") || text.contains("taco") { return "🍽️" }
        if text.contains("coffee") || text.contains("cafe") || text.contains("tea") { return "☕" }
        if text.contains("lecture") || text.contains("seminar") || text.contains("talk") || text.contains("panel") { return "🎤" }
        if text.contains("workshop") || text.contains("hack") || text.contains("coding") || text.contains("tech") { return "💻" }
        if text.contains("science") || text.contains("research") || text.contains("lab") { return "🔬" }
        if text.contains("yoga") || text.contains("meditation") || text.contains("wellness") || text.contains("health") { return "🧘" }
        if text.contains("volunteer") || text.contains("community") || text.contains("service") { return "🤝" }
        if text.contains("career") || text.contains("job") || text.contains("intern") || text.contains("recruit") { return "💼" }
        if text.contains("club") || text.contains("meeting") || text.contains("org") { return "👥" }
        if text.contains("party") || text.contains("social") || text.contains("mixer") { return "🎉" }
        if text.contains("study") || text.contains("tutor") || text.contains("exam") { return "📚" }
        if text.contains("outdoor") || text.contains("hike") || text.contains("nature") || text.contains("garden") { return "🌿" }
        if text.contains("game") || text.contains("trivia") || text.contains("board") { return "🎲" }
        return "📅"
    }

    /// Small accent emojis scattered in the background
    private var accentEmojis: [String] {
        let text = [event.title, event.eventType ?? "", event.tags.joined(separator: " ")].joined(separator: " ").lowercased()

        if text.contains("sport") || text.contains("athletic") { return ["⚡", "🔥", "💪"] }
        if text.contains("music") || text.contains("concert") { return ["🎶", "✨", "🎧"] }
        if text.contains("art") || text.contains("exhibit") { return ["✨", "🖌️", "💫"] }
        if text.contains("food") || text.contains("dining") || text.contains("cook") { return ["🔥", "✨", "😋"] }
        if text.contains("tech") || text.contains("hack") || text.contains("coding") { return ["⚡", "🚀", "✨"] }
        if text.contains("party") || text.contains("social") || text.contains("mixer") { return ["✨", "💫", "🎊"] }
        if text.contains("career") || text.contains("job") { return ["🌟", "📈", "✨"] }
        return ["✨", "💫", "⭐"]
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Top half: gradient with emoji
                ZStack {
                    LinearGradient(
                        colors: urgencyGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Scattered accent emojis
                    let accents = accentEmojis
                    Text(accents[0])
                        .font(.system(size: 16))
                        .opacity(0.4)
                        .offset(x: -55, y: -30)

                    Text(accents[1])
                        .font(.system(size: 14))
                        .opacity(0.35)
                        .offset(x: 50, y: -38)

                    if accents.count > 2 {
                        Text(accents[2])
                            .font(.system(size: 12))
                            .opacity(0.3)
                            .offset(x: -40, y: 32)
                    }

                    // Big center emoji
                    Text(eventEmoji)
                        .font(.system(size: 44))
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                    // Urgency badge
                    if let label = urgencyLabel {
                        VStack {
                            HStack {
                                Text(label)
                                    .font(.system(size: 9, weight: .heavy))
                                    .tracking(0.5)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(.black.opacity(0.35))
                                    )
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(10)
                    }
                }
                .frame(height: 120)
                .clipped()

                // Bottom half: event details
                VStack(alignment: .leading, spacing: 6) {
                    // Organizer
                    if let organizer = event.organizerName, !organizer.isEmpty {
                        Text(organizer.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.4)
                            .foregroundColor(Color.ucdGold)
                            .lineLimit(1)
                    }

                    // Title
                    Text(event.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    // Date + time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(event.friendlyDateLabel)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                    // Location + Save
                    HStack(alignment: .bottom) {
                        if !event.location.isEmpty && event.location != "TBD" {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 10))
                                Text(event.location)
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        }

                        Spacer()

                        // Save Toggle
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                savedViewModel.toggleEventSaved(event)
                            }
                        }) {
                            Image(systemName: savedViewModel.isEventSaved(event) ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(savedViewModel.isEventSaved(event) ? (colorScheme == .dark ? Color.ucdGold : Color.ucdBlue) : .secondary)
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .medium), trigger: savedViewModel.isEventSaved(event))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 180, height: 260)
            .background(colorScheme == .dark ? Color(hex: "#1e293b") : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(colorScheme == .dark ? Color(hex: "#334155") : Color(hex: "#e2e8f0"), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
