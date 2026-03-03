//
//  PipesPuzzleProvider.swift
//  TapInApp
//
//  MARK: - Service Layer
//  Singleton service that provides one Pipes puzzle per day.
//  Supports fetching AI-generated puzzles from the backend with fallback to static puzzles.
//

import Foundation

class PipesPuzzleProvider {

    static let shared = PipesPuzzleProvider()

    private init() {}

    private let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    /// Cached puzzle to avoid redundant network calls
    private var cachedPuzzle: (date: String, puzzle: PipePuzzle)?

    func dateKey(for date: Date = Date()) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Async Puzzle Fetching (Backend Integration)

    /// Fetch daily puzzle from backend with fallback to static puzzles
    func fetchDailyPuzzle() async -> PipePuzzle {
        let today = dateKey()

        // Return cached if available for today
        if let cached = cachedPuzzle, cached.date == today {
            return cached.puzzle
        }

        // Try fetching from backend
        do {
            let puzzle = try await fetchFromBackend()
            cachedPuzzle = (today, puzzle)
            return puzzle
        } catch {
            print("PipesPuzzleProvider: Failed to fetch from backend: \(error)")
            return fallbackPuzzle()
        }
    }

    private func fetchFromBackend() async throws -> PipePuzzle {
        guard let url = URL(string: APIConfig.pipesDailyURL) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let puzzleResponse = try JSONDecoder().decode(PipePuzzleResponse.self, from: data)

        return PipePuzzle(
            size: puzzleResponse.size,
            pairs: puzzleResponse.pairs.map { pair in
                PipeEndpointPair(
                    color: PipeColor(rawValue: pair.color) ?? .red,
                    start: PipePosition(row: pair.start.row, col: pair.start.col),
                    end: PipePosition(row: pair.end.row, col: pair.end.col)
                )
            }
        )
    }

    // MARK: - Fallback (Static Puzzles)

    /// Fallback to static puzzles if backend is unavailable
    func fallbackPuzzle() -> PipePuzzle {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % PipePuzzle.puzzles.count
        return PipePuzzle.puzzles[index]
    }

    // MARK: - Legacy Sync Method

    /// Synchronous puzzle access (uses cached or fallback)
    /// Used for initial load before async fetch completes
    func puzzleForDate(_ date: Date = Date()) -> PipePuzzle {
        if let cached = cachedPuzzle, cached.date == dateKey(for: date) {
            return cached.puzzle
        }
        return fallbackPuzzle()
    }
}

// MARK: - Response Models

struct PipePuzzleResponse: Codable {
    let size: Int
    let pairs: [PairResponse]
    let date: String?
    let difficulty: String?

    struct PairResponse: Codable {
        let color: String
        let start: PositionResponse
        let end: PositionResponse
    }

    struct PositionResponse: Codable {
        let row: Int
        let col: Int
    }
}
