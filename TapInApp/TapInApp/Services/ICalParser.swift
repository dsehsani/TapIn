//
//  ICalParser.swift
//  TapInApp
//
//  Created by Darius Ehsani on 2/10/26.
//
//  MARK: - iCal (.ics) Parser
//  Parses VCALENDAR data from Aggie Life (CampusGroups) into CampusEvent models.
//  Handles the specific format quirks of the Aggie Life feed.
//

import Foundation

struct ICalParser {

    // MARK: - Public API

    /// Parses raw .ics string content into an array of CampusEvent models.
    static func parse(_ icsString: String) -> [CampusEvent] {
        let eventBlocks = extractEventBlocks(from: icsString)
        return eventBlocks.compactMap { parseEvent(from: $0) }
    }

    // MARK: - Block Extraction

    /// Splits the full .ics content into individual VEVENT blocks.
    private static func extractEventBlocks(from icsString: String) -> [String] {
        var blocks: [String] = []
        let lines = icsString.components(separatedBy: "\n")

        var currentBlock: [String] = []
        var insideEvent = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed == "BEGIN:VEVENT" {
                insideEvent = true
                currentBlock = []
            } else if trimmed == "END:VEVENT" {
                insideEvent = false
                blocks.append(currentBlock.joined(separator: "\n"))
            } else if insideEvent {
                currentBlock.append(trimmed)
            }
        }

