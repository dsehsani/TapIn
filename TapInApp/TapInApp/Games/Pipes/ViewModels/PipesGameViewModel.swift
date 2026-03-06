//
//  PipesGameViewModel.swift
//  TapInApp
//

import SwiftUI

@Observable
class PipesGameViewModel {

    // MARK: - Grid / Drawing State

    var gridSize: Int = 5
    var grid: [[PipeColor?]] = []
    var paths: [PipeColor: [PipePosition]] = [:]
    var activeColor: PipeColor? = nil
    var gameState: PipesGameState = .playing
    var moves: Int = 0
    var gameStartTime: Date? = nil
    var gameDurationSeconds: Int = 0
    /// Set once when the session begins — never reset between puzzles. Used for cumulative timer display and leaderboard.
    var sessionStartTime: Date? = nil

    // MARK: - Live Drawing State (Flowing Animation)

    var liveDrawPosition: CGPoint? = nil
    var recentlyFilledCells: Set<PipePosition> = []

    // MARK: - Loading State

    var isLoadingPuzzle: Bool = false
    var loadError: String? = nil

    // MARK: - Daily Five State

    var dailyPuzzles: [PipePuzzle] = []
    var currentPuzzleIndex: Int = 0
    var puzzleStatuses: [PipesPuzzleStatus] = []
    var dailyCompletedCount: Int = 0
    var currentDateKey: String = ""
    var isArchiveMode: Bool = false
    var isReadOnly: Bool = false

    /// Only true the moment the user solves a puzzle in THIS session — not on re-entry
    var justSolvedPuzzle: Bool = false
    /// True when user just solved the 5th puzzle in this session
    var justCompletedAll: Bool = false
    /// True when user re-enters and all 5 were already done
    var alreadyCompletedToday: Bool = false
    /// True when there's saved progress (skip tutorial on re-entry)
    var hasExistingProgress: Bool = false

    /// Leaderboard state
    var scoreSubmitted: Bool = false
    var assignedUsername: String? = nil
    var didExitGame: Bool = false

    func markAsExited() {
        didExitGame = true
        UserDefaults.standard.set(true, forKey: "pipes_did_exit_\(currentDateKey)")
    }

    let difficultyLabels = ["Easy", "Easy", "Medium", "Medium", "Hard"]

    private(set) var currentPuzzle: PipePuzzle
    private var endpointMap: [PipePosition: PipeColor] = [:]
    private var lastDragCell: PipePosition? = nil
    private var dragLocked: Bool = false

    // MARK: - Init

    init() {
        currentPuzzle = PipesPuzzleProvider.shared.puzzleForDate()
        gridSize = currentPuzzle.size
        rebuildGrid()
    }

    // MARK: - Timer

    func startTimer() {
        if sessionStartTime == nil {
            sessionStartTime = Date()  // Only set once for the whole session
        }
        gameStartTime = Date()
        gameDurationSeconds = 0
    }

    /// Called when resuming an existing session — reconstructs sessionStartTime
    /// from already-saved puzzle times so the cumulative timer is accurate.
    func resumeSession() {
        guard sessionStartTime == nil else { return }
        if let start = gameStartTime {
            let candidate = start.addingTimeInterval(-Double(totalTimeForDay))
            // Fix 6: guard against corrupted saved data producing a future sessionStartTime
            sessionStartTime = candidate <= Date() ? candidate : Date()
        } else {
            sessionStartTime = Date()
        }
    }

    // MARK: - Daily Five Loading

