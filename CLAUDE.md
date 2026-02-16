# CLAUDE.md - TapIn Project Reference

## Project Overview

TapIn is an iOS social app combining news, campus events, and games for UC Davis students. Built with SwiftUI using MVVM architecture, targeting iOS 17+.

## Quick Start

```bash
# Open project in Xcode
open TapInApp/TapInApp.xcodeproj

# Run leaderboard server (for Wordle)
cd wordle-leaderboard-server
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
python server.py  # Runs on http://localhost:8080
```

## Project Structure

```
TapIn/
├── TapInApp/                    # iOS Xcode project
│   └── TapInApp/
│       ├── App/                 # Entry point & global state
│       │   ├── TapInAppApp.swift
│       │   └── AppState.swift   # @Observable singleton for auth, settings, errors
│       ├── Views/               # Main screen views
│       │   ├── ContentView.swift    # Tab container
│       │   ├── NewsView.swift       # News feed
│       │   ├── CampusView.swift     # Campus events
│       │   ├── GamesView.swift      # Games hub
│       │   ├── SavedView.swift      # Bookmarks
│       │   └── ProfileView.swift    # Auth & settings
│       ├── ViewModels/          # Business logic (one per main view)
│       ├── Models/              # Data models (User, NewsArticle, CampusEvent, Game)
│       ├── Services/            # API clients & data services
│       │   ├── LeaderboardService.swift  # Flask API client
│       │   ├── AggieLifeService.swift    # iCal feed fetcher
│       │   └── ICalParser.swift          # iCal parser
│       ├── Components/          # Reusable UI (CustomTabBar, cards, pills)
│       ├── Extensions/          # Color & font extensions
│       └── Games/               # Game implementations
│           ├── Wordle/          # Daily word puzzle (full MVVM)
│           └── Echo/            # Memory/logic puzzle (full MVVM)
└── wordle-leaderboard-server/   # Flask backend for Wordle scores
```

## Architecture

**Pattern:** MVVM with @Observable macro

```
View (SwiftUI) → ViewModel (@Observable) → Service/Repository → API/Storage
```

**Global State:** `AppState.shared` injected via @EnvironmentObject
- Manages: auth state, user settings, global errors, loading states

**Concurrency:** Swift async/await throughout, @MainActor for UI updates

**Persistence:** UserDefaults for local storage, JSON encoding for complex types

## Key Technologies

- **UI:** SwiftUI (iOS 17+)
- **State:** @Observable macro, Combine
- **Networking:** URLSession with async/await
- **Backend:** Flask (Python) for leaderboard API
- **Data Sources:** Aggie Life iCal feed for campus events

## API Endpoints

### Leaderboard Service (localhost:8080)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/leaderboard/score` | Submit Wordle score |
| GET | `/api/leaderboard/<puzzle_date>` | Get daily leaderboard (limit 5) |
| GET | `/api/leaderboard/health` | Health check |

### External APIs

- **Aggie Life:** `https://aggielife.ucdavis.edu/ical/ucdavis/ical_ucdavis.ics`

## Games

### Wordle
- Daily puzzle with deterministic word generation
- 6 attempts, 5-letter words, 5400+ valid words
- Full persistence across app restarts
- Archive mode for past puzzles
- Leaderboard integration

### Echo
- 5-round memory/logic puzzle
- Shape + color sequence transformation
- 3 attempts per round, progressive difficulty
- Local scoring only (no leaderboard)

## Color Scheme

UC Davis branding defined in `Extensions/ColorExtensions.swift`:
- **Primary Blue:** #022851
- **Primary Gold:** #FFBF00
- Full dark mode support throughout

## Navigation

5-tab structure via CustomTabBar:
1. News (articles with category filtering)
2. Campus (live events from Aggie Life)
3. Games (Wordle, Echo hub)
4. Saved (bookmarked content)
5. Profile (auth, settings)

Games open as fullScreenCover; event details as sheets.

## Common Patterns

### Adding a New View
```swift
// 1. Create ViewModel in ViewModels/
@Observable
class MyViewModel {
    // State properties
    // Methods for user actions
}

// 2. Create View in Views/
struct MyView: View {
    @State private var viewModel = MyViewModel()
    var body: some View { ... }
}
```

### Making API Calls
```swift
// Use existing service pattern
func fetchData() async {
    do {
        let result = try await MyService.shared.fetch()
        // Update state on main thread (automatic with @MainActor)
    } catch {
        AppState.shared.handleError(error)
    }
}
```

### Persisting Data
```swift
// Use UserDefaults via existing patterns
UserDefaults.standard.set(encoded, forKey: "myKey")
```

## Build Configuration

- **Min iOS:** 17.0
- **Swift:** 5.9+
- **Dependencies:** None (native frameworks only)
- **Info.plist:** NSAllowsLocalNetworking enabled for localhost dev server

## Current Status

**Completed (Milestone 0):**
- MVVM foundation, all 5 tabs functional
- News feed with filtering
- Campus events with live iCal integration
- Wordle game (full implementation + leaderboard)
- Echo game (full implementation)
- Dark mode support
- Saving/bookmarking content

**TODO:**
- Trivia game implementation
- Crossword game implementation
- Production authentication (replace stub)
- Push notifications
- Article detail view
- Social sharing features
- Deploy Flask backend to Google App Engine

## Key Files for Common Tasks

| Task | Files |
|------|-------|
| Add new tab/screen | `ContentView.swift`, `Models/TabItem.swift` |
| Modify navigation | `Components/CustomTabBar.swift` |
| Add new game | `Games/` (copy Wordle structure) |
| Change colors | `Extensions/ColorExtensions.swift` |
| Add API endpoint | `Services/` + corresponding ViewModel |
| Modify global state | `App/AppState.swift` |
| Parse iCal events | `Services/ICalParser.swift` |

## Documentation

Additional docs in repo root:
- `README.md` - Project overview
- `overview.md` - Feature details
- `client_architecture.md` - iOS architecture deep-dive
- `server_architecture.md` - Flask backend details
- `API.md` - API documentation
- `features.md` - Feature specifications
