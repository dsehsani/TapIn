# Local Leaderboards Implementation Spec

> **Owner:** Yash Pradhan
> **Last Updated:** 2026-02-12
> **Status:** In Progress

---

## Quick Context for Future Sessions

This document contains all context needed to continue implementing the local leaderboards feature. Read this file first when resuming work on leaderboards.

---

## Task Overview

### Primary Deliverables
- [ ] Local Leaderboards feature design and core implementation
- [ ] Google Cloud backend solution researched and documented
- [ ] API requirements fully documented for backend team (Jake)

### Success Criteria
1. **Feature Development:**
   - Define leaderboard categories and scoring mechanisms
   - Implement UI for displaying leaderboard rankings
   - User profile integration for leaderboard participation

2. **Research & Documentation:**
   - GCP comparison document (Cloud Functions, App Engine, Cloud Run)
   - Recommendation with cost estimates and scalability analysis
   - API specification document (endpoints, data models, auth)

3. **Integration Points:**
   - Daily sync with Jake on server architecture decisions
   - Provide Jake with specific GCP service requirements
   - Ensure leaderboard data model works with existing user profiles

---

## Architecture Decisions (Confirmed)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Leaderboard Structure** | 3 separate leaderboards (one per game) | Can't compare guesses vs points vs time; confirmed 2026-02-17 |
| **Storage Model** | Local cache + Remote sync | Store locally for offline, sync to cloud when available |
| **Ranking Period** | Daily (reset each day) | Separate leaderboard per day, like current Wordle |
| **Visibility** | Global leaderboard | All users can see rankings against other app users |

### High-Level Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iOS App       │────▶│  Local Cache    │────▶│  GCP Backend    │
│   (SwiftUI)     │     │  (UserDefaults/ │     │  (TBD - Cloud   │
│                 │◀────│   CoreData)     │◀────│   Run/Firestore)│
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

**Flow:**
1. User completes game → Score saved locally immediately
2. If online → Submit to cloud backend, receive global ranking
3. If offline → Queue submission, sync when connection restored
4. Leaderboard view → Show cached data, refresh from cloud periodically

---

## Current Codebase State

### Existing Games and Scoring

| Game | Current Scoring | Leaderboard Score Formula | Status |
|------|-----------------|---------------------------|--------|
| **Wordle** | Guesses (1-6), Time (seconds) | Lower guesses + faster time = higher rank | Implemented, has Flask backend |
| **Echo** | `attemptsRemaining * 100` per round | Total score across 5 rounds (0-1500 max) | Implemented, no leaderboard |
| **Trivia** | Not implemented | TBD | Planned |
| **Crossword** | Not implemented | TBD | Planned |

### Existing Models (TapInApp/Models/Game.swift)

```swift
// Already exists - can be reused
enum GameType: String, Codable, CaseIterable {
    case wordle, trivia, crossword, echo
}

struct GameStats: Codable {
    var gamesPlayed: Int
    var currentStreak: Int
    var maxStreak: Int
    var wins: Int
    var lastPlayedDate: Date?
    var winPercentage: Double { ... }
}

struct LeaderboardEntry: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let userName: String
    let gameType: GameType
    let score: Int
    let rank: Int
    let date: Date
}

struct ScoreSubmission: Codable {
    let gameType: GameType
    let score: Int
    let date: Date
    let metadata: [String: String]?  // For game-specific data
}
```

### Existing User Model (TapInApp/Models/User.swift)

```swift
struct User: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var profileImageURL: String?
}
```

**Gap:** User model has no link to game stats or leaderboard participation. Needs extension.

### Existing Services

| Service | Location | Purpose |
|---------|----------|---------|
| `LeaderboardService.swift` | TapInApp/Services/ | Remote Flask API (Wordle-only, localhost:8080) |
| `GameStorage.swift` | Games/Wordle/Services/ | Local persistence for Wordle game state |
| `UserDefaultManager.swift` | TapInApp/Services/ | Generic UserDefaults wrapper |

### Existing ViewModels with Score Data

| ViewModel | Location | Relevant Properties |
|-----------|----------|---------------------|
| `GameViewModel` (Wordle) | Games/Wordle/ViewModels/ | `currentRow` (guesses), `gameDurationSeconds`, `gameState` |
| `EchoGameViewModel` | Games/Echo/ViewModels/ | `score`, `roundScores`, `roundResults`, `perfectRounds` |

---

## Proposed Scoring Mechanisms

### Wordle Scoring (for leaderboard ranking)
```
Primary sort: Fewer guesses = better
Secondary sort: Faster time = better (tiebreaker)

Score formula (for display):
  baseScore = (7 - guesses) * 100  // Win in 1 = 600, win in 6 = 100
  timeBonus = max(0, 300 - timeSeconds)  // Up to 300 bonus for speed
  totalScore = baseScore + timeBonus
```

### Echo Scoring (already implemented)
```
Per round: attemptsRemaining * 100 (max 300 per round)
Total: Sum of 5 rounds (max 1500)

Ranking: Higher score = better
Tiebreaker: Fewer total attempts used
```

### Trivia Scoring (proposed)
```
Per question: 100 points for correct, 0 for incorrect
Time bonus: Faster answers get bonus points
Total: Sum across all questions

Ranking: Higher score = better
```