    @MainActor
    func loadDailyFive(for date: Date = Date()) async {
        let key = PipesPuzzleProvider.shared.dateKey(for: date)
        currentDateKey = key
        isArchiveMode = !Calendar.current.isDateInToday(date)

        // Reset session-only flags
        justSolvedPuzzle = false
        justCompletedAll = false
        alreadyCompletedToday = false
        didExitGame = UserDefaults.standard.bool(forKey: "pipes_did_exit_\(key)")
        scoreSubmitted = UserDefaults.standard.bool(forKey: "pipes_score_submitted_\(key)")

        // Fix 5: prune exit keys older than 7 days to prevent UserDefaults bloat
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for k in allKeys where k.hasPrefix("pipes_did_exit_") || k.hasPrefix("pipes_score_submitted_") {
            let prefix = k.hasPrefix("pipes_did_exit_") ? "pipes_did_exit_" : "pipes_score_submitted_"
            let dateStr = String(k.dropFirst(prefix.count))
            if let d = df.date(from: dateStr), d < cutoff {
                UserDefaults.standard.removeObject(forKey: k)
            }
        }

        // 1. Check local puzzle cache first (persisted from a previous backend fetch)
        if let cachedPuzzles = PipesGameStorage.shared.getCachedPuzzles(for: key) {
            setupDailyPuzzles(cachedPuzzles, for: key)
            return
        }

        // 2. No cache — fetch from backend (this is the first time for this date)
        let puzzles = await PipesPuzzleProvider.shared.fetchDailyFive(for: date)
        setupDailyPuzzles(puzzles, for: key)
    }

    /// Set up the 5 puzzles for a day — restoring saved state or initializing fresh
    private func setupDailyPuzzles(_ puzzles: [PipePuzzle], for key: String) {
        dailyPuzzles = puzzles

        if let savedState = PipesGameStorage.shared.loadDailyState(for: key) {
            puzzleStatuses = savedState.puzzleStates.map { $0.status }
            dailyCompletedCount = savedState.completedCount
            hasExistingProgress = savedState.puzzleStates.contains(where: {
                $0.status == .inProgress || $0.status == .completed
            })
        } else {
            puzzleStatuses = puzzles.indices.map { $0 == 0 ? .available : .locked }
            dailyCompletedCount = 0
            hasExistingProgress = false

            let initialStates = puzzles.indices.map { i in
                PipesStoredPuzzleState(
                    puzzleIndex: i,
                    dateKey: key,
                    status: i == 0 ? .available : .locked,
                    paths: [:],
                    moves: 0,
                    timeSeconds: 0
                )
            }
            let dailyState = PipesDailyState(dateKey: key, puzzleStates: initialStates)
            PipesGameStorage.shared.saveDailyState(dailyState)
        }

        // Check if all 5 already complete on re-entry
        if dailyCompletedCount == puzzles.count {
            alreadyCompletedToday = true
        }

        // Find the first playable puzzle
        let startIndex = puzzleStatuses.firstIndex(where: {
            $0 == .available || $0 == .inProgress
        }) ?? 0

        loadPuzzle(at: startIndex)
    }

    // MARK: - Puzzle Switching

    func loadPuzzle(at index: Int) {
        guard index >= 0, index < dailyPuzzles.count else { return }

        // Clear session solve flag when switching puzzles
        justSolvedPuzzle = false

        currentPuzzleIndex = index
        currentPuzzle = dailyPuzzles[index]
        gridSize = currentPuzzle.size

        activeColor = nil
        lastDragCell = nil
        dragLocked = false
        liveDrawPosition = nil
        recentlyFilledCells = []

        // Set game state — but DON'T trigger overlays on re-entry
        let status = puzzleStatuses[index]
        if status == .completed {
            gameState = .solved
        } else {
            gameState = .playing
        }

        // Restore saved paths
        if let savedPuzzle = PipesGameStorage.shared.loadPuzzleState(for: currentDateKey, puzzleIndex: index) {
            paths = savedPuzzle.paths
            moves = savedPuzzle.moves
            gameDurationSeconds = savedPuzzle.timeSeconds
            if status != .completed {
                gameStartTime = Date().addingTimeInterval(-Double(savedPuzzle.timeSeconds))
            } else {
                gameStartTime = nil
            }
        } else {
            paths = [:]
            moves = 0
            gameStartTime = nil
            gameDurationSeconds = 0
        }

        endpointMap = [:]
        for pair in currentPuzzle.pairs {
            endpointMap[pair.start] = pair.color
            endpointMap[pair.end] = pair.color
        }

        rebuildGrid()
    }

