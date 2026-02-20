# Local Leaderboards Implementation Spec

> **Owner:** Yash Pradhan
> **Last Updated:** 2026-02-20
> **Status:** Phase 4 Complete - Remote Infrastructure Ready

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

---

# Phase 1 Implementation Complete

> **Implemented By:** Claude Code
> **Date Completed:** 2026-02-17
> **Status:** ✅ Complete - Build Verified

---

## What Was Implemented

### 1. LocalScore Model (`Models/LocalScore.swift`)

A comprehensive score model supporting all game types with:

#### Enums
- **`SyncStatus`**: Tracks sync state (`pending`, `synced`, `failed`)

#### Structs
- **`GameMetadata`**: Game-specific data storage
  - Wordle: `guesses`, `timeSeconds`
  - Echo: `totalScore`, `roundScores`, `perfectRounds`, `totalAttempts`, `roundsSolved`
  - Crossword: `completionTimeSeconds`, `hintsUsed`
  - Trivia: `correctAnswers`, `totalQuestions` (future-ready)

- **`LocalScore`**: Main score model
  - Properties: `id`, `gameType`, `score`, `date`, `metadata`, `createdAt`, `syncStatus`, `remoteId`, `username`
  - Computed: `dateKey`, `scoreDisplay`, `secondaryDisplay`
  - Static helpers: `calculateWordleScore()`, `calculateEchoScore()`, `calculateCrosswordScore()`
  - Sorting: `ranksHigherThan()` for leaderboard ordering

#### Key Design Decisions
- Uses `GameType` enum from existing `Game.swift` (no duplication)
- Separate `date` (puzzle date) vs `createdAt` (submission time)
- `metadata` is flexible struct, not dictionary, for type safety
- Score calculation is game-specific but stored as normalized `Int` for sorting

### 2. LocalLeaderboardService (`Services/LocalLeaderboardService.swift`)

Singleton service managing all local score operations:

#### Core Methods
| Method | Purpose |
|--------|---------|
| `saveScore(_:)` | Save score locally, prevents duplicates |
| `updateScore(_:)` | Update existing score |
| `markAsSynced(_:remoteId:username:)` | Mark as synced with server |
| `markAsFailed(_:)` | Mark sync as failed |

#### Query Methods
| Method | Purpose |
|--------|---------|
| `getScores(for:)` | Get all scores for a game type |
| `getScores(for:date:)` | Get scores for game + specific date |
| `getUserScore(for:date:)` | Get user's score for game + date |
| `hasScore(for:date:)` | Check if score exists |
| `getAllScores()` | Get all scores across all games |
| `getBestScore(for:)` | Get highest-ranking score for game |
| `getRecentScores(limit:)` | Get most recent N scores |
| `getScoresFromLastDays(_:gameType:)` | Get scores from last N days |

#### Sync Management
| Property/Method | Purpose |
|-----------------|---------|
| `getPendingScores()` | Get scores needing sync |
| `hasPendingScores` | Check if any pending |
| `pendingScoreCount` | Count of pending scores |

#### User Stats
| Method | Purpose |
|--------|---------|
| `getUserStats(for:)` | Get stats for one game type |
| `getAllUserStats()` | Get stats for all game types |

#### Debug
| Method | Purpose |
|--------|---------|
| `clearAllData()` | Clear all stored data (testing) |
| `totalScoreCount` | Total number of stored scores |
| `printDebugInfo()` | Print debug summary to console |

### 3. Game Integrations

#### Echo Game (`Games/Echo/ViewModels/EchoGameViewModel.swift`)
- Added `scoreSaved: Bool` property to prevent duplicate saves
- Added `saveScoreToLocalLeaderboard()` method
- Score saved automatically when `advanceToNextRound()` triggers game over
- Reset `scoreSaved = false` in `startGame()`

