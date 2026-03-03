//
//  PipesPuzzleProvider.swift
//  TapInApp
//
//  MARK: - Service Layer
//  Singleton service that provides Pipes puzzles.
//  Supports daily single puzzle and daily-five set with backend + fallback.
//

import Foundation

class PipesPuzzleProvider {

    static let shared = PipesPuzzleProvider()

    /// Start date for the daily-five feature
    static let startDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        return Calendar.current.date(from: components)!
    }()

    private init() {}

    private let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    /// Cached puzzle to avoid redundant network calls (legacy single puzzle)
    private var cachedPuzzle: (date: String, puzzle: PipePuzzle)?

    /// Cached daily-five puzzles
    private var cachedDailyFive: (date: String, puzzles: [PipePuzzle])?

    func dateKey(for date: Date = Date()) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Daily Five Fetching

    /// Fetch 5-puzzle set for a given date with cascading fallback:
    /// 1. Local puzzle cache (PipesGameStorage)
    /// 2. Backend /api/pipes/daily-five
    /// 3. Deterministic offline fallback templates
    func fetchDailyFive(for date: Date = Date()) async -> [PipePuzzle] {
        let key = dateKey(for: date)

        // In-memory cache
        if let cached = cachedDailyFive, cached.date == key {
            return cached.puzzles
        }

        // Local persistent cache
        if let cached = PipesGameStorage.shared.getCachedPuzzles(for: key) {
            cachedDailyFive = (key, cached)
            return cached
        }

        // Try backend
        do {
            let puzzles = try await fetchDailyFiveFromBackend(dateKey: key)
            cachedDailyFive = (key, puzzles)
            PipesGameStorage.shared.cachePuzzles(for: key, puzzles: puzzles)
            return puzzles
        } catch {
            print("PipesPuzzleProvider: Failed to fetch daily-five from backend: \(error)")
        }

        // Offline fallback
        let fallback = PipePuzzle.dailyFiveFallback(for: key)
        cachedDailyFive = (key, fallback)
        return fallback
    }

    private func fetchDailyFiveFromBackend(dateKey: String) async throws -> [PipePuzzle] {
        guard let url = URL(string: "\(APIConfig.pipesDailyFiveURL)?date=\(dateKey)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let dailyFiveResponse = try JSONDecoder().decode(PipesDailyFiveResponse.self, from: data)

        return dailyFiveResponse.puzzles.map { puzzleData in
            PipePuzzle(
                size: puzzleData.size,
                pairs: puzzleData.pairs.map { pair in
                    PipeEndpointPair(
                        color: PipeColor(rawValue: pair.color) ?? .red,
                        start: PipePosition(row: pair.start.row, col: pair.start.col),
                        end: PipePosition(row: pair.end.row, col: pair.end.col)
                    )
                }
            )
        }
    }

    // MARK: - Legacy Single Puzzle (backward compat)

    /// Fetch daily puzzle from backend with fallback to static puzzles
    func fetchDailyPuzzle() async -> PipePuzzle {
        let today = dateKey()

        if let cached = cachedPuzzle, cached.date == today {
            return cached.puzzle
        }

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

    func fallbackPuzzle() -> PipePuzzle {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % PipePuzzle.puzzles.count
        return PipePuzzle.puzzles[index]
    }

    // MARK: - Legacy Sync Method

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

struct PipesDailyFiveResponse: Codable {
    let date: String
    let puzzles: [PuzzleData]

    struct PuzzleData: Codable {
        let index: Int?
        let size: Int
        let pairs: [PipePuzzleResponse.PairResponse]
        let difficulty: String?
    }
}
