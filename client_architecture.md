# Client Architecture

## Overview

TapIn iOS is built using **SwiftUI** with the **MVVM (Model-View-ViewModel)** architecture pattern. The app targets iOS 17+ and leverages modern Swift features including async/await concurrency, @Observable macro, and declarative UI composition.

## Architecture Pattern: MVVM

```
┌─────────────────────────────────────────────────────────────┐
│                         View Layer                          │
│  (SwiftUI Views - Declarative UI, user interactions)        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     ViewModel Layer                         │
│  (Business logic, state management, data transformation)    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Model Layer                           │
│  (Data structures, Services, Repositories)                  │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
TapInApp/
├── App/
│   ├── TapInAppApp.swift        # App entry point (@main)
│   └── AppState.swift           # Global application state
│
├── Views/
│   ├── ContentView.swift        # Main navigation container
│   ├── NewsView.swift           # News feed view
│   ├── CampusView.swift         # Campus events view
│   ├── GamesView.swift          # Games hub view
│   ├── SavedView.swift          # Saved content view
│   └── ProfileView.swift        # User profile view
│
├── ViewModels/
│   ├── NewsViewModel.swift      # News business logic
│   ├── CampusViewModel.swift    # Events business logic
│   ├── GamesViewModel.swift     # Games management
│   ├── SavedViewModel.swift     # Bookmarks management
│   └── ProfileViewModel.swift   # User profile logic
│
├── Models/
│   ├── User.swift               # User data model
│   ├── NewsArticle.swift        # Article data model
│   ├── CampusEvent.swift        # Event data model
│   ├── Game.swift               # Game-related models
│   ├── Category.swift           # Category model
│   ├── TabItem.swift            # Navigation tab model
│   └── AppError.swift           # Error definitions
│
├── Services/
│   ├── LeaderboardService.swift # Leaderboard API client
│   ├── NetworkManager.swift     # HTTP networking (stub)
│   ├── AuthService.swift        # Authentication (stub)
│   └── UserDefaultManager.swift # Local persistence (stub)
│
├── Components/
│   ├── CustomTabBar.swift       # Bottom navigation bar
│   ├── TopNavigationBar.swift   # Top header with search
│   ├── CategoryPillsView.swift  # Category filter pills
│   ├── FeaturedArticleCard.swift# Featured article card
│   └── GamesBannerView.swift    # Games promotion banner
│
├── Extensions/
│   ├── ColorExtensions.swift    # UC Davis brand colors
│   └── FontExtensions.swift     # Custom fonts
│
└── Games/
    └── Wordle/
        ├── ViewModels/
        │   └── GameViewModel.swift
        ├── Views/
        │   ├── WordleGameView.swift
        │   ├── GameGridView.swift
        │   ├── KeyboardView.swift
        │   ├── TileView.swift
        │   ├── HeaderView.swift
        │   ├── GameOverView.swift
        │   └── ArchiveView.swift
        ├── Models/
        │   ├── GameState.swift
        │   ├── LetterState.swift
        │   ├── LetterTile.swift
        │   └── StoredGameState.swift
        └── Services/
            ├── GameStorage.swift
            └── DateWordGenerator.swift
```

## State Management

### Global State (AppState)

`AppState` is an `@Observable` class injected as an environment object throughout the app. It manages:

- **Authentication state:** Current user, sign in/out
- **User preferences:** Notifications, dark mode
- **Global errors:** Centralized error handling
- **Loading states:** App-wide loading indicators

```swift
@Observable
class AppState {
    var currentUser: User?
    var isAuthenticated: Bool
    var globalError: AppError?
    var isLoading: Bool
    var notificationsEnabled: Bool
}
```

### ViewModel State

Each view has a dedicated ViewModel using `@StateObject` for lifecycle management:

```swift
struct NewsView: View {
    @StateObject private var viewModel = NewsViewModel()

    var body: some View {
        // View implementation
    }
}
```

## Data Flow