### Crossword Scoring (confirmed 2026-02-17)
```
Completion time is the ONLY metric
Hints do NOT affect ranking (Option A)

Ranking: Faster completion time = better
Tiebreaker: None needed (time is precise enough)

Note: We chose Option A (time only) over penalizing hints because:
- Simpler to understand for users
- Hints are a learning tool, not a competitive disadvantage
- Can revisit if users request hint penalties later
```

---

## Data Models Needed

### Local Storage Models

```swift
// New: Local score cache
struct LocalScore: Codable, Identifiable {
    let id: UUID
    let gameType: GameType
    let userId: UUID
    let score: Int
    let date: Date  // Puzzle/game date (not submission time)
    let metadata: GameMetadata
    var syncStatus: SyncStatus
    var remoteId: String?  // Set after successful sync
}

enum SyncStatus: String, Codable {
    case pending    // Not yet synced
    case synced     // Successfully synced
    case failed     // Sync failed, will retry
}

// Game-specific metadata
struct GameMetadata: Codable {
    // Wordle
    var guesses: Int?
    var timeSeconds: Int?

    // Echo
    var roundScores: [Int]?
    var perfectRounds: Int?
    var totalAttempts: Int?

    // Trivia
    var correctAnswers: Int?
    var totalQuestions: Int?

    // Crossword
    var completionTimeSeconds: Int?
    var hintsUsed: Int?
}
```

### Extended User Model

```swift
// Extension to existing User
extension User {
    // Computed from local cache or fetched from server
    var gameStats: [GameType: GameStats] { get }
    var recentScores: [LocalScore] { get }
}
```

---

## Services Needed

### 1. LocalLeaderboardService (New)
```swift
// Manages local score storage and caching
class LocalLeaderboardService {
    // Save score locally
    func saveScore(_ score: LocalScore)

    // Get cached leaderboard for date
    func getCachedLeaderboard(for gameType: GameType, date: Date) -> [LeaderboardEntry]

    // Get user's scores
    func getUserScores(for gameType: GameType) -> [LocalScore]

    // Get pending sync items
    func getPendingScores() -> [LocalScore]

    // Update sync status
    func markAsSynced(_ scoreId: UUID, remoteId: String)
}
```

### 2. LeaderboardSyncService (New)
```swift
// Handles sync between local and remote
class LeaderboardSyncService {
    // Sync pending scores to server
    func syncPendingScores() async

    // Fetch and cache remote leaderboard
    func refreshLeaderboard(for gameType: GameType, date: Date) async

    // Check connectivity and sync status
    var isOnline: Bool { get }
    var hasPendingSync: Bool { get }
}
```

### 3. Update Existing LeaderboardService
- Rename to `RemoteLeaderboardService` or `WordleLeaderboardService`
- Or generalize to support all game types

---

## UI Components Needed

### 1. LeaderboardView (Main)
- Tab/segment control to switch between games
- Date picker for viewing past days
- List of rankings with user highlight
- Pull-to-refresh for sync

### 2. LeaderboardRowView
- Rank number (with medal for top 3?)
- Username
- Score display (game-specific formatting)
- "You" indicator if current user

### 3. LeaderboardHeaderView
- Game icon and name
- Date display
- Sync status indicator

### 4. Integration Points
- Add leaderboard access from `GamesView`
- Add leaderboard summary to `ProfileView`
- Show rank in game-over screens

---

## API Specification (For Jake)

### Endpoints Needed

#### POST /api/scores
Submit a new score.

```json
// Request
{
  "user_id": "uuid",
  "game_type": "wordle|echo|trivia|crossword",
  "score": 450,
  "date": "2026-02-12",
  "metadata": {
    "guesses": 3,
    "time_seconds": 120
  }
}

// Response
{
  "success": true,
  "score_id": "remote-uuid",
  "rank": 15,
  "total_players": 234
}
```

#### GET /api/leaderboard/{game_type}/{date}
Get leaderboard for a specific game and date.

```json
// Response
{
  "success": true,
  "game_type": "wordle",
  "date": "2026-02-12",
  "total_players": 234,
  "leaderboard": [
    {
      "rank": 1,
      "user_id": "uuid",
      "username": "AggieChamp",
      "score": 580,
      "metadata": { "guesses": 1, "time_seconds": 45 }
    },
    // ... top N entries
  ],
  "user_rank": {  // Current user's position if not in top N
    "rank": 15,
    "score": 450
  }
}
```

#### GET /api/users/{user_id}/stats
Get user's overall stats across all games.

```json
// Response
{
  "success": true,
  "user_id": "uuid",
  "stats": {
    "wordle": {
      "games_played": 45,
      "current_streak": 12,
      "max_streak": 20,
      "wins": 42,
      "average_guesses": 3.8
    },
    "echo": {
      "games_played": 20,
      "high_score": 1400,
      "average_score": 890
    }
  }
}
```

### Authentication Requirements
- User must be authenticated to submit scores
- Anonymous users can view leaderboards but not participate
- Consider: Device ID fallback for non-authenticated users?

### Data Models (Server-side)

