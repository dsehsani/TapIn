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
        aiBulletPoints: [String] = []
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
    }

    // MARK: - Codable (custom to handle server "startDate" vs local "date")

    enum CodingKeys: String, CodingKey {
        case id, title, description, location, isOfficial
        case imageURL, organizerName, clubAcronym, eventType
        case tags, eventURL, organizerURL, aiSummary, aiBulletPoints
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
    }
}

import SwiftUI

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
