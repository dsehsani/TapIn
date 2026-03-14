//
//  CampusEvent.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import Foundation

struct CampusEvent: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let description: String
    let date: Date
    let endDate: Date?
    let location: String
    let isOfficial: Bool
    let imageURL: String?
    let organizerName: String?
    let clubAcronym: String?
    let eventType: String?
    let tags: [String]
    let eventURL: String?
    let organizerURL: String?

    // Server pre-computed AI content (populated by backend pipeline)
    let aiSummary: String?
    let aiBulletPoints: [String]
    let aiLocation: String?
    let webLocation: String?         // Web-searched club meeting location (unverified)
    let webLocationSource: String?   // Where it was found, e.g. "ASUCD page", "Linktree"
    let locationConfidence: Int?             // 0-100 confidence score from backend
    let locationConfidenceReason: String?    // Human-readable reason for the score

    // MARK: - Memberwise init (for sample data & local construction)
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        date: Date,
        endDate: Date? = nil,
        location: String,
        isOfficial: Bool = true,
        imageURL: String? = nil,
        organizerName: String? = nil,
        clubAcronym: String? = nil,
        eventType: String? = nil,
        tags: [String] = [],
        eventURL: String? = nil,
        organizerURL: String? = nil,
        aiSummary: String? = nil,
        aiBulletPoints: [String] = [],
        aiLocation: String? = nil,
        webLocation: String? = nil,
        webLocationSource: String? = nil,
        locationConfidence: Int? = nil,
        locationConfidenceReason: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.date = date
        self.endDate = endDate
        self.location = location
        self.isOfficial = isOfficial
        self.imageURL = imageURL
        self.organizerName = organizerName
        self.clubAcronym = clubAcronym
        self.eventType = eventType
        self.tags = tags
        self.eventURL = eventURL
        self.organizerURL = organizerURL
        self.aiSummary = aiSummary
        self.aiBulletPoints = aiBulletPoints
        self.aiLocation = aiLocation
        self.webLocation = webLocation
        self.webLocationSource = webLocationSource
        self.locationConfidence = locationConfidence
        self.locationConfidenceReason = locationConfidenceReason
    }

    // MARK: - Codable (custom to handle server "startDate" vs local "date")

    enum CodingKeys: String, CodingKey {
        case id, title, description, location, isOfficial
        case imageURL, organizerName, clubAcronym, eventType
        case tags, eventURL, organizerURL, aiSummary, aiBulletPoints, aiLocation, webLocation, webLocationSource, locationConfidence, locationConfidenceReason
        case startDate, date, endDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title         = try c.decode(String.self, forKey: .title)
        description   = try c.decode(String.self, forKey: .description)
        // Accept "startDate" (server) or "date" (UserDefaults / legacy)
        let serverDate = try? c.decode(Date.self, forKey: .startDate)
        let localDate  = try? c.decode(Date.self, forKey: .date)
        guard let resolved = serverDate ?? localDate else {
            throw DecodingError.keyNotFound(
                CodingKeys.date,
                DecodingError.Context(codingPath: c.codingPath,
                                      debugDescription: "Missing startDate or date key")
            )
        }
        date          = resolved
        endDate       = try? c.decode(Date.self, forKey: .endDate)
        location      = (try? c.decode(String.self, forKey: .location)) ?? "TBD"
        isOfficial    = (try? c.decode(Bool.self, forKey: .isOfficial)) ?? true
        imageURL      = try? c.decode(String.self, forKey: .imageURL)
        organizerName = try? c.decode(String.self, forKey: .organizerName)
        clubAcronym   = try? c.decode(String.self, forKey: .clubAcronym)
        eventType     = try? c.decode(String.self, forKey: .eventType)
        tags          = (try? c.decode([String].self, forKey: .tags)) ?? []
        eventURL      = try? c.decode(String.self, forKey: .eventURL)
        organizerURL  = try? c.decode(String.self, forKey: .organizerURL)
        aiSummary     = try? c.decode(String.self, forKey: .aiSummary)
        aiBulletPoints = (try? c.decode([String].self, forKey: .aiBulletPoints)) ?? []
        aiLocation     = try? c.decode(String.self, forKey: .aiLocation)
        webLocation    = try? c.decode(String.self, forKey: .webLocation)
        webLocationSource = try? c.decode(String.self, forKey: .webLocationSource)
        locationConfidence = try? c.decode(Int.self, forKey: .locationConfidence)
        locationConfidenceReason = try? c.decode(String.self, forKey: .locationConfidenceReason)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,             forKey: .id)
        try c.encode(title,          forKey: .title)
        try c.encode(description,    forKey: .description)
        try c.encode(date,           forKey: .date)       // store as "date" for UserDefaults compat
        try c.encodeIfPresent(endDate,       forKey: .endDate)
        try c.encode(location,       forKey: .location)
        try c.encode(isOfficial,     forKey: .isOfficial)
        try c.encodeIfPresent(imageURL,      forKey: .imageURL)
        try c.encodeIfPresent(organizerName, forKey: .organizerName)
        try c.encodeIfPresent(clubAcronym,   forKey: .clubAcronym)
        try c.encodeIfPresent(eventType,     forKey: .eventType)
        try c.encode(tags,           forKey: .tags)
        try c.encodeIfPresent(eventURL,      forKey: .eventURL)
        try c.encodeIfPresent(organizerURL,  forKey: .organizerURL)
        try c.encodeIfPresent(aiSummary,     forKey: .aiSummary)
        try c.encode(aiBulletPoints, forKey: .aiBulletPoints)
        try c.encodeIfPresent(aiLocation, forKey: .aiLocation)
        try c.encodeIfPresent(webLocation, forKey: .webLocation)
        try c.encodeIfPresent(webLocationSource, forKey: .webLocationSource)
        try c.encodeIfPresent(locationConfidence, forKey: .locationConfidence)
        try c.encodeIfPresent(locationConfidenceReason, forKey: .locationConfidenceReason)
    }
}