    func selectPuzzle(at index: Int) {
        guard index >= 0, index < dailyPuzzles.count else { return }
        let status = puzzleStatuses[index]
        guard status != .locked else { return }

        saveCurrentPuzzleProgress()
        loadPuzzle(at: index)
    }

    // MARK: - Progress Persistence

    func saveCurrentPuzzleProgress() {
        guard !dailyPuzzles.isEmpty else { return }

        let currentStatus = puzzleStatuses[currentPuzzleIndex]
        guard currentStatus != .locked else { return }

        var timeToSave = gameDurationSeconds
        if let start = gameStartTime, currentStatus != .completed {
            timeToSave = Int(Date().timeIntervalSince(start))
        }

        let puzzleState = PipesStoredPuzzleState(
            puzzleIndex: currentPuzzleIndex,
            dateKey: currentDateKey,
            status: currentStatus,
            paths: paths,
            moves: moves,
            timeSeconds: timeToSave
        )

        PipesGameStorage.shared.savePuzzleState(puzzleState, for: currentDateKey)
    }

    func saveDailyState() {
        guard !dailyPuzzles.isEmpty else { return }

        let puzzleStates = dailyPuzzles.indices.map { i -> PipesStoredPuzzleState in
            if let saved = PipesGameStorage.shared.loadPuzzleState(for: currentDateKey, puzzleIndex: i) {
                return saved
            }
            return PipesStoredPuzzleState(
                puzzleIndex: i,
                dateKey: currentDateKey,
                status: puzzleStatuses[i],
                paths: [:],
                moves: 0,
                timeSeconds: 0
            )
        }

        let dailyState = PipesDailyState(dateKey: currentDateKey, puzzleStates: puzzleStates)
        PipesGameStorage.shared.saveDailyState(dailyState)
    }

    // MARK: - Puzzle Management

    func resetPuzzle() {
        paths = [:]
        activeColor = nil
        lastDragCell = nil
        dragLocked = false
        moves = 0
        gameDurationSeconds = 0
        gameState = .playing
        justSolvedPuzzle = false
        justCompletedAll = false

        if puzzleStatuses[currentPuzzleIndex] != .locked {
            puzzleStatuses[currentPuzzleIndex] = .available
        }

        // Fix 1: recalculate so UI count stays accurate after reset
        dailyCompletedCount = puzzleStatuses.filter { $0 == .completed }.count

        // Fix 2: restart per-puzzle timer so completion time is tracked correctly
        gameStartTime = Date()

        rebuildGrid()
        saveCurrentPuzzleProgress()
    }

    // MARK: - Drag Handling

    func handleDragAt(row: Int, col: Int) {
        guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }
        guard gameState == .playing, !dragLocked, !isReadOnly else { return }

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
        if let color = endpointMap[pos] {
            activeColor = color
            paths[color] = [pos]

            if puzzleStatuses[currentPuzzleIndex] == .available {
                puzzleStatuses[currentPuzzleIndex] = .inProgress
            }

            rebuildGrid()
            return
        }

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

