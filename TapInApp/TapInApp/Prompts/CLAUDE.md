# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

### iOS App
```bash
open TapInApp/TapInApp.xcodeproj   # Open in Xcode, build with Cmd+B, run with Cmd+R

# Command-line build (simulator)
xcodebuild -project TapInApp/TapInApp.xcodeproj -scheme TapInApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -project TapInApp/TapInApp.xcodeproj -scheme TapInApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test
```
- Target: iOS 17.0+, Swift 5.9+
- SPM dependencies: SwiftSoup, Firebase (Auth + Core), GoogleSignIn — no CocoaPods/Carthage
- `Info.plist` has `NSAllowsLocalNetworking` enabled for localhost dev server

### Backend (Flask/Python)
```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python app.py                      # http://localhost:8080
```
- Production: Google Cloud Run (URL in `Services/APIConfig.swift`)
- Deploy: `cd backend && gcloud run deploy --source .`
- Required env vars: `SECRET_KEY`, `GCP_PROJECT`, `CLAUDE_API_KEY`

### Backend Tests
```bash
cd backend
python -m pytest test_pipes_puzzle.py   # Pipes puzzle generator tests
```

## Architecture

### iOS App (SwiftUI + MVVM)

```
View -> ViewModel (@Observable / @Published) -> Service -> API / UserDefaults / Keychain
```

**Global state:** `AppState.shared` is an `ObservableObject` singleton injected via `@EnvironmentObject`. Also accessible via custom `EnvironmentKey` at `\.appState`. Manages auth state, user profile, loading/error states. Auth tokens stored in Keychain via `KeychainService`, not UserDefaults.

**Auth flow:** `TapInAppApp.swift` checks `appState.restoreSession()` on launch, shows `OnboardingView` (in `Onboarding/`) or `ContentView`. Supports Apple Sign-In, Google Sign-In, and phone/SMS auth. Backend issues JWT stored as `backendToken`.

**API configuration:** All backend URLs centralized in `Services/APIConfig.swift`. Switch between local dev and production by changing `baseURL`.

**Navigation:** 5-tab `CustomTabBar` in `ContentView`. Games open as `fullScreenCover`; event details as sheets.

**Persistence:** UserDefaults for app data (saved articles, game state, preferences). Keychain for auth tokens. JSON encoding for complex types.

### Backend (Flask)

```
api/ (Blueprint routes) -> services/ (business logic) -> repositories/ (Firestore persistence)
```

**Blueprints** registered in `app.py`: leaderboard, claude, events, articles, users, pipes, analytics.

**Key services:**
- `firestore_client.py` — shared Firestore connection
- `claude_service.py` — Anthropic API proxy for event summaries and chat
- `aggie_life_service.py` / `aggie_rss_service.py` — campus event and article ingestion
- `pipes_puzzle_generator.py` — AI-generated daily puzzle sets
- `auth_service.py` — JWT creation/verification, Apple/Google/phone token validation

**Data flow for events:** iCal/RSS feed -> service parses -> Claude AI generates summaries -> stored in Firestore -> served to iOS client with `aiSummary` + `aiBulletPoints`.

### Key Directories (iOS)

| Directory | Purpose |
|-----------|---------|
| `App/` | Entry point (`TapInAppApp.swift`) and `AppState.swift` |
| `Views/` | Main tab views (News, Campus, Games, Saved, Profile) |
| `ViewModels/` | One ViewModel per main view, plus `LeaderboardViewModel` |
| `Models/` | `User`, `NewsArticle`, `CampusEvent`, `Game`, `TabItem`, `Category` |
| `Services/` | API clients, parsers, caching, analytics, preference engines (~25 files) |
| `Components/` | Reusable UI (tab bar, cards, leaderboard rows) |
| `Games/` | `Wordle/`, `Echo/`, `Pipes/`, `MiniCrossWord/` — each with own MVVM |
| `Onboarding/` | Auth flow views and `OnboardingViewModel` |
| `Repositories/` | `LeaderboardRepository` (data access layer) |
| `Extensions/` | UC Davis color scheme (#022851 blue, #FFBF00 gold) and font helpers |

### Services Overview (iOS)

- **News:** `NewsService`, `ArticleCacheService`, `DailyBriefingService`, `RSSParser`, `AggieArticleParser`
- **Events:** `EventsAPIService`, `AggieLifeService`, `ICalParser`, `EventIntelligenceService`, `EventPreferenceEngine`
- **Personalization:** `ForYouFeedEngine`, `ArticleReadTracker`, `NotInterestedTracker`
- **Auth:** `AuthService`, `SMSAuthService`, `UserAPIService`, `KeychainService`
- **Games:** `LeaderboardService` (cloud scores)
- **Infra:** `NetworkManager`, `APIConfig`, `UserDefaultManager`, `NotificationService`, `AnalyticsTracker`, `ClaudeAPIService`

### Games

Each game under `Games/` follows its own MVVM structure:
- **Wordle (DailyFive)** — daily 5-letter word puzzle, cloud leaderboard
- **Echo** — memory/logic with shape+color sequences, local scoring only
- **MiniCrossWord** — daily mini crossword, pre-verified puzzles in `Data/SamplePuzzles.swift`
- **Pipes** — pipe-rotation puzzle, daily puzzles from backend (`/api/pipes/daily-five`)

## Key Conventions

- ViewModels use `@Observable` macro (newer code) or `ObservableObject` with `@Published` (e.g. `AppState`)
- Views own their ViewModel: `@State private var viewModel = MyViewModel()`
- Services are singletons accessed via `.shared`
- All network calls use Swift async/await with `@MainActor` for UI updates
- Error handling flows through `AppState.shared.showError()` for global alerts
- Tutorial overlays for games use `GameTutorialOverlay` component with UserDefaults flags (`tutorial_seen_<game>`)
- The `Prompts/` folder contains design/feature prompts used during development — not runtime code
