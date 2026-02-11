//
//  AggieLifeService.swift
//  TapInApp
//
//  Created by Darius Ehsani on 2/10/26.
//
//  MARK: - Aggie Life Service
//  Fetches the iCal feed from Aggie Life (CampusGroups) and returns parsed CampusEvent models.
//

import Foundation

class AggieLifeService {

    // MARK: - Feed URL
    // TODO: Replace with the actual Aggie Life iCal export URL
    static let feedURL = URL(string: "https://aggielife.ucdavis.edu/ical/ucdavis/ical_ucdavis.ics")!

    // MARK: - Errors

    enum ServiceError: LocalizedError {
        case invalidURL
        case networkFailure(Error)
        case emptyResponse
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid feed URL."
            case .networkFailure(let error):
                return "Network error: \(error.localizedDescription)"
            case .emptyResponse:
                return "The events feed returned no data."
            case .parsingFailed:
                return "Failed to parse the events feed."
            }
        }
    }

    // MARK: - Fetch Events

    /// Fetches and parses events from the Aggie Life iCal feed.
    func fetchEvents() async throws -> [CampusEvent] {
        let url = AggieLifeService.feedURL

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw ServiceError.networkFailure(error)
        }

        // Verify we got a valid HTTP response
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw ServiceError.networkFailure(
                NSError(domain: "HTTP", code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Server returned status \(httpResponse.statusCode)"])
            )
        }

        guard let icsString = String(data: data, encoding: .utf8), !icsString.isEmpty else {
            throw ServiceError.emptyResponse
        }

        let events = ICalParser.parse(icsString)

        if events.isEmpty {
            throw ServiceError.parsingFailed
        }

        // Sort by date, soonest first
        return events.sorted { $0.date < $1.date }
    }
}