#### MiniCrossword (`Games/MiniCrossWord/ViewModels/CrosswordViewModel.swift`)
- Added `scoreSaved: Bool` property
- Added `saveScoreToLocalLeaderboard()` method
- Score saved automatically in `checkCompletion()` when puzzle completes
- Reset `scoreSaved = false` in `loadPuzzle(for:)`
- Uses completion time only for scoring (hints don't affect rank)

#### Wordle (`Games/Wordle/ViewModels/GameViewModel.swift`)
- Added `localScoreSaved: Bool` property (separate from `scoreSubmitted`)
- Added `saveScoreToLocalLeaderboard()` method
- Saves locally BEFORE remote submission (offline-first)
- Updates local score with server-assigned username after sync
- Marks local score as failed if remote submission fails
- Reset `localScoreSaved = false` in `loadGameForDate(_:)`

---

## How to Test

### Manual Testing

1. **Build and run** the app in simulator or device
2. **Play each game** to completion:
   - **Wordle**: Win a game, check console for "Saved Wordle score X to local leaderboard"
   - **Echo**: Complete all 5 rounds, check console for "Saved score X to local leaderboard"
   - **Crossword**: Complete the puzzle, check console for "Saved score X (time: Xs)"

3. **Verify persistence** by closing and reopening app - scores should persist

### Debug Commands (in Xcode debugger or SwiftUI preview)

```swift
// Check total scores stored
print(LocalLeaderboardService.shared.totalScoreCount)

// Get all Echo scores
let echoScores = LocalLeaderboardService.shared.getScores(for: .echo)
print(echoScores)

// Get user stats for Wordle
let wordleStats = LocalLeaderboardService.shared.getUserStats(for: .wordle)
print("Wordle: \(wordleStats.gamesPlayed) played, \(wordleStats.wins) wins")

// Print full debug info
LocalLeaderboardService.shared.printDebugInfo()

// Check pending sync scores
let pending = LocalLeaderboardService.shared.getPendingScores()
print("Pending sync: \(pending.count)")

// Clear all data (for testing fresh state)
LocalLeaderboardService.shared.clearAllData()
```

### Verification Checklist

- [x] `LocalScore.swift` compiles without errors
- [x] `LocalLeaderboardService.swift` compiles without errors
- [x] Project builds successfully (`xcodebuild` verified)
- [ ] Echo game saves scores when game ends (check console logs)
- [ ] Crossword game saves scores when puzzle completed (check console logs)
- [ ] Wordle game saves scores locally AND remotely
- [ ] `LocalLeaderboardService.shared.totalScoreCount` returns correct count
- [ ] `LocalLeaderboardService.shared.getScores(for: .echo)` returns saved Echo scores
- [ ] App doesn't crash when offline
- [ ] Scores persist after app restart
- [ ] Duplicate scores are prevented (same game + date)

---

## How to Expand

### Adding a New Game (e.g., Trivia)

1. **Add metadata fields** to `GameMetadata` (already prepared for Trivia):
   ```swift
   // In LocalScore.swift - GameMetadata already has:
   var correctAnswers: Int?
   var totalQuestions: Int?
   ```

2. **Add convenience initializer** (already exists):
   ```swift
   static func trivia(correctAnswers: Int, totalQuestions: Int) -> GameMetadata
   ```

3. **Add score calculation** (already exists):
   ```swift
   static func calculateTriviaScore(correctAnswers: Int, totalQuestions: Int, timeSeconds: Int) -> Int
   ```

4. **Update display helpers** in `LocalScore`:
   ```swift
   // scoreDisplay already handles .trivia case
   case .trivia:
       if let correct = metadata.correctAnswers, let total = metadata.totalQuestions {
           return "\(correct)/\(total)"
       }
   ```

5. **Integrate with TriviaViewModel** (when implemented):
   ```swift
   // In TriviaViewModel
   private var scoreSaved: Bool = false

   func saveScoreToLocalLeaderboard() {
       guard !scoreSaved else { return }
       guard gameState == .completed else { return }

       let metadata = GameMetadata.trivia(
           correctAnswers: correctCount,
           totalQuestions: totalQuestions
       )

       let score = LocalScore.calculateTriviaScore(
           correctAnswers: correctCount,
           totalQuestions: totalQuestions,
           timeSeconds: elapsedTime
       )

       let localScore = LocalScore(
           gameType: .trivia,
           score: score,
           date: Date(),
           metadata: metadata
       )

       LocalLeaderboardService.shared.saveScore(localScore)
       scoreSaved = true
   }
   ```

### Adding New Metadata Fields

1. Add optional properties to `GameMetadata`:
   ```swift
   var newField: SomeType?
   ```

2. Update relevant convenience initializer or add new one

3. Update `scoreDisplay` or `secondaryDisplay` if needed for UI

### Adding Remote Sync (Phase 3)

The sync infrastructure is ready:

```swift
// 1. Get pending scores
let pending = LocalLeaderboardService.shared.getPendingScores()

// 2. For each pending score, submit to server
for score in pending {
    do {
        let response = try await RemoteLeaderboardService.shared.submitScore(score)
        // 3. Mark as synced on success
        LocalLeaderboardService.shared.markAsSynced(
            score.id,
            remoteId: response.id,
            username: response.username
        )
    } catch {
        // 4. Mark as failed on error
        LocalLeaderboardService.shared.markAsFailed(score.id)
    }
}
```

### Creating Leaderboard UI (Phase 2)

```swift
// LeaderboardViewModel.swift
@Observable
class LeaderboardViewModel {
    var selectedGameType: GameType = .wordle
    var selectedDate: Date = Date()
    var scores: [LocalScore] = []

    func loadScores() {
        scores = LocalLeaderboardService.shared.getScores(
            for: selectedGameType,
            date: selectedDate
        ).sorted { $0.ranksHigherThan($1) }
    }
}

// LeaderboardView.swift
struct LeaderboardView: View {
    @State private var viewModel = LeaderboardViewModel()

    var body: some View {
        List(viewModel.scores) { score in
            LeaderboardRowView(score: score)
        }
    }
}
```

---

## Potential Issues & Mitigations

### 1. Storage Limits

**Issue**: UserDefaults has a practical limit (~1MB recommended, 4MB hard limit on some platforms).

**Current State**: Each `LocalScore` is approximately 200-500 bytes. At 500 bytes, you could store ~2000 scores before hitting 1MB.

**Mitigation Options**:
- Implement score pruning (delete scores older than N days)
- Migrate to Core Data or SQLite for larger storage
- Archive old scores to file system

```swift
// Example: Prune scores older than 90 days
func pruneOldScores(olderThan days: Int = 90) {
    let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    var scores = loadAllScores()
    scores.removeAll { $0.date < cutoff }
    saveAllScores(scores)
}
```

### 2. Thread Safety

**Issue**: `LocalLeaderboardService` is not explicitly thread-safe.

**Current State**: All game ViewModels use `@Observable` and run on MainActor, so writes happen on main thread. Service reads from UserDefaults which is thread-safe for reads.

**Mitigation**: If background sync is added, wrap mutations in a serial queue:

```swift
private let queue = DispatchQueue(label: "com.tapinapp.leaderboard")

func saveScore(_ score: LocalScore) {
    queue.sync {
        // ... existing code
    }
}
```

### 3. Date Handling

**Issue**: Games like Echo don't have "daily puzzles" - they use current date, which means multiple plays per day would try to save multiple scores.

**Current State**: Duplicate prevention checks `gameType + dateKey`, so only first score of the day is saved.

**Potential Enhancement**: For Echo, consider using a different duplicate key (e.g., allow multiple scores per day) or track "best score of the day":

```swift
// Option: Update if new score is better
func saveOrUpdateBestScore(_ score: LocalScore) {
    if let existing = getUserScore(for: score.gameType, date: score.date) {
        if score.ranksHigherThan(existing) {
            var updated = score
            updated.id = existing.id  // Keep same ID
            updateScore(updated)
        }
    } else {
        saveScore(score)
    }
}
```

### 4. Sync Conflicts

**Issue**: If remote server has a different username than local, or if scores get out of sync.

**Current State**: Wordle updates local username when server responds.

**Potential Enhancement**: Add conflict resolution strategy (server wins, client wins, merge).

### 5. Migration

**Issue**: If `LocalScore` model changes, existing persisted data may fail to decode.

**Mitigation**: Add migration support:

```swift
private func loadAllScores() -> [LocalScore] {
    guard let data = defaults.data(forKey: scoresStorageKey) else { return [] }

    // Try current version first
    if let scores = try? JSONDecoder().decode([LocalScore].self, from: data) {
        return scores
    }

    // Try legacy format and migrate
    if let legacyScores = try? JSONDecoder().decode([LegacyLocalScore].self, from: data) {
        let migrated = legacyScores.map { $0.toCurrentVersion() }
        saveAllScores(migrated)
        return migrated
    }

    return []
}
```

### 6. Memory Usage

**Issue**: Loading all scores into memory for every query.

**Current State**: Acceptable for expected data sizes (< 1000 scores).

**Future Enhancement**: If needed, add pagination or lazy loading:

```swift
func getScores(for gameType: GameType, limit: Int, offset: Int) -> [LocalScore] {
    return Array(loadAllScores()
        .filter { $0.gameType == gameType }
        .sorted { $0.date > $1.date }
        .dropFirst(offset)
        .prefix(limit))
}
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Game ViewModels                          │
├─────────────────┬─────────────────┬─────────────────────────────┤
│ GameViewModel   │ EchoGameViewModel│ CrosswordViewModel         │
│ (Wordle)        │                  │                             │
├─────────────────┴─────────────────┴─────────────────────────────┤
│                    saveScoreToLocalLeaderboard()                 │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   LocalLeaderboardService                        │
│                      (Singleton)                                 │
├─────────────────────────────────────────────────────────────────┤
│  saveScore() → updateUserStats()                                │
│  getScores() / getUserScore() / getBestScore()                  │
│  markAsSynced() / markAsFailed()                                │
│  getPendingScores()                                             │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       UserDefaults                               │
├─────────────────────────────┬───────────────────────────────────┤
│  "localLeaderboardScores"   │  "localUserGameStats"             │
│  [LocalScore] (JSON)        │  [String: GameStats] (JSON)       │
└─────────────────────────────┴───────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         Data Models                              │
├─────────────────────────────────────────────────────────────────┤
│  LocalScore                                                      │
│  ├── id: UUID                                                   │
│  ├── gameType: GameType (.wordle, .echo, .crossword, .trivia)  │
│  ├── score: Int                                                 │
│  ├── date: Date                                                 │
│  ├── metadata: GameMetadata                                     │
│  │   ├── guesses, timeSeconds (Wordle)                         │
│  │   ├── totalScore, roundScores, perfectRounds... (Echo)      │
│  │   └── completionTimeSeconds, hintsUsed (Crossword)          │
│  ├── createdAt: Date                                           │
│  ├── syncStatus: SyncStatus (.pending, .synced, .failed)       │
│  ├── remoteId: String?                                         │
│  └── username: String?                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Related Files Quick Reference

| File | Location | Purpose |
|------|----------|---------|
| `LocalScore.swift` | `Models/` | Score data model |
| `LocalLeaderboardService.swift` | `Services/` | Storage service |
| `Game.swift` | `Models/` | `GameType` enum, `GameStats` struct |
| `GameViewModel.swift` | `Games/Wordle/ViewModels/` | Wordle integration |
| `EchoGameViewModel.swift` | `Games/Echo/ViewModels/` | Echo integration |
| `CrosswordViewModel.swift` | `Games/MiniCrossWord/ViewModels/` | Crossword integration |
| `LeaderboardService.swift` | `Services/` | Remote API (Wordle only, existing) |

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-12 | Initial spec created with architecture decisions |
| 2026-02-17 | Added Phase 1 Implementation Prompt with detailed codebase analysis |
| 2026-02-17 | **Phase 1 Implementation Complete** - Created LocalScore.swift, LocalLeaderboardService.swift, integrated all 3 games |
| 2026-02-17 | **Phase 2 Implementation Complete** - Created LeaderboardView, LeaderboardViewModel, UI components, integrated into GamesView |

---

# Phase 2 Implementation Complete

> **Implemented By:** Claude Code
> **Date Completed:** 2026-02-17
> **Status:** ✅ Complete - Build Verified

---

## What Was Implemented (Phase 2)

### 1. LeaderboardViewModel (`ViewModels/LeaderboardViewModel.swift`)

Central ViewModel managing leaderboard state:

#### Properties
- `selectedGameType: GameType` - Current game filter
- `selectedDate: Date` - Date for viewing scores
- `showingDatePicker: Bool` - Date picker visibility
- `scores: [LocalScore]` - Scores for current selection
- `userStats: GameStats` - User stats for selected game
- `bestScore: LocalScore?` - All-time best score

#### Methods
| Method | Purpose |
|--------|---------|
| `loadData()` | Loads all data for current selection |
| `selectGameType(_:)` | Changes game type and reloads |
| `selectDate(_:)` | Changes date and reloads |
| `previousDay() / nextDay()` | Date navigation |
| `goToToday()` | Jump to today's scores |
| `rank(for:)` | Get rank for a score |
| `refresh()` | Pull-to-refresh handler |

### 2. LeaderboardView (`Views/LeaderboardView.swift`)

Main leaderboard view with:
- Navigation header with dismiss button
- Game type selector pills
- Date navigation (prev/next/today)
- Stats summary boxes (Best Score, Games Played, Win Rate)
- Scrollable scores list with pull-to-refresh
- Empty state for no scores
- Date picker sheet

### 3. LeaderboardRowView (`Components/LeaderboardRowView.swift`)

Individual score entry row showing:
- Rank indicator (medals for top 3: 🥇🥈🥉)
- Username with "YOU" badge for current user
- Secondary info (time, rounds, etc.)
- Score display with game-appropriate label
- Highlighted styling for user's own scores

### 4. LeaderboardHeaderView (`Components/LeaderboardHeaderView.swift`)

Header components including:
- **GameTypePill**: Selectable game type buttons
- **Date Navigator**: Prev/Next day buttons with calendar
- **LeaderboardStatBox**: Stats display boxes

### 5. GamesView Integration

- Added trophy button in header (next to streak badge)
- Added `fullScreenCover` for LeaderboardView
- Updated `GamesViewModel` with `showingLeaderboard`, `showLeaderboard()`, `dismissLeaderboard()`

---

## Phase 2 UI Components

```
┌─────────────────────────────────────────────────────────────────┐
│  GamesView                                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Aggie Games        [🏆] [7 streak]                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                     │
│                            ▼ (tap trophy)                       │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  LeaderboardView (fullScreenCover)                              │
├─────────────────────────────────────────────────────────────────┤
│  [X]          Leaderboard                                       │
│               Aggie Wordle                                      │
├─────────────────────────────────────────────────────────────────┤
│  [Wordle] [Echo] [Crossword]        ← GameTypePills             │
├─────────────────────────────────────────────────────────────────┤
│  [<]  Today  [>]               [Today]  ← DateNavigator         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌─────────┐                           │
│  │Your Best│ │Games    │ │Win Rate │    ← LeaderboardStatBoxes │
│  │  3/6    │ │  42     │ │  83%    │                           │
│  └─────────┘ └─────────┘ └─────────┘                           │
├─────────────────────────────────────────────────────────────────┤
│  Rankings                           1 player                    │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 🥇  You         [YOU]                          3/6     │   │
│  │     0:45                                       guesses │   │
│  └─────────────────────────────────────────────────────────┘   │
│                         ← LeaderboardRowView                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## How to Test Phase 2

### Manual Testing

1. **Build and run** the app in simulator
2. **Navigate to Games tab**
3. **Tap the trophy button** (🏆) in the header
4. **LeaderboardView should open** as full screen cover
5. **Test game type switching** - tap Wordle, Echo, Crossword pills
6. **Test date navigation** - tap < > arrows, tap date for picker
7. **Test Today button** - navigate to past day, tap "Today"
8. **Test dismiss** - tap X button to close
9. **Verify scores display** - play a game, check leaderboard shows it

### Verification Checklist

- [x] LeaderboardView opens from GamesView trophy button
- [x] Game type pills switch between games
- [x] Date navigation works (prev/next/today)
- [x] Stats boxes show correct data
- [x] Scores list displays with proper formatting
- [x] Medal emojis for top 3
- [x] "YOU" badge on user's scores
- [x] Empty state shows when no scores
- [x] Date picker sheet works
- [x] Dismiss button closes the view
- [x] Build succeeds with no errors

---

## Files Created/Modified (Phase 2)

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `ViewModels/LeaderboardViewModel.swift` | Leaderboard state management |
| CREATE | `Views/LeaderboardView.swift` | Main leaderboard UI |
| CREATE | `Components/LeaderboardRowView.swift` | Score row component |
| CREATE | `Components/LeaderboardHeaderView.swift` | Header components |
| MODIFY | `Views/GamesView.swift` | Added trophy button, fullScreenCover |
| MODIFY | `ViewModels/GamesViewModel.swift` | Added leaderboard navigation |

---

## Next Steps (Phase 3)

After Phase 2 is complete and tested:

1. **Game Over Leaderboard** - Auto-show leaderboard when game ends
2. **Username Generator** - Random display names (e.g., "SwiftFalcon")
3. **Per-Game Leaderboard Buttons** - Quick access from game cards
4. **Remote Sync** - (Future) Backend for multi-user leaderboards

---

# Phase 3 Implementation Prompt

> **Purpose:** This section provides detailed implementation instructions for Phase 3: Game Over Leaderboard Integration. An AI assistant or developer can follow this prompt to implement the feature correctly.
> **Last Updated:** 2026-02-20

---

## Phase 3 Overview

### Goals
1. **Auto-show leaderboard on game completion** - When any game ends, display a leaderboard overlay
2. **Random display names** - Generate fun usernames like "SwiftFalcon" (400 unique per day)
3. **Top 5 + user rank** - Show top 5 scores; if user not in top 5, show their rank as 6th entry
4. **Per-game leaderboard buttons** - Add leaderboard access next to each game in GamesView

### Key Decisions (Confirmed 2026-02-20)
| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Score handling** | Ignore duplicates (first score only) | Simplicity; replacement logic deferred to future version |
| **Display name** | Random generated (e.g., "SwiftFalcon") | Privacy; fun factor |
| **Name uniqueness** | 400 unique per day (20 adj × 20 nouns) | Sufficient for daily active users |
| **Replay same day** | Not allowed | Matches current daily puzzle behavior |
| **Leaderboard trigger** | Auto-appear on game over | No extra tap required |
| **Data source** | Local only (single device, single user) | Remote sync is future phase |

---

## Architecture

### New Components

```
┌─────────────────────────────────────────────────────────────────┐
│                      Game Over Flow                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Game Ends → Save Score → Generate Username → Show Leaderboard  │
│                                                                  │
│  ┌─────────────┐    ┌──────────────────┐    ┌────────────────┐  │
│  │ GameViewModel│───▶│LocalLeaderboard  │───▶│GameOverLeader- │  │
│  │ (any game)  │    │Service           │    │boardView       │  │
│  └─────────────┘    └──────────────────┘    └────────────────┘  │
│                              │                       │           │
│                              ▼                       ▼           │
│                     ┌──────────────────┐    ┌────────────────┐  │
│                     │UsernameGenerator │    │LeaderboardRow  │  │
│                     │Service           │    │View (reused)   │  │
│                     └──────────────────┘    └────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `UsernameGenerator.swift` | `Services/` | Generate random display names |
| `GameOverLeaderboardView.swift` | `Components/` | Leaderboard overlay for game completion |
| `GameOverLeaderboardViewModel.swift` | `ViewModels/` | State management for game over leaderboard |

### Files to Modify

| File | Change |
|------|--------|
| `LocalLeaderboardService.swift` | Integrate username generation on save, add ranking helpers |
| `EchoGameView.swift` | Replace game over phase with GameOverLeaderboardView |
| `MiniCrosswordGameView.swift` | Replace CrosswordCompletionView with GameOverLeaderboardView |
| `WordleGameView.swift` / `GameOverView.swift` | Integrate GameOverLeaderboardView |
| `GamesView.swift` | Add per-game leaderboard buttons |
| `GameRowCard` | Add trophy button |

---

## Step 1: Create UsernameGenerator Service

**Location:** `TapInApp/TapInApp/Services/UsernameGenerator.swift`

**Purpose:** Generates random, fun display names like "SwiftFalcon" or "BraveTiger". Designed to produce up to 400 unique names per day (20 adjectives × 20 nouns).

### Requirements
- Deterministic: Same user + same date = same username
- Fun and memorable names
- 20 adjectives × 20 nouns = 400 unique combinations
- Persists generated name for the day in UserDefaults

### Implementation

```swift
//
//  UsernameGenerator.swift
//  TapInApp
//
//  MARK: - Username Generator Service
//  Generates random display names for leaderboard entries.
//  Names are deterministic per user per day (same user gets same name each day).
//

import Foundation

/// Service for generating random display names for leaderboard entries.
///
/// Generates names in the format "AdjectiveNoun" (e.g., "SwiftFalcon", "BraveTiger").
/// Names are deterministic: the same user on the same day always gets the same name.
/// Supports up to 400 unique names per day (20 adjectives × 20 nouns).
///
class UsernameGenerator {

    // MARK: - Singleton

    static let shared = UsernameGenerator()

    // MARK: - Storage Key

    private let storageKeyPrefix = "generatedUsername_"

    // MARK: - Word Lists (20 × 20 = 400 combinations)

    private let adjectives: [String] = [
        "Swift", "Brave", "Clever", "Bold", "Mighty",
        "Noble", "Agile", "Fierce", "Cosmic", "Golden",
        "Silver", "Crystal", "Thunder", "Shadow", "Blazing",
        "Rapid", "Lucky", "Mystic", "Royal", "Epic"
    ]

    private let nouns: [String] = [
        "Falcon", "Tiger", "Phoenix", "Dragon", "Eagle",
        "Wolf", "Panther", "Hawk", "Lion", "Bear",
        "Fox", "Raven", "Shark", "Cobra", "Mustang",
        "Jaguar", "Viper", "Griffin", "Pegasus", "Titan"
    ]

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Gets or generates a display name for the current user for today.
    ///
    /// If a name was already generated today, returns the cached name.
    /// Otherwise, generates a new deterministic name based on user ID and date.
    ///
    /// - Returns: A display name like "SwiftFalcon"
    func getDisplayName() -> String {
        let dateKey = formatDateKey(Date())
        let storageKey = storageKeyPrefix + dateKey

        // Check if we already have a name for today
        if let cachedName = UserDefaults.standard.string(forKey: storageKey) {
            return cachedName
        }

        // Generate a new name
        let name = generateName(for: Date())

        // Cache it for today
        UserDefaults.standard.set(name, forKey: storageKey)

        // Clean up old cached names (keep only last 7 days)
        cleanupOldNames()

        return name
    }

    /// Gets the display name for a specific date.
    ///
    /// Useful for displaying historical scores with consistent names.
    ///
    /// - Parameter date: The date to get the name for
    /// - Returns: A display name
    func getDisplayName(for date: Date) -> String {
        let dateKey = formatDateKey(date)
        let storageKey = storageKeyPrefix + dateKey

        if let cachedName = UserDefaults.standard.string(forKey: storageKey) {
            return cachedName
        }

        // For past dates, generate deterministically but don't cache
        return generateName(for: date)
    }

    /// Generates a preview name (not cached).
    ///
    /// - Returns: Today's display name without caching
    func previewTodaysName() -> String {
        return generateName(for: Date())
    }

    // MARK: - Private Methods

    /// Generates a deterministic name based on date and device ID.
    private func generateName(for date: Date) -> String {
        // Create a seed from date + device identifier
        let dateString = formatDateKey(date)
        let deviceId = getDeviceIdentifier()
        let seed = "\(dateString)_\(deviceId)"

        // Use hash to get deterministic indices
        let hash = abs(seed.hashValue)
        let adjIndex = hash % adjectives.count
        let nounIndex = (hash / adjectives.count) % nouns.count

        return adjectives[adjIndex] + nouns[nounIndex]
    }

    /// Gets a stable device identifier.
    private func getDeviceIdentifier() -> String {
        let key = "deviceIdentifier"

        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }

        // Generate new identifier
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    /// Formats a date as yyyy-MM-dd.
    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Cleans up cached names older than 7 days.
    private func cleanupOldNames() {
        let calendar = Calendar.current
        let defaults = UserDefaults.standard

        let allKeys = defaults.dictionaryRepresentation().keys
        let usernameKeys = allKeys.filter { $0.hasPrefix(storageKeyPrefix) }

        let cutoffDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cutoffKey = storageKeyPrefix + formatDateKey(cutoffDate)

        for key in usernameKeys {
            if key < cutoffKey {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
```

---

## Step 2: Update LocalLeaderboardService

**Location:** `TapInApp/TapInApp/Services/LocalLeaderboardService.swift`

**Changes needed:**
1. Auto-assign display name when saving scores (if not already set)
2. Add helper method for getting leaderboard data with user rank

### Modify `saveScore` Method

Find the `saveScore` method and update it to auto-assign username:

```swift
@discardableResult
func saveScore(_ score: LocalScore) -> Bool {
    var allScores = loadAllScores()

    // Check if a score already exists for this game/date combination
    let isDuplicate = allScores.contains { existing in
        existing.gameType == score.gameType &&
        existing.dateKey == score.dateKey
    }

    if isDuplicate {
        print("LocalLeaderboardService: Score already exists for \(score.gameType.rawValue) on \(score.dateKey)")
        return false
    }

    // Auto-assign display name if not set
    var scoreToSave = score
    if scoreToSave.username == nil {
        scoreToSave.username = UsernameGenerator.shared.getDisplayName(for: score.date)
    }

    allScores.append(scoreToSave)
    saveAllScores(allScores)

    // Update user stats
    updateUserStats(for: scoreToSave)

    print("LocalLeaderboardService: Saved \(scoreToSave.gameType.rawValue) score: \(scoreToSave.score) for \(scoreToSave.dateKey) as \(scoreToSave.username ?? "unknown")")
    return true
}
```

### Add Helper Method for Leaderboard Data

Add this method to `LocalLeaderboardService`:

```swift
/// Gets the top N scores for a game and date, plus the user's score if not in top N.
///
/// - Parameters:
///   - gameType: The game type
///   - date: The date
///   - limit: Number of top scores to return (default 5)
/// - Returns: Tuple of (topScores, userScoreIfNotInTop, userRank)
func getLeaderboardData(for gameType: GameType, date: Date, limit: Int = 5) -> (topScores: [LocalScore], userScoreIfNotInTop: LocalScore?, userRank: Int?) {
    let allScores = getScores(for: gameType, date: date)
        .sorted { $0.ranksHigherThan($1) }

    let topScores = Array(allScores.prefix(limit))
    let userScore = getUserScore(for: gameType, date: date)

    var userScoreIfNotInTop: LocalScore? = nil
    var userRank: Int? = nil

    if let userScore = userScore {
        if let index = allScores.firstIndex(where: { $0.id == userScore.id }) {
            userRank = index + 1
            if index >= limit {
                userScoreIfNotInTop = userScore
            }
        }
    }

    return (topScores, userScoreIfNotInTop, userRank)
}
```

---

## Step 3: Create GameOverLeaderboardViewModel

**Location:** `TapInApp/TapInApp/ViewModels/GameOverLeaderboardViewModel.swift`

```swift
//
//  GameOverLeaderboardViewModel.swift
//  TapInApp
//
//  MARK: - Game Over Leaderboard ViewModel
//  Manages state for the leaderboard shown after game completion.
//

import Foundation
import SwiftUI

/// ViewModel for the game over leaderboard overlay.
@Observable
class GameOverLeaderboardViewModel {

    // MARK: - Properties

    let gameType: GameType
    let gameDate: Date
    let userScore: LocalScore?

    var topScores: [LocalScore] = []
    var userScoreIfNotInTop: LocalScore? = nil
    var userRank: Int? = nil
    var displayName: String = ""
    var totalPlayers: Int = 0
    var isLoading: Bool = true

    // MARK: - Computed Properties

    var isUserInTop5: Bool {
        guard let rank = userRank else { return false }
        return rank <= 5
    }

    var gameDisplayName: String {
        switch gameType {
        case .wordle: return "Aggie Wordle"
        case .echo: return "Echo"
        case .crossword: return "Mini Crossword"
        case .trivia: return "Trivia"
        }
    }

    // MARK: - Initialization

    init(gameType: GameType, gameDate: Date = Date(), userScore: LocalScore? = nil) {
        self.gameType = gameType
        self.gameDate = gameDate
        self.userScore = userScore
        loadData()
    }

    // MARK: - Methods

    func loadData() {
        isLoading = true
        displayName = UsernameGenerator.shared.getDisplayName(for: gameDate)

        let data = LocalLeaderboardService.shared.getLeaderboardData(
            for: gameType,
            date: gameDate,
            limit: 5
        )

        topScores = data.topScores
        userScoreIfNotInTop = data.userScoreIfNotInTop
        userRank = data.userRank
        totalPlayers = LocalLeaderboardService.shared.getScores(for: gameType, date: gameDate).count

        isLoading = false
    }

    func rank(for score: LocalScore) -> Int {
        if let index = topScores.firstIndex(where: { $0.id == score.id }) {
            return index + 1
        }
        return userRank ?? 0
    }

    func isUserScore(_ score: LocalScore) -> Bool {
        return score.id == userScore?.id
    }
}
```

---

## Step 4: Create GameOverLeaderboardView

**Location:** `TapInApp/TapInApp/Components/GameOverLeaderboardView.swift`

```swift
//
//  GameOverLeaderboardView.swift
//  TapInApp
//
//  MARK: - Game Over Leaderboard View
//  Overlay shown after game completion displaying leaderboard and user info.
//

import SwiftUI

struct GameOverLeaderboardView: View {

    @State private var viewModel: GameOverLeaderboardViewModel

    let resultTitle: String
    let resultSubtitle: String
    let resultIcon: String
    let resultColor: Color

    let onDismiss: () -> Void
    let onBack: () -> Void

    @Environment(\.colorScheme) var colorScheme

    init(
        gameType: GameType,
        gameDate: Date = Date(),
        userScore: LocalScore? = nil,
        resultTitle: String,
        resultSubtitle: String,
        resultIcon: String = "trophy.fill",
        resultColor: Color = .ucdGold,
        onDismiss: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self._viewModel = State(initialValue: GameOverLeaderboardViewModel(
            gameType: gameType,
            gameDate: gameDate,
            userScore: userScore
        ))
        self.resultTitle = resultTitle
        self.resultSubtitle = resultSubtitle
        self.resultIcon = resultIcon
        self.resultColor = resultColor
        self.onDismiss = onDismiss
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    resultHeader
                    leaderboardSection
                    userInfoSection
                    actionButtons
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(colorScheme == .dark ? Color(hex: "#1a1a2e") : .white)
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 48)
            }
        }
    }

    private var resultHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: resultIcon)
                .font(.system(size: 48))
                .foregroundColor(resultColor)

            Text(resultTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)

            Text(resultSubtitle)
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var leaderboardSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.ucdGold)
                Text("Today's Leaderboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)

                Spacer()

                if viewModel.totalPlayers > 0 {
                    Text("\(viewModel.totalPlayers) player\(viewModel.totalPlayers == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .padding(.vertical, 20)
            } else if viewModel.topScores.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.topScores) { score in
                        LeaderboardRowView(
                            score: score,
                            rank: viewModel.rank(for: score),
                            isCurrentUser: viewModel.isUserScore(score),
                            colorScheme: colorScheme
                        )
                    }

                    if let userScore = viewModel.userScoreIfNotInTop,
                       let userRank = viewModel.userRank {
                        Divider().padding(.vertical, 4)

                        LeaderboardRowView(
                            score: userScore,
                            rank: userRank,
                            isCurrentUser: true,
                            colorScheme: colorScheme
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No scores yet today")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
            Text("Be the first to set a score!")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
        }
        .padding(.vertical, 16)
    }

    private var userInfoSection: some View {
        VStack(spacing: 8) {
            Text("Your display name is:")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)

            Text(viewModel.displayName)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color.ucdGold)

            if let rank = viewModel.userRank {
                Text("You ranked #\(rank) out of \(viewModel.totalPlayers)")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.ucdGold.opacity(0.15))
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onDismiss) {
                Text("View \(viewModel.gameDisplayName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.ucdBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.ucdGold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: onBack) {
                Text("Back to Games")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.3) : Color.ucdBlue.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
}

#Preview {
    GameOverLeaderboardView(
        gameType: .wordle,
        resultTitle: "Puzzle Complete!",
        resultSubtitle: "Solved in 4 guesses",
        onDismiss: {},
        onBack: {}
    )
}
```

---

## Step 5: Integrate with Echo Game

**Location:** `TapInApp/TapInApp/Games/Echo/Views/EchoGameView.swift`

**Find the `gameOverPhase` section (case `.gameOver:`) and replace with:**

```swift
case .gameOver:
    GameOverLeaderboardView(
        gameType: .echo,
        gameDate: Date(),
        userScore: LocalLeaderboardService.shared.getUserScore(for: .echo, date: Date()),
        resultTitle: viewModel.roundsSolved == 5 ? "Perfect Game!" : "Game Complete",
        resultSubtitle: "\(viewModel.score) points • \(viewModel.roundsSolved)/5 rounds solved",
        resultIcon: viewModel.roundsSolved == 5 ? "star.fill" : "checkmark.circle.fill",
        resultColor: viewModel.roundsSolved == 5 ? .ucdGold : .wordleGreen,
        onDismiss: {
            // Stay in game but dismiss overlay if needed
        },
        onBack: onDismiss
    )
