//
//  EventDetailView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 2/10/26.
//

import SwiftUI
import MapKit

struct EventDetailView: View {
    let event: CampusEvent
    @ObservedObject var savedViewModel: SavedViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    // Bullets come directly from the model — no async loading needed
    private var bulletPoints: [String] { event.aiBulletPoints }
    @State private var showAISummary: Bool = true
    @State private var locationCoordinate: CLLocationCoordinate2D?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Badge & Event Type
                    HStack(spacing: 8) {
                        Text(event.isOfficial ? "OFFICIAL" : "CLUB EVENT")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(event.isOfficial ? Color.ucdBlue : Color.ucdGold)
                            .clipShape(Capsule())

                        if let eventType = event.eventType {
                            Text(eventType)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9")
                                )
                                .clipShape(Capsule())
                        }
                    }

                    // MARK: - Title
                    Text(event.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

                    // MARK: - Organizer
                    if let organizer = event.organizerName {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.ucdBlue)
                            Text("Hosted by \(organizer)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#334155"))
                        }
                    }

                    Divider()

                    // MARK: - Date & Time
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(
                            icon: "calendar",
                            title: "Date",
                            value: event.date.formatted(date: .long, time: .omitted),
                            colorScheme: colorScheme
                        )

                        DetailRow(
                            icon: "clock.fill",
                            title: "Time",
                            value: formatTimeRange(),
                            colorScheme: colorScheme
                        )

                        if event.location != "N/A" {
                            DetailRow(
                                icon: "mappin.circle.fill",
                                title: "Location",
                                value: event.location,
                                colorScheme: colorScheme
                            )

                            // Tappable map preview
                            if let coordinate = locationCoordinate {
                                Map(initialPosition: .region(MKCoordinateRegion(
                                    center: coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                ))) {
                                    Marker(event.location, coordinate: coordinate)
                                        .tint(.red)
                                }
                                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .allowsHitTesting(false)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.clear)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            openInMaps(location: event.location)
                                        }
                                )
                            }
                        } else {
                            DetailRow(
                                icon: "mappin.circle.fill",
                                title: "Location",
                                value: "N/A",
                                colorScheme: colorScheme
                            )
                        }
                    }

                    Divider()

                    // MARK: - About (AI Bullet Points / Raw Description)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("About")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                            if !bulletPoints.isEmpty {
                                AIBadgePill(isActive: showAISummary)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            showAISummary.toggle()
                                        }
                                    }
                            }
                        }

                        if !bulletPoints.isEmpty && showAISummary {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(bulletPoints, id: \.self) { bullet in
                                        LinkedText(bullet)
                                            .font(.system(size: 15))
                                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : Color(hex: "#334155"))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                // Extracted links shown as prominent labeled buttons
                                let links = extractLinks(from: bulletPoints + [event.description])
                                if !links.isEmpty {
                                    VStack(spacing: 8) {
                                        ForEach(links, id: \.url.absoluteString) { link in
                                            Link(destination: link.url) {
                                                HStack(spacing: 10) {
                                                    Image(systemName: link.icon)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .frame(width: 20)
                                                    Text(link.label)
                                                        .font(.system(size: 14, weight: .semibold))
                                                    Spacer()
                                                    Image(systemName: "arrow.up.right")
                                                        .font(.system(size: 12, weight: .semibold))
                                                }
                                                .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 12)
                                                .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color.ucdBlue.opacity(0.08))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                        }
                                    }
                                }
                            }
                            .transition(.opacity)
                        } else {
                            LinkedText(event.description)
                                .font(.system(size: 15))
                                .foregroundColor(.textMuted)
                                .lineSpacing(4)
                                .transition(.opacity)
                        }
                    }

                    // MARK: - Tags
                    if !event.tags.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tags")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

                            FlowLayout(spacing: 8) {
                                ForEach(event.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#334155"))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9")
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // MARK: - Save Event Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            savedViewModel.toggleEventSaved(event)
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: savedViewModel.isEventSaved(event) ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 18, weight: .semibold))
                            Text(savedViewModel.isEventSaved(event) ? "Saved" : "Save Event")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(savedViewModel.isEventSaved(event) ? .white : (colorScheme == .dark ? .white : Color(hex: "#0f172a")))
                        .padding(.vertical, 14)
                        .background(savedViewModel.isEventSaved(event) ? Color(hex: "#10b981") : (colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9")))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(savedViewModel.isEventSaved(event) ? Color.clear : Color(hex: "#e2e8f0"), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .medium), trigger: savedViewModel.isEventSaved(event))
                    .padding(.top, 8)

                    // MARK: - RSVP Button
                    if let urlString = event.eventURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack {
                                Spacer()
                                Text("View on Aggie Life")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .background(Color.ucdBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Color.adaptiveBackground(colorScheme))
            .task { await geocodeLocation() }

            // Floating nav buttons (matches ArticleDetailView pattern)
            floatingButtons
        }
    }

    // MARK: - Floating Buttons

    private var floatingButtons: some View {
        HStack(spacing: 12) {
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .floatingButtonBackground()
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .floatingButtonBackground()
            }
        }
        .padding(.trailing, 20)
        .padding(.top, 16)
    }

    // MARK: - Share

    private var shareText: String {
        var text = "\(event.title)\n"
        text += "\(event.friendlyDateLabel) at \(event.date.formatted(date: .omitted, time: .shortened))"
        if !event.location.isEmpty && event.location != "N/A" {
            text += "\n\(event.location)"
        }
        if let urlString = event.eventURL {
            text += "\n\(urlString)"
        }
        return text
    }

    // MARK: - Helpers

    /// Geocodes the event location to get a coordinate for the map preview.
    private func geocodeLocation() async {
        let location = event.location
        guard location != "N/A" && !location.isEmpty else { return }

        let query = mapsQuery(for: location)

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            // Bias search toward UC Davis area
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 38.5382, longitude: -121.7617),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            if let mapItem = response.mapItems.first {
                let coordinate = mapItem.placemark.coordinate
                withAnimation(.easeIn(duration: 0.3)) {
                    locationCoordinate = coordinate
                }
            }
        } catch {
            // Search failed — just don't show the map
        }
    }

    /// Builds a maps search query, appending UC Davis context for known campus buildings.
    private func mapsQuery(for location: String) -> String {
        let knownCampusBuildings = [
            "memorial union", "arc pavilion", "arc",
            "shields library", "wellman hall", "hutchison hall",
            "olson hall", "mondavi center", "freeborn hall",
            "young hall", "kemper hall", "cruess hall",
            "sciences lecture hall", "giedt hall", "haring hall",
            "hunt hall", "walker hall", "rock hall",
            "student community center", "coho", "coffee house",
            "the silo", "the quad",
            "activities and recreation center",
            "international center", "genome center",
            "conference center", "alumni center",
            "putah creek lodge", "walter a. buehler",
            "surge", "everson hall", "hart hall",
            "plant and environmental sciences",
            "social sciences", "sprocket",
        ]

        let locationLower = location.lowercased()
        let isKnownCampus = knownCampusBuildings.contains { locationLower.contains($0) }

        if isKnownCampus {
            return "\(location), UC Davis, Davis, CA"
        } else if !locationLower.contains("davis") && !locationLower.contains("sacramento") {
            return "\(location), Davis, CA"
        }
        return location
    }

    /// Opens the location in the user's default maps app.
    private func openInMaps(location: String) {
        let query = mapsQuery(for: location)
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "maps://?q=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }

    private func formatTimeRange() -> String {
        let startTime = event.date.formatted(date: .omitted, time: .shortened)
        if let endDate = event.endDate {
            let endTime = endDate.formatted(date: .omitted, time: .shortened)
            return "\(startTime) – \(endTime)"
        }
        return startTime
    }

    /// Extracts unique URLs from an array of strings with descriptive labels.
    private func extractLinks(from texts: [String]) -> [(url: URL, label: String, icon: String)] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        var seen = Set<String>()
        var results: [(url: URL, label: String, icon: String)] = []

        for text in texts {
            let nsString = text as NSString
            let range = NSRange(location: 0, length: nsString.length)
            for match in detector.matches(in: text, range: range) {
                guard let url = match.url, seen.insert(url.absoluteString).inserted else { continue }
                let (label, icon) = linkLabel(for: url, context: text, matchRange: match.range)
                results.append((url: url, label: label, icon: icon))
            }
        }

        return results
    }

    /// Generates a human-readable label for a URL based on surrounding text and URL patterns.
    private func linkLabel(for url: URL, context: String, matchRange: NSRange) -> (String, String) {
        // 0. Email addresses → open mail app
        if url.scheme == "mailto" {
            let email = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            return ("Email \(email)", "envelope.fill")
        }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        let contextLower = context.lowercased()

        // 1. Try to infer from surrounding context keywords
        let contextKeywords: [(keywords: [String], label: String, icon: String)] = [
            (["apply", "application"], "Application Form", "doc.text.fill"),
            (["register", "registration", "sign up", "sign-up", "signup"], "Registration", "person.crop.circle.badge.plus"),
            (["rsvp"], "RSVP", "envelope.open.fill"),
            (["ticket", "tickets", "admission"], "Get Tickets", "ticket.fill"),
            (["donate", "donation", "fundrais"], "Donate", "heart.fill"),
            (["survey", "feedback", "questionnaire"], "Survey", "list.clipboard.fill"),
            (["schedule", "agenda", "itinerary"], "Schedule", "calendar"),
            (["map", "direction", "parking"], "Directions", "map.fill"),
            (["menu", "food", "catering"], "Menu", "fork.knife"),
            (["flyer", "poster", "info"], "Event Info", "info.circle.fill"),
            (["discord"], "Discord Server", "bubble.left.and.bubble.right.fill"),
            (["slack"], "Slack Channel", "bubble.left.and.bubble.right.fill"),
            (["instagram", "ig"], "Instagram", "camera.fill"),
            (["linkedin"], "LinkedIn", "person.fill"),
        ]

        for entry in contextKeywords {
            if entry.keywords.contains(where: { contextLower.contains($0) }) {
                return (entry.label, entry.icon)
            }
        }

        // 2. Infer from URL host / path patterns
        let urlPatterns: [(pattern: (String, String) -> Bool, label: String, icon: String)] = [
            ({ h, p in h.contains("forms.google") || (h.contains("docs.google.com") && p.contains("/forms")) }, "Google Form", "doc.text.fill"),
            ({ h, p in h.contains("docs.google") && !p.contains("/forms") }, "Google Doc", "doc.fill"),
            ({ h, p in h.contains("drive.google") }, "Google Drive", "folder.fill"),
            ({ h, p in p.contains("form") || p.contains("apply") || p.contains("application") }, "Application Form", "doc.text.fill"),
            ({ h, p in h.contains("eventbrite") }, "Get Tickets", "ticket.fill"),
            ({ h, p in h.contains("zoom.us") || h.contains("zoom.com") }, "Zoom Meeting", "video.fill"),
            ({ h, p in h.contains("teams.microsoft") }, "Teams Meeting", "video.fill"),
            ({ h, p in h.contains("discord.gg") || h.contains("discord.com") }, "Discord Server", "bubble.left.and.bubble.right.fill"),
            ({ h, p in h.contains("instagram.com") }, "Instagram", "camera.fill"),
            ({ h, p in h.contains("linkedin.com") }, "LinkedIn", "person.fill"),
            ({ h, p in h.contains("twitter.com") || h.contains("x.com") }, "Twitter / X", "at"),
            ({ h, p in h.contains("youtube.com") || h.contains("youtu.be") }, "YouTube Video", "play.rectangle.fill"),
            ({ h, p in h.contains("canva.com") }, "Flyer", "photo.fill"),
            ({ h, p in h.contains("linktr.ee") || h.contains("linktree") }, "Linktree", "link"),
            ({ h, p in h.contains("calendly.com") }, "Book a Time", "calendar.badge.clock"),
            ({ h, p in h.contains("gofundme.com") || h.contains("venmo.com") }, "Donate", "heart.fill"),
            ({ h, p in p.contains("register") || p.contains("signup") || p.contains("sign-up") }, "Registration", "person.crop.circle.badge.plus"),
            ({ h, p in p.contains("ticket") }, "Get Tickets", "ticket.fill"),
            ({ h, p in p.contains("survey") || p.contains("feedback") }, "Survey", "list.clipboard.fill"),
        ]

        for entry in urlPatterns {
            if entry.pattern(host, path) {
                return (entry.label, entry.icon)
            }
        }

        // 3. Fallback: use a cleaned-up host name
        let cleanHost = host
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: ".com", with: "")
            .replacingOccurrences(of: ".org", with: "")
            .replacingOccurrences(of: ".edu", with: "")
            .capitalized
        return (cleanHost.isEmpty ? "Open Link" : cleanHost, "link")
    }
}