```
Score {
  id: UUID (primary key)
  user_id: UUID (foreign key)
  game_type: String
  score: Integer
  date: Date
  metadata: JSON
  created_at: Timestamp
}

User {
  id: UUID (primary key)
  username: String (unique, display name)
  email: String (optional, for auth)
  created_at: Timestamp
}

DailyLeaderboard {
  // Materialized view or cached table
  game_type: String
  date: Date
  rankings: JSON (cached top N)
  total_players: Integer
  updated_at: Timestamp
}
```

---

## GCP Options to Research

| Service | Pros | Cons | Best For |
|---------|------|------|----------|
| **Cloud Run** | Auto-scaling, pay-per-use, containerized | Cold starts | Variable traffic, cost-conscious |
| **App Engine** | Managed, easy deploy | Less flexible | Simple APIs, quick setup |
| **Cloud Functions** | Serverless, event-driven | Cold starts, 9min timeout | Simple endpoints, triggers |
| **Firestore** | Real-time sync, offline support | NoSQL limitations | Mobile apps, real-time data |
| **Cloud SQL** | Relational, familiar | Always-on cost | Complex queries, joins |

### Recommendation Factors to Evaluate
1. Cost at different user scales (100, 1000, 10000 DAU)
2. Latency requirements
3. Offline sync complexity
4. Team familiarity
5. Integration with existing Flask server

---

## Open Questions / Blockers

1. **User Authentication:** How are users currently authenticated? Need to link scores to user accounts.
2. **Username Generation:** Keep auto-generated ("SwiftFalcon") or use actual usernames?
3. **Trivia/Crossword Scoring:** Need to finalize scoring formulas when games are implemented.
4. **Rate Limiting:** How to prevent score manipulation/spam?
5. **Data Retention:** How long to keep historical leaderboards?

---

## Implementation Order (Suggested)

1. **Phase 1: Local Storage**
   - Create `LocalLeaderboardService`
   - Implement `LocalScore` model
   - Integrate with existing game ViewModels

2. **Phase 2: UI**
   - Create `LeaderboardView` and subcomponents
   - Add leaderboard access points in app
   - Display local scores (offline-capable)

3. **Phase 3: Remote Sync**
   - Finalize GCP choice with Jake
   - Create `LeaderboardSyncService`
   - Implement background sync

4. **Phase 4: Polish**
   - Add animations and transitions
   - Handle edge cases (ties, empty states)
   - Performance optimization

---

## File Locations Reference

```
TapInApp/
├── Models/
│   ├── Game.swift              # GameType, LeaderboardEntry (existing)
│   └── LocalScore.swift        # NEW: Local score cache model
├── Services/
│   ├── LeaderboardService.swift      # Existing (Wordle remote)
│   ├── LocalLeaderboardService.swift # NEW: Local storage
│   └── LeaderboardSyncService.swift  # NEW: Sync logic
├── ViewModels/
│   └── LeaderboardViewModel.swift    # NEW: Leaderboard UI state
├── Views/
│   └── LeaderboardView.swift         # NEW: Main leaderboard UI
├── Components/
│   ├── LeaderboardRowView.swift      # NEW
│   └── LeaderboardHeaderView.swift   # NEW
└── Games/
    ├── Wordle/ViewModels/GameViewModel.swift  # Update: call leaderboard
    └── Echo/ViewModels/EchoGameViewModel.swift # Update: call leaderboard
```

---

## Related Documents

- `LEADERBOARD.md` - Original Flask Wordle backend spec (different from this task)
- Jake's server documentation (TBD)

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-12 | Initial spec created with architecture decisions |
| 2026-02-17 | Added Phase 1 Implementation Prompt with detailed codebase analysis |

---

# Phase 1 Implementation Prompt

> **Purpose:** This section provides a detailed, step-by-step implementation guide for Phase 1 (Local Storage Foundation) of the Local Leaderboards feature. An AI assistant or developer can follow this prompt to implement the feature correctly.

---

## Codebase Context (Current State as of 2026-02-17)

### What Already Exists

Before implementing, understand what's already built:

#### 1. Games with Scoring Systems

| Game | File | Scoring Properties | Leaderboard Status |
|------|------|-------------------|-------------------|
| **Wordle** | `Games/Wordle/ViewModels/GameViewModel.swift` | `currentRow` (guesses 1-6), `gameDurationSeconds`, `gameState` | ✅ Has remote leaderboard via `LeaderboardService` |
| **Echo** | `Games/Echo/ViewModels/EchoGameViewModel.swift` | `score` (0-1500), `roundScores`, `perfectRounds`, `totalAttemptsUsed`, `roundsSolved` | ❌ No leaderboard integration |
| **MiniCrossword** | `Games/MiniCrossWord/ViewModels/CrosswordViewModel.swift` | `elapsedSeconds`, `gameState` | ❌ No leaderboard integration |

#### 2. Existing Models (`TapInApp/Models/Game.swift`)

```swift
// These already exist and should be REUSED, not recreated:
enum GameType: String, Codable, CaseIterable {
    case wordle = "wordle"
    case trivia = "trivia"
    case crossword = "crossword"
    case echo = "echo"
}

struct GameStats: Codable {
    var gamesPlayed: Int
    var currentStreak: Int
    var maxStreak: Int
    var wins: Int
    var lastPlayedDate: Date?
    var winPercentage: Double { ... }
}

struct LeaderboardEntry: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let userName: String
    let gameType: GameType
    let score: Int
    let rank: Int
    let date: Date
}

struct ScoreSubmission: Codable {
    let gameType: GameType
    let score: Int
    let date: Date
    let metadata: [String: String]?
}
```

