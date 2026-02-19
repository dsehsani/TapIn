//
//  EventsAPIService.swift
//  TapInApp
//
//  MARK: - Events API Service
//  Fetches AI-processed campus events from the TapIn backend.
//  Events already include aiSummary and aiBulletPoints — no client-side
//  Claude calls needed.
//

import Foundation

class EventsAPIService {

    static let shared = EventsAPIService()
    private init() {}

    // MARK: - Fetch

    /// Fetches all processed events from the backend.
    /// Returns an empty array (not a throw) if the backend is still warming up.
    func fetchEvents() async throws -> [CampusEvent] {
        guard let url = URL(string: APIConfig.eventsURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        // Backend sends ISO 8601 dates: "2026-02-24T18:00:00Z"
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            // Fallback with fractional seconds
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }

        struct Response: Decodable {
            let success: Bool
            let events: [CampusEvent]
        }

        let parsed = try decoder.decode(Response.self, from: data)
        return parsed.events
    }
}