import SwiftUI

// MARK: - Stable Social ID
extension CampusEvent {
    /// Deterministic ID for likes/comments — same across all devices.
    /// Uses title + date (stable from backend) instead of the random UUID.
    /// IMPORTANT: Do NOT change this format — existing Firestore data depends on it.
    var socialId: String {
        let formatter = ISO8601DateFormatter()
        let raw = "\(title)_\(formatter.string(from: date))"

        var cleaned = raw.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_"
                ? String(scalar)
                : "_"
        }.joined()

        // Collapse repeated underscores
        while cleaned.contains("__") {
            cleaned = cleaned.replacingOccurrences(of: "__", with: "_")
        }

        if cleaned.count > 200 { return String(cleaned.prefix(200)) }
        return cleaned.isEmpty ? id.uuidString : cleaned
    }
}

// MARK: - Location Confidence
enum LocationConfidenceLevel {
    case high      // ≥80
    case moderate  // 50-79
    case low       // 1-49
    case none      // 0

    var color: Color {
        switch self {
        case .high:     return .green
        case .moderate: return .orange
        case .low:      return Color(red: 0.92, green: 0.27, blue: 0.27)
        case .none:     return .gray
        }
    }

    var label: String {
        switch self {
        case .high:     return "High confidence"
        case .moderate: return "Moderate confidence"
        case .low:      return "Low confidence"
        case .none:     return "No location"
        }
    }
}

extension CampusEvent {
    /// Confidence level derived from the backend score, with a fallback heuristic
    /// for cached events that predate the confidence field.
    var confidenceLevel: LocationConfidenceLevel {
        let score: Int
        if let s = locationConfidence {
            score = s
        } else {
            // Fallback for old cached events without backend confidence
            if location != "TBD" && !location.isEmpty { score = 95 }
            else if aiLocation != nil { score = 75 }
            else if webLocation != nil { score = 40 }
            else { score = 0 }
        }

        if score >= 80 { return .high }
        if score >= 50 { return .moderate }
        if score > 0   { return .low }
        return .none
    }

    var confidenceScore: Int {
        if let s = locationConfidence { return s }
        // Fallback
        if location != "TBD" && !location.isEmpty { return 95 }
        if aiLocation != nil { return 75 }
        if webLocation != nil { return 40 }
        return 0
    }

    var confidenceReason: String {
        locationConfidenceReason ?? "No confidence data available"
    }
}

// MARK: - Display Location
extension CampusEvent {
    /// The best available location string for display.
    /// Priority: confirmed iCal → AI description scan → web search → "TBD".
    var displayLocation: String {
        if location != "TBD" && !location.isEmpty { return location }
        if let ai = aiLocation { return ai }
        if let web = webLocation { return web }
        return "TBD"
    }

    /// True when the shown location was inferred by AI from the description.
    var isLocationInferred: Bool {
        return (location == "TBD" || location.isEmpty) && aiLocation != nil
    }

    /// True when the location came from a web search — least confident source.
    var isLocationFromWeb: Bool {
        return (location == "TBD" || location.isEmpty)
            && aiLocation == nil
            && webLocation != nil
    }
}

enum EventDateUrgency {
    case today
    case tomorrow
    case thisWeek
    case later

    var badgeColor: Color {
        switch self {
        case .today:    return Color(red: 0.92, green: 0.27, blue: 0.27) // red
        case .tomorrow: return Color(red: 1.0, green: 0.58, blue: 0.0)  // orange
        case .thisWeek: return Color.ucdBlue
        case .later:    return Color.clear
        }
    }
}

extension CampusEvent {
    /// "Today", "Tomorrow", "This Friday", etc. for events within the week.
    /// Falls back to standard date format (e.g. "Mar 5, 2026") for later events.
    var friendlyDateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        let startOfToday = calendar.startOfDay(for: Date())
        if let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday),
           date < endOfWeek {
            let dayName = date.formatted(.dateTime.weekday(.wide))
            return "This \(dayName)"
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var dateUrgency: EventDateUrgency {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInTomorrow(date) { return .tomorrow }
        let startOfToday = calendar.startOfDay(for: Date())
        if let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday),
           date < endOfWeek { return .thisWeek }
        return .later
    }

    /// Stable identifier for notification scheduling (title + ISO date, since iCal UUIDs regenerate)
    var stableNotificationId: String {
        let formatter = ISO8601DateFormatter()
        return "\(title)_\(formatter.string(from: date))"
    }
}

enum EventFilterType: String, CaseIterable {
    case forYou = "For You"
    case all = "All Events"
    case official = "UC Davis"
    case studentPosted = "Club Events"
}

enum EventTimeFilter: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allUpcoming = "All Upcoming"
}

// MARK: - Sample Data
extension CampusEvent {
    static let sampleData: [CampusEvent] = [
        CampusEvent(
            title: "Spring Career Fair 2026",
            description: "Connect with top employers and explore internship opportunities",
            date: Date().addingTimeInterval(86400 * 7),
            location: "ARC Pavilion",
            isOfficial: true
        ),
        CampusEvent(
            title: "CS Study Group - Algorithms",
            description: "Weekly coding practice and problem-solving session",
            date: Date().addingTimeInterval(3600 * 2),
            location: "Shields Library, Room 101",
            isOfficial: false
        ),
        CampusEvent(
            title: "Picnic Day Planning Meeting",
            description: "Help plan UC Davis's annual open house event",
            date: Date().addingTimeInterval(86400 * 3),
            location: "Memorial Union",
            isOfficial: true
        )
    ]
}
