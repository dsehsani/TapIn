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
    var onDismiss: () -> Void = {}

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

    /// SF Symbol icon based on event keywords
    private var eventIcon: String {
        let text = [
            event.title,
            event.eventType ?? "",
            event.organizerName ?? "",
            event.tags.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        if text.contains("sport") || text.contains("athletic") || text.contains("basketball") || text.contains("football") || text.contains("soccer") { return "sportscourt.fill" }
        if text.contains("music") || text.contains("concert") || text.contains("band") { return "music.note.list" }
        if text.contains("art") || text.contains("exhibit") || text.contains("gallery") || text.contains("painting") { return "paintpalette.fill" }
        if text.contains("dance") || text.contains("ballet") { return "figure.dance" }
        if text.contains("theater") || text.contains("theatre") || text.contains("drama") || text.contains("comedy") { return "theatermasks.fill" }
        if text.contains("film") || text.contains("movie") || text.contains("screen") { return "film.fill" }
        if text.contains("food") || text.contains("dining") || text.contains("cook") || text.contains("potluck") || text.contains("taco") { return "fork.knife" }
        if text.contains("coffee") || text.contains("cafe") || text.contains("tea") { return "cup.and.saucer.fill" }
        if text.contains("lecture") || text.contains("seminar") || text.contains("talk") || text.contains("panel") { return "mic.fill" }
        if text.contains("workshop") || text.contains("hack") || text.contains("coding") || text.contains("tech") { return "laptopcomputer" }
        if text.contains("science") || text.contains("research") || text.contains("lab") { return "atom" }
        if text.contains("yoga") || text.contains("meditation") || text.contains("wellness") || text.contains("health") { return "heart.fill" }
        if text.contains("volunteer") || text.contains("community") || text.contains("service") { return "hands.sparkles.fill" }
        if text.contains("career") || text.contains("job") || text.contains("intern") || text.contains("recruit") { return "briefcase.fill" }
        if text.contains("club") || text.contains("meeting") || text.contains("org") { return "person.3.fill" }
        if text.contains("party") || text.contains("social") || text.contains("mixer") { return "party.popper.fill" }
        if text.contains("study") || text.contains("tutor") || text.contains("exam") { return "book.fill" }
        if text.contains("outdoor") || text.contains("hike") || text.contains("nature") || text.contains("garden") { return "leaf.fill" }
        if text.contains("game") || text.contains("trivia") || text.contains("board") { return "gamecontroller.fill" }
        return "calendar"
    }

    /// Formatted time string like "5:00 PM"
    private var eventTimeString: String {
        event.date.formatted(date: .omitted, time: .shortened)
    }

    /// True only when location has real, useful data
    private var hasRealLocation: Bool {
        let loc = event.location
        return !loc.isEmpty && loc != "TBD" && loc != "N/A"
    }

    /// Extracts just the building/hall + room from a full address.
    /// e.g. "123 Shields Library, Room 360, Davis, CA" → "Shields Library, Rm 360"
    /// e.g. "Hunt Hall Room 100, Shields Ave, Davis, CA" → "Hunt Hall Rm 100"
    private var shortenedLocation: String {
        let loc = event.location

        // Split by comma and keep relevant parts (building, room)
        let parts = loc.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        var result: [String] = []
        for part in parts {
            let lower = part.lowercased()
            // Skip city, state, zip, country
            if lower.contains("davis") || lower.contains(", ca") || lower.contains("california") { continue }
            if lower.count <= 3 && lower.allSatisfy(\.isUppercase) { continue } // "CA"
            // Strip leading street number (e.g. "123 Shields Library" → "Shields Library")
            let cleaned = part.replacingOccurrences(of: "^\\d+\\s+", with: "", options: .regularExpression)
            if cleaned.isEmpty { continue }

            if result.isEmpty {
                // Always keep the first relevant part (building name)
                result.append(cleaned)
            } else if lower.contains("room") || lower.contains("rm") || lower.contains("suite") || lower.contains("ste") {
                // Only keep a 2nd part if it's a room/suite number
                result.append(cleaned)
                break
            } else {
                break
            }
        }

        // Shorten "Room" → "Rm" to save space
        let joined = result.isEmpty ? loc : result.joined(separator: ", ")
        return joined.replacingOccurrences(of: "Room ", with: "Rm ")
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

                    // Center icon
                    Image(systemName: eventIcon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                    // Top row: date pill (left) + dismiss (right)
                    VStack {
                        HStack {
                            Text(event.friendlyDateLabel)
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.3)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(.black.opacity(0.35)))
                                .lineLimit(1)

                            Spacer()

                            Button(action: onDismiss) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(.black.opacity(0.35), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(8)

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

                    // Location — only if real data, above time
                    if hasRealLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 11))
                            Text(shortenedLocation)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                        .lineLimit(1)
                    }

                    // Time
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(eventTimeString)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                    .lineLimit(1)

                    // Save row
                    HStack {
                        Spacer()
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
