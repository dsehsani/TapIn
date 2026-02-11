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
        organizerURL: String? = nil
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
    }
}

enum EventFilterType: String, CaseIterable {
    case all = "All Events"
    case official = "Official"
    case studentPosted = "Student Events"
    case today = "Today"
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