#### 3. Existing Services

| Service | Location | Pattern | Key Methods |
|---------|----------|---------|-------------|
| `LeaderboardService` | `Services/LeaderboardService.swift` | Singleton (`shared`), `@MainActor`, `ObservableObject` | `submitScore()`, `fetchLeaderboard()`, `isServerHealthy()` |
| `GameStorage` | `Games/Wordle/Services/GameStorage.swift` | Singleton (`shared`), UserDefaults-based | `saveGameState()`, `loadGameState()`, date-keyed storage |
| `CrosswordStorage` | `Games/MiniCrossWord/Services/CrosswordStorage.swift` | Singleton (`shared`), UserDefaults-based | Same pattern as GameStorage |

#### 4. Architecture Patterns Used

- **MVVM:** Views bind to `@Observable` ViewModels
- **Singletons:** Services use `static let shared = ServiceName()` pattern
- **UserDefaults:** JSON-encoded data stored with string keys
- **Date Keys:** Format `yyyy-MM-dd` for daily game data
- **Async/Await:** All network operations use Swift concurrency
- **Error Handling:** Uses `AppError` enum from `Models/AppError.swift`

#### 5. How Wordle Currently Submits Scores

From `GameViewModel.swift:426-468`:
```swift
func submitScoreToLeaderboard() {
    // Only submit for today's game
    guard !isArchiveMode else { return }
    guard gameState == .won else { return }
    guard !scoreSubmitted else { return }
    guard let startTime = gameStartTime else { return }

    let duration = Int(Date().timeIntervalSince(startTime))
    gameDurationSeconds = duration

    // Format date for API (YYYY-MM-DD)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let puzzleDate = dateFormatter.string(from: currentDate)

    Task {
        do {
            let response = try await LeaderboardService.shared.submitScore(
                guesses: currentRow,
                timeSeconds: duration,
                puzzleDate: puzzleDate
            )
            await MainActor.run {
                self.assignedUsername = response.score.username
                self.scoreSubmitted = true
            }
        } catch {
            print("Failed to submit score: \(error)")
        }
    }
}
```

---

## Phase 1 Implementation Steps

### Step 1: Create `LocalScore.swift` Model

**Location:** `TapInApp/TapInApp/Models/LocalScore.swift`

**Reasoning:** We need a unified model that can store scores from ANY game type locally, track sync status, and hold game-specific metadata. This is different from the existing `ScoreSubmission` because it includes persistence-specific fields like `syncStatus` and `remoteId`.

