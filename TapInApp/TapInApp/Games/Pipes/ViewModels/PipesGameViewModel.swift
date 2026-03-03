//
//  PipesGameViewModel.swift
//  TapInApp
//

import SwiftUI

@Observable
class PipesGameViewModel {

    // MARK: - State

    var gridSize: Int = 5
    var grid: [[PipeColor?]] = []
    var paths: [PipeColor: [PipePosition]] = [:]
    var activeColor: PipeColor? = nil
    var gameState: PipesGameState = .playing
    var moves: Int = 0
    var gameStartTime: Date? = nil
    var gameDurationSeconds: Int = 0

    // MARK: - Live Drawing State (Flowing Animation)

    /// Current finger position for live preview line (in view coordinates)
    var liveDrawPosition: CGPoint? = nil

    /// Track which cells were recently filled for snap animation
    var recentlyFilledCells: Set<PipePosition> = []

    // MARK: - Loading State (Backend Integration)

    var isLoadingPuzzle: Bool = false
    var loadError: String? = nil

    private(set) var currentPuzzle: PipePuzzle
    private var endpointMap: [PipePosition: PipeColor] = [:]
    private var lastDragCell: PipePosition? = nil
    private var dragLocked: Bool = false

    private let storageKey = "pipes_completed_date"

    var isCompletedToday: Bool {
        guard let saved = UserDefaults.standard.string(forKey: storageKey) else { return false }
        return saved == PipesPuzzleProvider.shared.dateKey()
    }

    // MARK: - Init

    init() {
        currentPuzzle = PipesPuzzleProvider.shared.puzzleForDate()
        loadDailyPuzzle()

        // Attempt to fetch from backend asynchronously
        Task {
            await loadDailyPuzzleAsync()
        }
    }

    // MARK: - Timer

    func startTimer() {
        gameStartTime = Date()
        gameDurationSeconds = 0
    }

    // MARK: - Puzzle Management

    func loadDailyPuzzle() {
        currentPuzzle = PipesPuzzleProvider.shared.puzzleForDate()
        gridSize = currentPuzzle.size
        gameState = .playing
        moves = 0
        gameStartTime = nil
        gameDurationSeconds = 0
        paths = [:]
        activeColor = nil
        lastDragCell = nil
        dragLocked = false

        endpointMap = [:]
        for pair in currentPuzzle.pairs {
            endpointMap[pair.start] = pair.color
            endpointMap[pair.end] = pair.color
        }

        rebuildGrid()
    }

    func resetPuzzle() {
        paths = [:]
        activeColor = nil
        lastDragCell = nil
        dragLocked = false
        moves = 0
        gameStartTime = nil
        gameDurationSeconds = 0
        gameState = .playing
        rebuildGrid()
    }

    // MARK: - Drag Handling

    func handleDragAt(row: Int, col: Int) {
        guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }
        guard gameState == .playing, !dragLocked else { return }

        let pos = PipePosition(row: row, col: col)

        if pos == lastDragCell { return }
        lastDragCell = pos

        if activeColor == nil {
            startDrag(at: pos)
        } else {
            continueDrag(to: pos)
        }
    }

    func handleDragEnd() {
        if activeColor != nil || dragLocked {
            moves += 1
        }
        activeColor = nil
        lastDragCell = nil
        dragLocked = false
        liveDrawPosition = nil
    }

    private func startDrag(at pos: PipePosition) {
        // Touching an endpoint — start fresh path for that color
        if let color = endpointMap[pos] {
            activeColor = color
            paths[color] = [pos]
            rebuildGrid()
            return
        }

        // Touching an existing path cell — pick up from that point
        for (color, path) in paths {
            if let idx = path.firstIndex(of: pos) {
                activeColor = color
                paths[color] = Array(path.prefix(through: idx))
                rebuildGrid()
                return
            }
        }
    }

    private func continueDrag(to pos: PipePosition) {
        guard let color = activeColor else { return }
        guard let path = paths[color], !path.isEmpty else { return }
        let last = path.last!

        guard isAdjacent(last, pos) else { return }

        // Backtracking
        if path.count >= 2 && path[path.count - 2] == pos {
            paths[color]?.removeLast()
            withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                rebuildGrid()
            }
            return
        }

        // No loops
        if path.contains(pos) { return }

        // Can't enter another color's endpoint
        if let epColor = endpointMap[pos], epColor != color {
            return
        }

        // Clear conflicting path
        if let existingColor = grid[pos.row][pos.col], existingColor != color {
            paths[existingColor] = nil
        }

        paths[color]?.append(pos)

        // Mark cell as recently filled for snap animation
        recentlyFilledCells.insert(pos)

        // Clear animation state after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.recentlyFilledCells.remove(pos)
        }

        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            rebuildGrid()
        }

        // If we reached the matching endpoint, lock the path
        let pair = currentPuzzle.pairs.first { $0.color == color }!
        let pathStart = paths[color]!.first!
        let isComplete =
            (pathStart == pair.start && pos == pair.end) ||
            (pathStart == pair.end && pos == pair.start)
        if isComplete {
            activeColor = nil
            dragLocked = true
        }

        if checkWinCondition() {
            if let start = gameStartTime {
                gameDurationSeconds = Int(Date().timeIntervalSince(start))
            }
            UserDefaults.standard.set(
                PipesPuzzleProvider.shared.dateKey(),
                forKey: storageKey
            )
            withAnimation(.easeInOut(duration: 0.4)) {
                gameState = .solved
            }
        }
    }

    // MARK: - Grid

    private func rebuildGrid() {
        grid = Array(repeating: Array(repeating: nil as PipeColor?, count: gridSize), count: gridSize)

        for (pos, color) in endpointMap {
            grid[pos.row][pos.col] = color
        }

        for (color, path) in paths {
            for pos in path {
                grid[pos.row][pos.col] = color
            }
        }
    }

    // MARK: - Win Condition

    private func checkWinCondition() -> Bool {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if grid[row][col] == nil { return false }
            }
        }

        for pair in currentPuzzle.pairs {
            guard let path = paths[pair.color], path.count >= 2 else { return false }
            let first = path.first!
            let last = path.last!
            let connects =
                (first == pair.start && last == pair.end) ||
                (first == pair.end && last == pair.start)
            if !connects { return false }
        }

        return true
    }

    // MARK: - Helpers

    private func isAdjacent(_ a: PipePosition, _ b: PipePosition) -> Bool {
        let dr = abs(a.row - b.row)
        let dc = abs(a.col - b.col)
        return (dr == 1 && dc == 0) || (dr == 0 && dc == 1)
    }

    // MARK: - Async Puzzle Loading (Backend Integration)

    @MainActor
    func loadDailyPuzzleAsync() async {
        isLoadingPuzzle = true
        loadError = nil

        let puzzle = await PipesPuzzleProvider.shared.fetchDailyPuzzle()

        // Only update if puzzle is different (from backend)
        if puzzle.size != currentPuzzle.size || puzzle.pairs.count != currentPuzzle.pairs.count {
            currentPuzzle = puzzle
            gridSize = puzzle.size
            gameState = .playing
            moves = 0
            gameStartTime = nil
            gameDurationSeconds = 0
            paths = [:]
            activeColor = nil
            lastDragCell = nil
            dragLocked = false
            liveDrawPosition = nil
            recentlyFilledCells = []

            endpointMap = [:]
            for pair in currentPuzzle.pairs {
                endpointMap[pair.start] = pair.color
                endpointMap[pair.end] = pair.color
            }

            rebuildGrid()
        }

        isLoadingPuzzle = false
    }
}