// MARK: - Detail Row Component

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color.ucdBlue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
            }
        }
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

// MARK: - Linked Text (auto-detects URLs and makes them tappable)

private struct LinkedText: View {
    let rawText: String

    init(_ text: String) {
        self.rawText = text
    }

    var body: some View {
        Text(buildAttributedString())
            .tint(.blue)
    }

    private func buildAttributedString() -> AttributedString {
        var attributed = AttributedString(rawText)

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attributed
        }

        let nsString = rawText as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let matches = detector.matches(in: rawText, range: fullRange)

        // Apply in reverse order so ranges stay valid
        for match in matches.reversed() {
            guard let swiftRange = Range(match.range, in: rawText),
                  let url = match.url,
                  let attrRange = Range(swiftRange, in: attributed) else { continue }

            attributed[attrRange].link = url
            attributed[attrRange].underlineStyle = .single
        }

        return attributed
    }
}

// MARK: - Floating Button Background Modifier

private struct FloatingButtonBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .circle)
        } else {
            content.background(.thinMaterial, in: Circle())
        }
    }
}

extension View {
    func floatingButtonBackground() -> some View {
        modifier(FloatingButtonBackground())
    }
}

#Preview {
    EventDetailView(event: CampusEvent.sampleData[0], savedViewModel: SavedViewModel())
}