```swift
//
//  LocalScore.swift
//  TapInApp
//
//  MARK: - Local Score Model
//  Represents a score stored locally on the device.
//  Supports offline-first architecture with sync status tracking.
//

import Foundation

// MARK: - Sync Status
/// Tracks the synchronization state of a local score with the remote server.
enum SyncStatus: String, Codable {
    case pending    // Not yet synced to server
    case synced     // Successfully synced
    case failed     // Sync attempted but failed, will retry
}

// MARK: - Game Metadata
/// Game-specific metadata for different game types.
/// Each game can have its own relevant data stored here.
struct GameMetadata: Codable, Equatable {
    // Wordle-specific
    var guesses: Int?           // Number of guesses (1-6)
    var timeSeconds: Int?       // Time taken in seconds

    // Echo-specific
    var totalScore: Int?        // Total score (0-1500)
    var roundScores: [Int]?     // Score per round
    var perfectRounds: Int?     // Rounds solved on first attempt
    var totalAttempts: Int?     // Total attempts used
    var roundsSolved: Int?      // Number of rounds solved

    // Crossword-specific
    var completionTimeSeconds: Int?  // Time to complete
    var hintsUsed: Int?              // Number of hints used
    var cellsRevealed: Int?          // Cells revealed via hints

    // Trivia-specific (for future)
    var correctAnswers: Int?
    var totalQuestions: Int?

    init() {}

    // MARK: - Convenience Initializers

    /// Creates metadata for a Wordle game
    static func wordle(guesses: Int, timeSeconds: Int) -> GameMetadata {
        var metadata = GameMetadata()
        metadata.guesses = guesses
        metadata.timeSeconds = timeSeconds
        return metadata
    }

    /// Creates metadata for an Echo game
    static func echo(
        totalScore: Int,
        roundScores: [Int],
        perfectRounds: Int,
        totalAttempts: Int,
        roundsSolved: Int
    ) -> GameMetadata {
        var metadata = GameMetadata()
        metadata.totalScore = totalScore
        metadata.roundScores = roundScores
        metadata.perfectRounds = perfectRounds
        metadata.totalAttempts = totalAttempts
        metadata.roundsSolved = roundsSolved
        return metadata
    }

    /// Creates metadata for a Crossword game
    /// Note: hintsUsed is stored for reference but doesn't affect ranking
    static func crossword(completionTimeSeconds: Int, hintsUsed: Int? = nil) -> GameMetadata {
        var metadata = GameMetadata()
        metadata.completionTimeSeconds = completionTimeSeconds
        metadata.hintsUsed = hintsUsed  // Optional, for display only
        return metadata
    }
}

// MARK: - Local Score
/// A score stored locally on the device.
///
/// This model supports:
/// - Offline storage and retrieval
/// - Sync status tracking for eventual consistency
/// - Game-specific metadata for different game types
/// - Date-based organization for daily leaderboards
///
struct LocalScore: Identifiable, Codable, Equatable {
    let id: UUID
    let gameType: GameType
    let score: Int                      // Computed/display score
    let date: Date                      // Game/puzzle date (not submission time)
    let metadata: GameMetadata          // Game-specific data
    let createdAt: Date                 // When this score was created locally
    var syncStatus: SyncStatus          // Sync state with server
    var remoteId: String?               // Server-assigned ID after sync
    var username: String?               // Username (assigned by server or generated)

    init(
        id: UUID = UUID(),
        gameType: GameType,
        score: Int,
        date: Date,
        metadata: GameMetadata,
        createdAt: Date = Date(),
        syncStatus: SyncStatus = .pending,
        remoteId: String? = nil,
        username: String? = nil
    ) {
        self.id = id
        self.gameType = gameType
        self.score = score
        self.date = date
        self.metadata = metadata
        self.createdAt = createdAt
        self.syncStatus = syncStatus
        self.remoteId = remoteId
        self.username = username
    }

    // MARK: - Date Key

    /// Returns the date formatted as a string key (yyyy-MM-dd)
    var dateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Display Helpers

    /// Returns a display string for the score based on game type
    var scoreDisplay: String {
        switch gameType {
        case .wordle:
            if let guesses = metadata.guesses {
                return "\(guesses)/6"
            }
            return "\(score)"
        case .echo:
            return "\(score) pts"
        case .crossword:
            if let time = metadata.completionTimeSeconds {
                let minutes = time / 60
                let seconds = time % 60
                return String(format: "%d:%02d", minutes, seconds)
            }
            return "\(score)"
        case .trivia:
            if let correct = metadata.correctAnswers, let total = metadata.totalQuestions {
                return "\(correct)/\(total)"
            }
            return "\(score)"
        }
    }
}

// MARK: - Score Calculation Helpers

extension LocalScore {

    /// Calculates a normalized score for Wordle (for ranking purposes)
    /// Lower guesses = higher score, faster time = tiebreaker
    static func calculateWordleScore(guesses: Int, timeSeconds: Int) -> Int {
        let baseScore = (7 - guesses) * 100  // 600 for 1 guess, 100 for 6 guesses
        let timeBonus = max(0, 300 - timeSeconds)  // Up to 300 bonus for speed
        return baseScore + timeBonus
    }

    /// Calculates score for Echo (already computed in game)
    static func calculateEchoScore(roundScores: [Int]) -> Int {
        return roundScores.reduce(0, +)
    }

    /// Calculates score for Crossword (time-based only, lower time = higher score)
    /// Note: Hints do NOT affect score (confirmed decision 2026-02-17)
    static func calculateCrosswordScore(completionTimeSeconds: Int) -> Int {
        // Invert time so higher score = better (for consistent ranking)
        // Max score 3600 for instant completion, 0 for 1 hour+
        return max(0, 3600 - completionTimeSeconds)
    }
}
```

---

### Step 2: Create `LocalLeaderboardService.swift`

**Location:** `TapInApp/TapInApp/Services/LocalLeaderboardService.swift`

**Reasoning:** This service handles all local storage operations for scores. It follows the same singleton pattern as `GameStorage` and `LeaderboardService`. It uses UserDefaults with JSON encoding, consistent with the rest of the codebase.