        return blocks
    }

    // MARK: - Single Event Parsing

    /// Parses a single VEVENT block string into a CampusEvent.
    private static func parseEvent(from block: String) -> CampusEvent? {
        let fields = extractFields(from: block)

        // SUMMARY is required — skip events without a title
        guard let rawSummary = fields["SUMMARY"], !rawSummary.isEmpty else {
            return nil
        }
        let title = rawSummary.trimmingCharacters(in: .whitespaces)

        // DTSTART is required — skip events without a date
        guard let startDateString = fields["DTSTART"],
              let startDate = parseDate(startDateString) else {
            return nil
        }

        let endDate: Date? = {
            guard let endDateString = fields["DTEND"] else { return nil }
            return parseDate(endDateString)
        }()

        let description = cleanDescription(fields["DESCRIPTION"] ?? "")
        let location = cleanLocation(fields["LOCATION"] ?? "")
        let organizerName = extractOrganizerName(from: block)
        let organizerURL = extractOrganizerURL(from: block)
        let clubAcronym = extractCategory(named: "club_acronym", from: block)
        let eventType = extractCategory(named: "event_type", from: block)?.trimmingCharacters(in: .whitespaces)
        let tags = extractTags(from: block)
        let eventURL = fields["URL"]
        let isOfficial = checkIfOfficial(organizerURL: organizerURL, organizerName: organizerName)

        return CampusEvent(
            title: title,
            description: description,
            date: startDate,
            endDate: endDate,
            location: location,
            isOfficial: isOfficial,
            organizerName: organizerName,
            clubAcronym: clubAcronym,
            eventType: eventType,
            tags: tags,
            eventURL: eventURL,
            organizerURL: organizerURL
        )
    }

    // MARK: - Field Extraction

    /// Extracts key-value pairs from a VEVENT block.
    /// Handles iCal properties that have parameters (e.g. `SUMMARY;ENCODING=QUOTED-PRINTABLE:value`).
    private static func extractFields(from block: String) -> [String: String] {
        var fields: [String: String] = [:]
        let lines = block.components(separatedBy: "\n")

        for line in lines {
            // Find the first colon to split key from value
            guard let colonIndex = line.firstIndex(of: ":") else { continue }

            let rawKey = String(line[line.startIndex..<colonIndex])
            let value = String(line[line.index(after: colonIndex)...])

            // Strip parameters from key (e.g. "SUMMARY;ENCODING=QUOTED-PRINTABLE" → "SUMMARY")
            let key = rawKey.components(separatedBy: ";").first ?? rawKey

            // Only store the first occurrence (don't overwrite with CATEGORIES etc.)
            if fields[key] == nil {
                fields[key] = value
            }
        }

        return fields
    }

    // MARK: - Date Parsing

    /// Parses iCal date strings. Handles formats:
    /// - `20251113T010000Z` (UTC datetime)
    /// - `20251113T010000`  (local datetime)
    /// - `20251113`         (date only)
    private static func parseDate(_ dateString: String) -> Date? {
        let cleaned = dateString.trimmingCharacters(in: .whitespacesAndNewlines)

        let utcFormatter = DateFormatter()
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")
        utcFormatter.timeZone = TimeZone(identifier: "UTC")

        // Try UTC datetime first (most common in Aggie Life feed)
        utcFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        if let date = utcFormatter.date(from: cleaned) {
            return date
        }

        // Try local datetime
        utcFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        utcFormatter.timeZone = .current
        if let date = utcFormatter.date(from: cleaned) {
            return date
        }

        // Try date only
        utcFormatter.dateFormat = "yyyyMMdd"
        if let date = utcFormatter.date(from: cleaned) {
            return date
        }

        return nil
    }

    // MARK: - Content Cleaning

    /// Cleans the DESCRIPTION field:
    /// - Converts literal `\n` to actual newlines
    /// - Strips the `---\nEvent Details: <url>` footer that Aggie Life appends
    private static func cleanDescription(_ raw: String) -> String {
        var cleaned = raw.replacingOccurrences(of: "\\n", with: "\n")
        // Remove the Aggie Life footer
        if let separatorRange = cleaned.range(of: "\n---\n") {
            cleaned = String(cleaned[cleaned.startIndex..<separatorRange.lowerBound])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cleans the LOCATION field:
    /// - Returns "TBD" if location is the "Sign in to download" placeholder
    private static func cleanLocation(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().contains("sign in to download") {
            return "TBD"
        }
        return trimmed.isEmpty ? "TBD" : trimmed
    }

    // MARK: - Organizer Extraction

    /// Extracts the club/organizer name from the ORGANIZER line.
    /// Format: `ORGANIZER;CN="Club Name":https://...`
    private static func extractOrganizerName(from block: String) -> String? {
        let lines = block.components(separatedBy: "\n")
        guard let organizerLine = lines.first(where: { $0.hasPrefix("ORGANIZER") }) else {
            return nil
        }
        // Extract content between CN=" and the closing "
        guard let cnStart = organizerLine.range(of: "CN=\""),
              let cnEnd = organizerLine[cnStart.upperBound...].firstIndex(of: "\"") else {
            return nil
        }
        return String(organizerLine[cnStart.upperBound..<cnEnd])
    }

    /// Extracts the organizer's AggieLife URL from the ORGANIZER line.
    /// Format: `ORGANIZER;CN="Club Name":https://aggielife.ucdavis.edu/admin/`
    private static func extractOrganizerURL(from block: String) -> String? {
        let lines = block.components(separatedBy: "\n")
        guard let organizerLine = lines.first(where: { $0.hasPrefix("ORGANIZER") }) else {
            return nil
        }
        // The URL comes after the CN="..." part, separated by a colon
        // Find the https:// portion
        guard let urlStart = organizerLine.range(of: "https://") else {
            return nil
        }
        return String(organizerLine[urlStart.lowerBound...])
    }

    // MARK: - Official Event Detection

    /// Determines if an event is from an official UC Davis source vs a student club.
    /// Official sources use the /admin/ URL path or are known campus resource centers.
    private static func checkIfOfficial(organizerURL: String?, organizerName: String?) -> Bool {
        // Known official organizer URL paths
        if let url = organizerURL {
            if url.contains("/admin/") { return true }
        }

        // Known official campus resource centers
        let officialOrganizers = [
            "center for student involvement",
            "cross cultural center",
            "women's resources and research center",
            "guardian scholars program",
            "asucd",
            "student affairs",
        ]

        if let name = organizerName?.lowercased() {
            return officialOrganizers.contains(where: { name.contains($0) })
        }

        return false
    }

    // MARK: - Category Extraction

    /// Extracts a specific category value from CATEGORIES lines.
    /// e.g. for `CATEGORIES;X-CG-CATEGORY=club_acronym:COFFEE`, passing "club_acronym" returns "COFFEE".
    private static func extractCategory(named name: String, from block: String) -> String? {
        let lines = block.components(separatedBy: "\n")
        let prefix = "CATEGORIES;X-CG-CATEGORY=\(name):"
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return String(line.dropFirst(prefix.count))
    }

    /// Extracts event tags from the event_tags CATEGORIES line.
    /// Returns an array of individual tags.
    private static func extractTags(from block: String) -> [String] {
        guard let tagsString = extractCategory(named: "event_tags", from: block) else {
            return []
        }
        return tagsString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