```

---

## Step 6: Integrate with MiniCrossword Game

**Location:** `TapInApp/TapInApp/Games/MiniCrossWord/Views/MiniCrosswordGameView.swift`

**Find where `CrosswordCompletionView` is shown and replace:**

```swift
// Find:
if viewModel.gameState == .completed && showCompletionOverlay {
    CrosswordCompletionView(...)
}

// Replace with:
if viewModel.gameState == .completed && showCompletionOverlay {
    GameOverLeaderboardView(
        gameType: .crossword,
        gameDate: viewModel.currentDate,
        userScore: LocalLeaderboardService.shared.getUserScore(for: .crossword, date: viewModel.currentDate),
        resultTitle: "Puzzle Complete!",
        resultSubtitle: "Solved in \(formatTime(viewModel.elapsedSeconds))",
        resultIcon: "trophy.fill",
        resultColor: .ucdGold,
        onDismiss: { showCompletionOverlay = false },
        onBack: onDismiss
    )
}

// Add helper if not present:
private func formatTime(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let secs = seconds % 60
    return String(format: "%d:%02d", minutes, secs)
}
```

---

## Step 7: Integrate with Wordle Game

**Location:** `TapInApp/TapInApp/Games/Wordle/Views/` (wherever `GameOverView` is presented)

**Replace GameOverView with GameOverLeaderboardView:**

```swift
// Find the GameOverView presentation and replace with:
if viewModel.showGameOver {
    GameOverLeaderboardView(
        gameType: .wordle,
        gameDate: viewModel.currentDate,
        userScore: LocalLeaderboardService.shared.getUserScore(for: .wordle, date: viewModel.currentDate),
        resultTitle: viewModel.gameState == .won ? "Congratulations!" : "Game Over",
        resultSubtitle: viewModel.gameState == .won
            ? "Solved in \(viewModel.currentRow) guess\(viewModel.currentRow == 1 ? "" : "es")"
            : "The word was \(viewModel.targetWord)",
        resultIcon: viewModel.gameState == .won ? "checkmark.circle.fill" : "xmark.circle.fill",
        resultColor: viewModel.gameState == .won ? .wordleGreen : .ucdGold,
        onDismiss: { viewModel.showGameOver = false },
        onBack: onDismiss
    )
}
```

---

## Step 8: Add Per-Game Leaderboard Buttons

**Location:** `TapInApp/TapInApp/Views/GamesView.swift`

### Modify GameRowCard to include leaderboard button:

```swift
struct GameRowCard: View {
    let game: Game
    let colorScheme: ColorScheme
    let onPlay: () -> Void
    let onLeaderboard: () -> Void  // ADD THIS