        if path.count >= 2 && path[path.count - 2] == pos {
            paths[color]?.removeLast()
            withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                rebuildGrid()
            }
            return
        }

        if path.contains(pos) { return }

        if let epColor = endpointMap[pos], epColor != color {
            return
        }

        if let existingColor = grid[pos.row][pos.col], existingColor != color {
            paths[existingColor] = nil
        }

        paths[color]?.append(pos)

        recentlyFilledCells.insert(pos)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.recentlyFilledCells.remove(pos)
        }

        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            rebuildGrid()
        }

        guard let pair = currentPuzzle.pairs.first(where: { $0.color == color }),
              let pathStart = paths[color]?.first else { return }
        let isComplete =
            (pathStart == pair.start && pos == pair.end) ||
            (pathStart == pair.end && pos == pair.start)
        if isComplete {
            activeColor = nil
            dragLocked = true
        }

        if checkWinCondition() {
            handlePuzzleSolved()
        }
    }

    // MARK: - Win Condition

    private func handlePuzzleSolved() {
        if let start = gameStartTime {
            gameDurationSeconds = Int(Date().timeIntervalSince(start))
        }

        withAnimation(.easeInOut(duration: 0.4)) {
            gameState = .solved
        }

        puzzleStatuses[currentPuzzleIndex] = .completed
        dailyCompletedCount = puzzleStatuses.filter { $0 == .completed }.count

        let nextIndex = currentPuzzleIndex + 1
        if nextIndex < puzzleStatuses.count && puzzleStatuses[nextIndex] == .locked {
            puzzleStatuses[nextIndex] = .available
        }

        saveCurrentPuzzleProgress()
        saveDailyState()

        // Set session-only flags so overlays show
        if dailyCompletedCount == dailyPuzzles.count {
            justCompletedAll = true
            submitScoreToLeaderboard()
        } else {
            justSolvedPuzzle = true
        }
    }

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

    // MARK: - Helpers

    private func isAdjacent(_ a: PipePosition, _ b: PipePosition) -> Bool {
        let dr = abs(a.row - b.row)
        let dc = abs(a.col - b.col)
        return (dr == 1 && dc == 0) || (dr == 0 && dc == 1)
    }

    // MARK: - Leaderboard Submission

    func submitScoreToLeaderboard() {
        guard !isArchiveMode else { return }
        guard !scoreSubmitted else { return }
        guard !didExitGame else { return }

        let dateKey = currentDateKey

        // Gather stats from all completed puzzles
        var totalMoves = 0
        var completed = 0

        for i in 0..<dailyPuzzles.count {
            if let saved = PipesGameStorage.shared.loadPuzzleState(for: dateKey, puzzleIndex: i),
               saved.status == .completed {
                totalMoves += saved.moves
                completed += 1
            }
        }

        // Use wall-clock session time for accuracy (not sum of per-puzzle times)
        let totalTime = sessionStartTime.map { Int(Date().timeIntervalSince($0)) } ?? totalTimeForDay

        guard completed > 0 else { return }

        Task {
            do {
                let response = try await LeaderboardService.shared.submitPipesScore(
                    puzzlesCompleted: completed,
                    totalMoves: totalMoves,
                    totalTimeSeconds: totalTime,
                    puzzleDate: dateKey,
                    username: AppState.shared.userName
                )

                await MainActor.run {
                    self.assignedUsername = response.score.username
                    self.scoreSubmitted = true
                    // Persist so re-entry after app restart doesn't re-submit
                    UserDefaults.standard.set(true, forKey: "pipes_score_submitted_\(dateKey)")
                }

                #if DEBUG
                print("Pipes score submitted! Username: \(response.score.username)")
                #endif
            } catch {
                #if DEBUG
                print("Failed to submit pipes score: \(error)")
                #endif
            }
        }
    }

    /// Total moves across all completed puzzles for current day (for overlay display)
    var totalMovesForDay: Int {
        var total = 0
        for i in 0..<dailyPuzzles.count {
            if let saved = PipesGameStorage.shared.loadPuzzleState(for: currentDateKey, puzzleIndex: i),
               saved.status == .completed {
                total += saved.moves
            }
        }
        return total
    }

    /// Total time across all completed puzzles for current day (for overlay display)
    var totalTimeForDay: Int {
        var total = 0
        for i in 0..<dailyPuzzles.count {
            if let saved = PipesGameStorage.shared.loadPuzzleState(for: currentDateKey, puzzleIndex: i),
               saved.status == .completed {
                total += saved.timeSeconds
            }
        }
        return total
    }

    func goToNextPuzzle() {
        justSolvedPuzzle = false
        let nextIndex = currentPuzzleIndex + 1
        if nextIndex < dailyPuzzles.count {
            selectPuzzle(at: nextIndex)
            gameState = .playing
            // Reset per-puzzle timer but keep sessionStartTime running
            gameStartTime = Date()
            gameDurationSeconds = 0
        }
    }
}