```swift
//
//  LocalLeaderboardService.swift
//  TapInApp
//
//  MARK: - Local Leaderboard Service
//  Manages local storage of game scores for offline-first leaderboard functionality.
//
//  Architecture:
//  - Singleton pattern (LocalLeaderboardService.shared)
//  - UserDefaults-based persistence with JSON encoding
//  - Organized by game type and date for efficient querying
//
//  Integration Notes:
//  - Call saveScore() from game ViewModels when a game ends
//  - Call getScores() to retrieve scores for display
//  - Call getPendingScores() to get scores that need syncing
//

import Foundation

// MARK: - Local Leaderboard Service

/// Service for managing local storage of game scores.
///
/// Provides functionality for:
/// - Saving scores locally after game completion
/// - Retrieving scores by game type and date
/// - Tracking sync status for offline/online sync
/// - Managing user's score history
///
class LocalLeaderboardService {

    // MARK: - Singleton

    static let shared = LocalLeaderboardService()

    // MARK: - Storage Keys

    private let scoresStorageKey = "localLeaderboardScores"
    private let userStatsStorageKey = "localUserGameStats"

    // MARK: - Properties

    private let defaults = UserDefaults.standard

    // MARK: - Initialization

    private init() {}

    // MARK: - Save Score

    /// Saves a score locally.
    ///
    /// The score is stored with a pending sync status by default.
    /// Call this immediately when a game ends to ensure no data is lost.
    ///
    /// - Parameter score: The LocalScore to save
    ///
    /// Example:
    /// ```swift
    /// let score = LocalScore(
    ///     gameType: .echo,
    ///     score: 1200,
    ///     date: Date(),
    ///     metadata: .echo(totalScore: 1200, roundScores: [300, 300, 300, 200, 100], ...)
    /// )
    /// LocalLeaderboardService.shared.saveScore(score)
    /// ```
    func saveScore(_ score: LocalScore) {
        var allScores = loadAllScores()

        // Check if a score already exists for this game/date combination
        // (prevent duplicate submissions)
        let isDuplicate = allScores.contains { existing in
            existing.gameType == score.gameType &&
            existing.dateKey == score.dateKey &&
            existing.id != score.id
        }

        if isDuplicate {
            print("LocalLeaderboardService: Score already exists for \(score.gameType) on \(score.dateKey)")
            return
        }

        allScores.append(score)
        saveAllScores(allScores)

        // Update user stats
        updateUserStats(for: score)

        print("LocalLeaderboardService: Saved \(score.gameType) score: \(score.score) for \(score.dateKey)")
    }

    // MARK: - Update Score

    /// Updates an existing score (e.g., after sync completes).
    ///
    /// - Parameter score: The updated LocalScore
    func updateScore(_ score: LocalScore) {
        var allScores = loadAllScores()

        if let index = allScores.firstIndex(where: { $0.id == score.id }) {
            allScores[index] = score
            saveAllScores(allScores)
            print("LocalLeaderboardService: Updated score \(score.id)")
        }
    }

    /// Marks a score as synced with the remote server.
    ///
    /// - Parameters:
    ///   - scoreId: The local score ID
    ///   - remoteId: The ID assigned by the server
    ///   - username: The username assigned by the server
    func markAsSynced(_ scoreId: UUID, remoteId: String, username: String? = nil) {
        var allScores = loadAllScores()

        if let index = allScores.firstIndex(where: { $0.id == scoreId }) {
            allScores[index].syncStatus = .synced
            allScores[index].remoteId = remoteId
            if let username = username {
                allScores[index].username = username
            }
            saveAllScores(allScores)
            print("LocalLeaderboardService: Marked score \(scoreId) as synced")
        }
    }

    /// Marks a score sync as failed.
    ///
    /// - Parameter scoreId: The local score ID
    func markAsFailed(_ scoreId: UUID) {
        var allScores = loadAllScores()

        if let index = allScores.firstIndex(where: { $0.id == scoreId }) {
            allScores[index].syncStatus = .failed
            saveAllScores(allScores)
            print("LocalLeaderboardService: Marked score \(scoreId) as failed")
        }
    }

    // MARK: - Retrieve Scores

    /// Gets all scores for a specific game type.
    ///
    /// - Parameter gameType: The type of game
    /// - Returns: Array of LocalScore, sorted by date (most recent first)
    func getScores(for gameType: GameType) -> [LocalScore] {
        return loadAllScores()
            .filter { $0.gameType == gameType }
            .sorted { $0.date > $1.date }
    }

    /// Gets scores for a specific game type and date.
    ///
    /// - Parameters:
    ///   - gameType: The type of game
    ///   - date: The date to filter by
    /// - Returns: Array of LocalScore for that game/date
    func getScores(for gameType: GameType, date: Date) -> [LocalScore] {
        let dateKey = formatDateKey(date)
        return loadAllScores()
            .filter { $0.gameType == gameType && $0.dateKey == dateKey }
    }

    /// Gets the user's score for a specific game and date.
    ///
    /// - Parameters:
    ///   - gameType: The type of game
    ///   - date: The date
    /// - Returns: The user's LocalScore if it exists
    func getUserScore(for gameType: GameType, date: Date) -> LocalScore? {
        return getScores(for: gameType, date: date).first
    }

    /// Checks if the user has a score for a specific game and date.
    ///
    /// - Parameters:
    ///   - gameType: The type of game
    ///   - date: The date
    /// - Returns: True if a score exists
    func hasScore(for gameType: GameType, date: Date) -> Bool {
        return getUserScore(for: gameType, date: date) != nil
    }

    // MARK: - Sync Management

    /// Gets all scores that need to be synced to the server.
    ///
    /// - Returns: Array of LocalScore with pending or failed sync status
    func getPendingScores() -> [LocalScore] {
        return loadAllScores()
            .filter { $0.syncStatus == .pending || $0.syncStatus == .failed }
            .sorted { $0.createdAt < $1.createdAt }  // Oldest first
    }

    /// Checks if there are any scores pending sync.
    ///
    /// - Returns: True if there are pending scores
    var hasPendingScores: Bool {
        return !getPendingScores().isEmpty
    }

    /// Gets the count of pending scores.
    var pendingScoreCount: Int {
        return getPendingScores().count
    }

    // MARK: - User Stats

    /// Gets the user's stats for a specific game type.
    ///
    /// - Parameter gameType: The type of game
    /// - Returns: GameStats for that game type
    func getUserStats(for gameType: GameType) -> GameStats {
        let allStats = loadAllUserStats()
        return allStats[gameType.rawValue] ?? GameStats()
    }

    /// Gets stats for all game types.
    ///
    /// - Returns: Dictionary mapping GameType to GameStats
    func getAllUserStats() -> [GameType: GameStats] {
        let allStats = loadAllUserStats()
        var result: [GameType: GameStats] = [:]
        for gameType in GameType.allCases {
            result[gameType] = allStats[gameType.rawValue] ?? GameStats()
        }
        return result
    }

    // MARK: - Private Helpers

    private func loadAllScores() -> [LocalScore] {
        guard let data = defaults.data(forKey: scoresStorageKey),
              let scores = try? JSONDecoder().decode([LocalScore].self, from: data) else {
            return []
        }
        return scores
    }

    private func saveAllScores(_ scores: [LocalScore]) {
        if let data = try? JSONEncoder().encode(scores) {
            defaults.set(data, forKey: scoresStorageKey)
        }
    }

    private func loadAllUserStats() -> [String: GameStats] {
        guard let data = defaults.data(forKey: userStatsStorageKey),
              let stats = try? JSONDecoder().decode([String: GameStats].self, from: data) else {
            return [:]
        }
        return stats
    }

    private func saveAllUserStats(_ stats: [String: GameStats]) {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: userStatsStorageKey)
        }
    }

    private func updateUserStats(for score: LocalScore) {
        var allStats = loadAllUserStats()
        var stats = allStats[score.gameType.rawValue] ?? GameStats()

        stats.gamesPlayed += 1
        stats.lastPlayedDate = score.date

        // Game-specific stat updates
        switch score.gameType {
        case .wordle:
            if score.score > 0 {  // Won
                stats.wins += 1
                // Update streak logic would go here
            }
        case .echo:
            if let roundsSolved = score.metadata.roundsSolved, roundsSolved == 5 {
                stats.wins += 1
            }
        case .crossword:
            stats.wins += 1  // Completing is a win
        case .trivia:
            if let correct = score.metadata.correctAnswers,
               let total = score.metadata.totalQuestions,
               correct > total / 2 {
                stats.wins += 1
            }
        }

        allStats[score.gameType.rawValue] = stats
        saveAllUserStats(allStats)
    }

    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Debug/Testing

    /// Clears all local score data. Use for testing only.
    func clearAllData() {
        defaults.removeObject(forKey: scoresStorageKey)
        defaults.removeObject(forKey: userStatsStorageKey)
        print("LocalLeaderboardService: Cleared all data")
    }

    /// Gets total count of stored scores.
    var totalScoreCount: Int {
        return loadAllScores().count
    }
}
```

---

### Step 3: Integrate with Echo Game

**Location:** `TapInApp/TapInApp/Games/Echo/ViewModels/EchoGameViewModel.swift`

**Reasoning:** Echo already computes scores but doesn't save them anywhere. We need to add a call to `LocalLeaderboardService` when the game ends. This follows the same pattern Wordle uses with `submitScoreToLeaderboard()`.

**Changes needed:**

1. Add a method `saveScoreToLocalLeaderboard()` that's called when `gameState` becomes `.gameOver`
2. Track whether the score has been saved to prevent duplicates

**Add this code at the end of the `EchoGameViewModel` class (before the closing brace):**

```swift
    // MARK: - Leaderboard Integration

    /// Whether the score has been saved locally
    private var scoreSaved: Bool = false

    /// Saves the final score to the local leaderboard.
    /// Called automatically when game ends.
    func saveScoreToLocalLeaderboard() {
        // Prevent duplicate saves
        guard !scoreSaved else { return }
        guard gameState == .gameOver else { return }

        let metadata = GameMetadata.echo(
            totalScore: score,
            roundScores: roundScores,
            perfectRounds: perfectRounds,
            totalAttempts: totalAttemptsUsed,
            roundsSolved: roundsSolved
        )

        let localScore = LocalScore(
            gameType: .echo,
            score: score,
            date: Date(),  // Echo doesn't have daily puzzles, use current date
            metadata: metadata
        )

        LocalLeaderboardService.shared.saveScore(localScore)
        scoreSaved = true

        print("EchoGameViewModel: Saved score \(score) to local leaderboard")
    }