    var body: some View {
        HStack(spacing: 16) {
            // ... existing icon code ...

            VStack(alignment: .leading, spacing: 4) {
                // ... existing name and description ...
            }

            Spacer()

            // ADD: Leaderboard button
            Button(action: onLeaderboard) {
                Image(systemName: "trophy")
                    .font(.system(size: 16))
                    .foregroundColor(Color.ucdGold)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.ucdGold.opacity(0.15))
                    )
            }
            .buttonStyle(PlainButtonStyle())

            Image(systemName: "chevron.right")
            // ... rest of styling ...
        }
    }
}
```

### Update GamesView to handle per-game leaderboard:

```swift
// Add state in GamesView
@State private var leaderboardGameType: GameType? = nil

// Add sheet presentation
.sheet(item: $leaderboardGameType) { gameType in
    LeaderboardView(
        initialGameType: gameType,
        onDismiss: { leaderboardGameType = nil }
    )
}

// Update GameRowCard usage
ForEach(viewModel.availableGames) { game in
    GameRowCard(
        game: game,
        colorScheme: colorScheme,
        onPlay: { viewModel.startGame(game) },
        onLeaderboard: { leaderboardGameType = game.type }
    )
}
```

### Make GameType Identifiable (if not already):

```swift
// In Game.swift or Models
extension GameType: Identifiable {
    var id: String { rawValue }
}
```

---

## Verification Checklist

After implementing Phase 3, verify:

- [ ] `UsernameGenerator.swift` compiles and generates names like "SwiftFalcon"
- [ ] `UsernameGenerator.shared.getDisplayName()` returns consistent name for same day
- [ ] `LocalLeaderboardService.saveScore()` auto-assigns username
- [ ] `GameOverLeaderboardView` displays correctly
- [ ] Echo game shows leaderboard on game over
- [ ] Crossword game shows leaderboard on completion
- [ ] Wordle game shows leaderboard on win/loss
- [ ] Leaderboard shows "Your display name is: [name]"
- [ ] If user not in top 5, 6th row shows their rank
- [ ] Per-game leaderboard button appears next to each game
- [ ] Build succeeds with no errors

---

## Files Created/Modified Summary (Phase 3)

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `Services/UsernameGenerator.swift` | Random display name generation |
| CREATE | `ViewModels/GameOverLeaderboardViewModel.swift` | Game over leaderboard state |
| CREATE | `Components/GameOverLeaderboardView.swift` | Game over leaderboard UI |
| MODIFY | `Services/LocalLeaderboardService.swift` | Auto-assign username, add ranking helpers |
| MODIFY | `Games/Echo/Views/EchoGameView.swift` | Integrate GameOverLeaderboardView |
| MODIFY | `Games/MiniCrossWord/Views/MiniCrosswordGameView.swift` | Replace CrosswordCompletionView |
| MODIFY | `Games/Wordle/Views/*` | Integrate GameOverLeaderboardView |
| MODIFY | `Views/GamesView.swift` | Add per-game leaderboard buttons |

---

## Future Considerations (Phase 5+)

### Score Replacement Feature
When ready to implement "most recent score replaces old":

1. Add `saveOrReplaceScore()` method to `LocalLeaderboardService`
2. Update game ViewModels to call replacement method
3. Add "Play Again" button to GameOverLeaderboardView

### Friends & Social Features
1. Add friends list with friend-only leaderboards
2. Implement score sharing to social media
3. Add notifications for when friends beat your score

---

## Phase 4: Remote Server Infrastructure

> **Status:** ✅ IMPLEMENTED (2026-02-20)
> **Purpose:** Enable remote sync of leaderboard scores across users when authentication is ready.

---

### Overview

Phase 4 adds the infrastructure for syncing local leaderboard scores to a remote server. This enables:
- Multi-user leaderboards (global rankings)
- Score persistence across devices
- Future integration with user authentication

The implementation follows an **offline-first architecture**: scores are always saved locally first, then synced to the server when available.

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Primary data source** | Local (LocalLeaderboardService) | Offline-first; always save locally first |
| **Sync trigger** | After local save | Immediate sync attempt, with retry on failure |
| **Remote toggle** | `APIConfig.useLocalOnlyLeaderboards` | Easy to enable/disable remote sync |
| **Backend** | Flask (tapin-backend) | Reuses existing backend infrastructure |
| **Storage** | In-memory (MVP) | Future: Firestore for persistence |

---

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Remote Sync Architecture                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐     ┌──────────────────┐     ┌────────────────────┐  │
│  │ Game         │────▶│ LocalLeaderboard │────▶│ LeaderboardSync    │  │
│  │ ViewModel    │     │ Service          │     │ Service            │  │
│  └──────────────┘     └──────────────────┘     └────────────────────┘  │
│                              │                          │               │
│                              │ Save Score               │ Sync          │
│                              ▼                          ▼               │
│                     ┌──────────────────┐     ┌────────────────────┐    │
│                     │ UserDefaults     │     │ RemoteLeaderboard  │    │
│                     │ (Local Storage)  │     │ Service            │    │
│                     └──────────────────┘     └────────────────────┘    │
│                                                         │               │
│                                                         │ HTTP          │
│                                                         ▼               │
│                                              ┌────────────────────┐    │
│                                              │ tapin-backend      │    │
│                                              │ (Flask Server)     │    │
│                                              └────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### Files Created

| File | Location | Purpose |
|------|----------|---------|
| `RemoteLeaderboardService.swift` | `Services/` | HTTP client for remote leaderboard API |
| `LeaderboardSyncService.swift` | `Services/` | Orchestrates local-to-remote sync |
| `unified_leaderboard_service.py` | `tapin-backend/services/` | Backend service for all game types |

### Files Modified

| File | Changes |
|------|---------|
| `APIConfig.swift` | Added leaderboard endpoints, auth placeholders, sync settings |
| `LocalScore.swift` | Added `userId`, `deviceId`, `isAuthenticated` auth fields |
| `models.py` | Added `GameScore`, `UnifiedLeaderboardEntry` models |
| `api/leaderboard.py` | Added unified endpoints for all game types |
| `app.py` | Updated endpoint documentation |

---

### iOS Client Implementation

#### APIConfig.swift Additions

```swift
// MARK: - Leaderboard Endpoints

/// Leaderboard API base path
static var leaderboardBaseURL: String { "\(baseURL)/api/leaderboard" }

/// POST - Submit a score for any game type
/// Request: { game_type, score, date, username?, metadata }
static var submitScoreURL: String { "\(leaderboardBaseURL)/score" }

/// GET - Get leaderboard for a specific game and date
/// Path: /api/leaderboard/{game_type}/{date}?limit=5
static func leaderboardURL(gameType: String, date: String) -> String {
    "\(leaderboardBaseURL)/\(gameType)/\(date)"
}

/// POST - Sync multiple scores at once (batch upload)
/// Request: { scores: [...] }
static var syncScoresURL: String { "\(leaderboardBaseURL)/sync" }

/// GET - Leaderboard health check
static var leaderboardHealthURL: String { "\(leaderboardBaseURL)/health" }

// MARK: - Auth Endpoints (Placeholder for friend's implementation)

static var authBaseURL: String { "\(baseURL)/api/auth" }
static var loginURL: String { "\(authBaseURL)/login" }
static var registerURL: String { "\(authBaseURL)/register" }
static var profileURL: String { "\(authBaseURL)/profile" }

// MARK: - Mode Toggles

/// Set to true to use local-only leaderboards (no remote sync)
/// Set to false when backend is ready
static let useLocalOnlyLeaderboards = true

// MARK: - Sync Settings

/// How often to attempt background sync (in seconds)
static let syncIntervalSeconds: TimeInterval = 60

/// Maximum number of scores to sync in a single batch
static let syncBatchSize = 50

/// Number of retry attempts for failed syncs
static let syncMaxRetries = 3
```

#### RemoteLeaderboardService.swift

Unified HTTP client for remote leaderboard API:

```swift
@MainActor
class RemoteLeaderboardService: ObservableObject {
    static let shared = RemoteLeaderboardService()

    @Published var isLoading: Bool = false
    @Published var lastError: AppError?

    /// Submits a score to the remote leaderboard
    func submitScore(_ score: LocalScore) async throws -> RemoteScoreResponse

    /// Fetches leaderboard for a specific game and date
    func fetchLeaderboard(gameType: GameType, date: String, limit: Int = 5)
        async throws -> [RemoteLeaderboardEntry]

    /// Batch syncs multiple scores
    func syncScores(_ scores: [LocalScore]) async throws -> RemoteSyncResponse

    /// Health check
    func isServerHealthy() async -> Bool
}
```

#### LeaderboardSyncService.swift

Orchestrates sync between local and remote:

```swift
@MainActor
class LeaderboardSyncService: ObservableObject {
    static let shared = LeaderboardSyncService()

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var pendingCount: Int = 0

    /// Syncs a single score after local save
    @discardableResult
    func syncScore(_ score: LocalScore) async -> Bool

    /// Syncs all pending scores (batch)
    @discardableResult
    func syncPendingScores() async -> Int

    /// Saves locally and attempts remote sync
    @discardableResult
    func saveAndSync(_ score: LocalScore) async -> Bool

    /// Starts periodic background sync
    func startBackgroundSync()

    /// Stops background sync
    func stopBackgroundSync()

    /// Checks if remote sync is available
    func isRemoteSyncAvailable() async -> Bool
}
```

#### LocalScore.swift Auth Fields

```swift
struct LocalScore: Identifiable, Codable, Equatable {
    // ... existing fields ...

    // MARK: - Auth Fields (for future auth integration)

    /// The authenticated user's ID (nil if anonymous/not logged in)
    var userId: String?

    /// Whether this score was submitted by a logged-in user
    var isAuthenticated: Bool {
        userId != nil
    }

    /// Device identifier for anonymous tracking
    var deviceId: String?
}
```

---

### Backend Implementation

#### New Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/leaderboard/score` | Submit score (unified format with game_type) |
| GET | `/api/leaderboard/{game_type}/{date}` | Get leaderboard for any game |
| POST | `/api/leaderboard/sync` | Batch sync multiple scores |
| GET | `/api/leaderboard/health` | Health check with supported games |

#### Unified Score Submission

```python
# POST /api/leaderboard/score
# Supports both unified format and legacy Wordle format

# Unified Format:
{
    "game_type": "echo",      # Required: wordle, echo, crossword, trivia
    "score": 1200,            # Required
    "date": "2026-02-20",     # Required (YYYY-MM-DD)
    "username": "SwiftFalcon",# Optional (auto-generated if not provided)
    "metadata": {...}         # Optional, game-specific data
}

# Response:
{
    "success": true,
    "id": "uuid-string",
    "rank": 1,
    "username": "SwiftFalcon"
}
```

#### Fetch Leaderboard

```python
# GET /api/leaderboard/{game_type}/{date}?limit=5

# Response:
{
    "success": true,
    "game_type": "echo",
    "date": "2026-02-20",
    "leaderboard": [
        {
            "id": "uuid",
            "rank": 1,
            "username": "SwiftFalcon",
            "score": 1250,
            "game_type": "echo",
            "date": "2026-02-20",
            "metadata": {...}
        }
    ]
}
```

#### Batch Sync

```python
# POST /api/leaderboard/sync
{
    "scores": [
        {
            "game_type": "echo",
            "score": 1200,
            "date": "2026-02-20",
            "username": "SwiftFalcon",
            "metadata": {...}
        }
    ]
}

# Response:
{
    "success": true,
    "synced_count": 3,
    "results": [
        {
            "local_id": null,
            "remote_id": "uuid",
            "success": true,
            "error": null
        }
    ]
}
```

---

### How to Enable Remote Sync

When authentication is implemented and backend is deployed:

1. **Update APIConfig.swift:**
   ```swift
   // Change from true to false
   static let useLocalOnlyLeaderboards = false

   // Update to production URL
   static let baseURL = "https://your-backend.appspot.com"
   ```

2. **Start background sync in app launch:**
   ```swift
   // In AppDelegate or App init
   LeaderboardSyncService.shared.startBackgroundSync()
   ```

3. **Sync scores after game completion:**
   ```swift
   // Already handled by LocalLeaderboardService.saveScore()
   // which calls LeaderboardSyncService.syncScore() when remote is enabled
   ```

---

### Integration with Auth (for friend's implementation)

When implementing user authentication:

1. **After successful login**, update `LocalScore` entries with user ID:
   ```swift
   // Update pending scores with authenticated user ID
   let pendingScores = LocalLeaderboardService.shared.getPendingScores()
   for var score in pendingScores {
       score.userId = AuthService.shared.currentUser?.id
       LocalLeaderboardService.shared.updateScore(score)
   }
   ```

2. **On new score submission**, attach user ID:
   ```swift
   let score = LocalScore(
       gameType: .echo,
       score: 1200,
       date: Date(),
       metadata: metadata,
       userId: AuthService.shared.currentUser?.id,  // Attach user ID
       deviceId: UIDevice.current.identifierForVendor?.uuidString
   )
   LocalLeaderboardService.shared.saveScore(score)
   ```

3. **Backend**: Update score submission to validate user tokens and associate scores with authenticated users.

---

### Verification Checklist

After enabling remote sync, verify:

- [ ] `APIConfig.useLocalOnlyLeaderboards = false` is set
- [ ] `APIConfig.baseURL` points to correct server
- [ ] Backend server is running and healthy (`/api/leaderboard/health`)
- [ ] `RemoteLeaderboardService.submitScore()` succeeds
- [ ] `RemoteLeaderboardService.fetchLeaderboard()` returns data
- [ ] `LeaderboardSyncService.syncPendingScores()` syncs pending scores
- [ ] Scores appear on backend after game completion
- [ ] Leaderboard shows global rankings (not just local)

---

### Files Created/Modified Summary (Phase 4)

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `Services/RemoteLeaderboardService.swift` | HTTP client for remote API |
| CREATE | `Services/LeaderboardSyncService.swift` | Sync orchestration |
| CREATE | `tapin-backend/services/unified_leaderboard_service.py` | Backend unified service |
| MODIFY | `Services/APIConfig.swift` | Leaderboard endpoints, auth placeholders |
| MODIFY | `Models/LocalScore.swift` | Added userId, deviceId auth fields |
| MODIFY | `tapin-backend/models.py` | GameScore, UnifiedLeaderboardEntry models |
| MODIFY | `tapin-backend/api/leaderboard.py` | Unified endpoints |
| MODIFY | `tapin-backend/app.py` | Endpoint documentation |

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-12 | Initial spec created with architecture decisions |
| 2026-02-17 | Phase 1 Implementation Complete |
| 2026-02-17 | Phase 2 Implementation Complete |
| 2026-02-20 | **Phase 3 Spec Added** - Game over leaderboard, username generator, per-game buttons |
| 2026-02-20 | **Phase 4 Implemented** - Remote server infrastructure for leaderboard sync |