```
User Action → View → ViewModel → Service/Repository → API/Storage
                          ↓
                    @Published state
                          ↓
                    View updates (SwiftUI reactivity)
```

## Key Components

### Views

| View | Purpose |
|------|---------|
| `ContentView` | Main container with tab navigation |
| `NewsView` | Displays news articles with filtering |
| `CampusView` | Shows campus events with filters |
| `GamesView` | Games hub with stats and game list |
| `SavedView` | Manages bookmarked content |
| `ProfileView` | User profile and settings |

### ViewModels

| ViewModel | Responsibilities |
|-----------|------------------|
| `NewsViewModel` | Fetch articles, category filtering, search |
| `CampusViewModel` | Fetch events, event filtering |
| `GamesViewModel` | Game list, user stats, game launching |
| `SavedViewModel` | Add/remove bookmarks, persistence |
| `ProfileViewModel` | Authentication delegation, settings |
| `GameViewModel` | Wordle game logic, leaderboard integration |

### Models

| Model | Description |
|-------|-------------|
| `User` | User profile (id, name, email, profileImageURL) |
| `NewsArticle` | Article data (title, excerpt, category, author, etc.) |
| `CampusEvent` | Event data (title, description, date, location) |
| `Game` | Game metadata (type, name, description, hasLeaderboard) |
| `GameStats` | Player statistics (gamesPlayed, streak, wins) |
| `AppError` | Typed errors with user-friendly messages |

### Services

| Service | Purpose |
|---------|---------|
| `LeaderboardService` | REST API client for leaderboard server |
| `GameStorage` | Persists Wordle game state to UserDefaults |
| `DateWordGenerator` | Deterministic daily word selection |

## Navigation

The app uses a custom tab bar (`CustomTabBar`) with 5 main sections:

```swift
enum TabItem: CaseIterable {
    case news
    case campus
    case games
    case saved
    case profile
}
```

Navigation within tabs uses SwiftUI's `NavigationStack` for drill-down navigation.

## Networking

### LeaderboardService

Communicates with the Flask backend using `URLSession` with async/await:

```swift
@MainActor
class LeaderboardService {
    static let shared = LeaderboardService()
    private let baseURL = "http://localhost:8080/api/leaderboard"

    func submitScore(guesses: Int, timeSeconds: Int, puzzleDate: String) async throws -> ScoreSubmissionResponse
    func fetchLeaderboard(for date: String, limit: Int) async throws -> [LeaderboardEntryResponse]
    func isServerHealthy() async -> Bool
}
```

## Persistence

### UserDefaults

Used for lightweight data storage:
- User preferences (dark mode, notifications)
- Game states (Wordle progress per date)
- Authentication tokens

### GameStorage

Singleton service for Wordle game persistence:

```swift
class GameStorage {
    static let shared = GameStorage()

    func saveGameState(for date: Date, guesses: [String], gameState: GameState)
    func loadGameState(for date: Date) -> StoredGameState?
    func hasPlayedDate(_ date: Date) -> Bool
    func getAllPlayedDates() -> [Date]
}
```

## Error Handling

Centralized error handling with typed errors:

```swift
enum AppError: Error {
    // Network errors
    case networkUnavailable
    case serverError(statusCode: Int)
    case timeout

    // Authentication errors
    case notAuthenticated
    case invalidCredentials

    // Data errors
    case notFound
    case invalidData

    var userFriendlyMessage: String { ... }
}
```

## Theming

### UC Davis Brand Colors

```swift
extension Color {
    static let ucdBlue = Color(hex: "#022851")
    static let ucdGold = Color(hex: "#FFBF00")
}
```

### Dark Mode

Full dark mode support with adaptive colors throughout the app, controlled via `ProfileViewModel.toggleDarkMode()`.

## Testing

### Unit Tests (`TapInAppTests/`)
- ViewModel logic testing
- Model serialization tests
- Service mock testing

### UI Tests (`TapInAppUITests/`)
- Navigation flow testing
- User interaction testing
- Accessibility testing