```

**Also modify the `startGame()` method to reset `scoreSaved`:**

Find this line in `startGame()`:
```swift
attemptsUsedPerRound = []
```

Add after it:
```swift
scoreSaved = false
```

**And modify `advanceToNextRound()` to save score when game ends:**

Find this block:
```swift
func advanceToNextRound() {
    currentRoundIndex += 1
    if currentRoundIndex < totalRounds {
        startRound()
    } else {
        gameState = .gameOver
    }
}
```

Change it to:
```swift
func advanceToNextRound() {
    currentRoundIndex += 1
    if currentRoundIndex < totalRounds {
        startRound()
    } else {
        gameState = .gameOver
        saveScoreToLocalLeaderboard()  // Save score when game ends
    }
}
```

---

### Step 4: Integrate with Crossword Game

**Location:** `TapInApp/TapInApp/Games/MiniCrossWord/ViewModels/CrosswordViewModel.swift`

**Reasoning:** Crossword tracks `elapsedSeconds` but doesn't save to leaderboard. We need to add score saving when the puzzle is completed.

**Add this code at the end of the `CrosswordViewModel` class (before the closing brace):**

```swift
    // MARK: - Leaderboard Integration

    /// Whether the score has been saved locally
    private var scoreSaved: Bool = false

    /// Saves the completion to the local leaderboard.
    /// Called automatically when puzzle is completed.
    /// Note: Only completion time matters for ranking (hints don't affect score)
    func saveScoreToLocalLeaderboard() {
        // Prevent duplicate saves
        guard !scoreSaved else { return }
        guard gameState == .completed else { return }

        // Score based on completion time only (confirmed decision 2026-02-17)
        let calculatedScore = LocalScore.calculateCrosswordScore(
            completionTimeSeconds: elapsedSeconds
        )

        let metadata = GameMetadata.crossword(
            completionTimeSeconds: elapsedSeconds
        )

        let localScore = LocalScore(
            gameType: .crossword,
            score: calculatedScore,
            date: currentDate,
            metadata: metadata
        )

        LocalLeaderboardService.shared.saveScore(localScore)
        scoreSaved = true

        print("CrosswordViewModel: Saved score \(calculatedScore) (time: \(elapsedSeconds)s) to local leaderboard")
    }
```

**Modify `loadPuzzle(for:)` to reset `scoreSaved`:**

Find this line in `loadPuzzle(for:)`:
```swift
elapsedSeconds = 0
```

Add after it:
```swift
scoreSaved = false
```

**Modify `checkCompletion()` to save score:**

Find the end of `checkCompletion()`:
```swift
// Puzzle is complete!
gameState = .completed
stopTimer()
saveCurrentState()
```

Change it to:
```swift
// Puzzle is complete!
gameState = .completed
stopTimer()
saveCurrentState()
saveScoreToLocalLeaderboard()  // Save score when completed
```

---

### Step 5: Update Wordle to Also Save Locally

**Location:** `TapInApp/TapInApp/Games/Wordle/ViewModels/GameViewModel.swift`

**Reasoning:** Wordle already submits to the remote server, but we should also save locally for consistency and offline support. This ensures the local leaderboard has complete data.

**Add this method to the `GameViewModel` class:**

```swift
    /// Saves the score to the local leaderboard.
    /// Called in addition to remote submission for offline support.
    func saveScoreToLocalLeaderboard() {
        // Only save completed games
        guard gameState == .won else { return }

        let calculatedScore = LocalScore.calculateWordleScore(
            guesses: currentRow,
            timeSeconds: gameDurationSeconds
        )

        let metadata = GameMetadata.wordle(
            guesses: currentRow,
            timeSeconds: gameDurationSeconds
        )

        let localScore = LocalScore(
            gameType: .wordle,
            score: calculatedScore,
            date: currentDate,
            metadata: metadata,
            username: assignedUsername  // Will be nil until remote sync
        )

        LocalLeaderboardService.shared.saveScore(localScore)

        print("GameViewModel: Saved Wordle score \(calculatedScore) to local leaderboard")
    }
```

**Modify `submitScoreToLeaderboard()` to also save locally:**

Find the end of the `Task` block in `submitScoreToLeaderboard()`:
```swift
print("Score submitted! Username: \(response.score.username)")
```

Add before the catch block:
```swift
// Also update local score with username
if let existingScore = LocalLeaderboardService.shared.getUserScore(for: .wordle, date: self.currentDate) {
    LocalLeaderboardService.shared.markAsSynced(existingScore.id, remoteId: response.score.id, username: response.score.username)
}
```

**And call `saveScoreToLocalLeaderboard()` at the beginning of `submitScoreToLeaderboard()`:**

Find:
```swift
func submitScoreToLeaderboard() {
    // Only submit for today's game
    guard !isArchiveMode else { return }
```

Add after the guard statements:
```swift
// Save locally first (offline-first)
saveScoreToLocalLeaderboard()
```

---

## Verification Checklist

After implementing Phase 1, verify:

- [ ] `LocalScore.swift` compiles without errors
- [ ] `LocalLeaderboardService.swift` compiles without errors
- [ ] Echo game saves scores when game ends (check console logs)
- [ ] Crossword game saves scores when puzzle completed (check console logs)
- [ ] Wordle game saves scores locally AND remotely
- [ ] Running `LocalLeaderboardService.shared.totalScoreCount` returns correct count
- [ ] Running `LocalLeaderboardService.shared.getScores(for: .echo)` returns saved Echo scores
- [ ] App doesn't crash when offline

---

## Next Steps (Phase 2)

After Phase 1 is complete and tested:

1. Create `LeaderboardView.swift` to display scores
2. Create `LeaderboardViewModel.swift` for view state management
3. Add leaderboard button to `GamesView`
4. Create `LeaderboardRowView` component

---

## Files Created/Modified Summary

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `Models/LocalScore.swift` | Score model with sync status |
| CREATE | `Services/LocalLeaderboardService.swift` | Local storage singleton |
| MODIFY | `Games/Echo/ViewModels/EchoGameViewModel.swift` | Add leaderboard integration |
| MODIFY | `Games/MiniCrossWord/ViewModels/CrosswordViewModel.swift` | Add leaderboard integration |
| MODIFY | `Games/Wordle/ViewModels/GameViewModel.swift` | Add local save alongside remote |
