# TapIn — Your Campus, One Place

TapIn is a SwiftUI iOS app built for UC Davis students. It brings campus news, live events, and daily games into a single experience — powered by a Flask backend deployed on Google Cloud Run.

## Features

- **News** — Aggie articles with category filtering and AI-powered daily briefings
- **Campus Events** — Live feed from Aggie Life with event details and RSVP
- **Games**
  - **DailyFive** — Daily 5-letter word puzzle with cloud leaderboard
  - **Pipes** — Connect colored endpoints and fill every cell
  - **Echo** — Memory and pattern recognition challenge
- **Saved** — Bookmark articles and events for later
- **Profile** — Sign in with Apple, Google, or phone number; dark mode support

## Tech Stack

| Layer | Technology |
|-------|-----------|
| iOS App | SwiftUI, MVVM, `@Observable`, async/await |
| Backend | Flask (Python), Gunicorn, Google Cloud Run |
| Database | Google Cloud Firestore |
| Auth | Apple Sign-In, Google Sign-In, Phone (SMS) |
| Min Target | iOS 17.0 |

## Project Structure

```
TapIn/
├── TapInApp/                    # iOS Xcode project
│   └── TapInApp/
│       ├── App/                 # Entry point, AppState
│       ├── Views/               # Main tab views + leaderboard
│       ├── ViewModels/          # One per view (MVVM)
│       ├── Models/              # User, Game, NewsArticle, CampusEvent
│       ├── Services/            # API clients (LeaderboardService, NewsService, etc.)
│       ├── Components/          # Reusable UI (CustomTabBar, LeaderboardRowView, etc.)
│       ├── Games/               # DailyFive (Wordle), Echo, Pipes
│       ├── Onboarding/          # Auth flow (Apple, Google, Phone)
│       └── Extensions/          # Color & font helpers
├── tapin-backend/               # Flask backend (Cloud Run)
│   ├── api/                     # Route blueprints (leaderboard, articles, events, users)
│   ├── services/                # Business logic + Firestore client
│   └── app.py                   # Application entry point
└── wordle-leaderboard-server/   # Local dev server (mirrors tapin-backend leaderboard)
```

## Getting Started

### iOS App
1. Open `TapInApp/TapInApp.xcodeproj` in Xcode
2. Select an iOS 17+ simulator or device
3. Build and run

### Backend (for local development)
```bash
cd tapin-backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py                    # Runs on http://localhost:8080
```

The production backend is deployed at Google Cloud Run. The iOS app points to the Cloud Run URL by default via `APIConfig.swift`.

## API Endpoints

### Leaderboard
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/leaderboard/score` | Submit a DailyFive score (guesses, time, username) |
| GET | `/api/leaderboard/<date>` | Get leaderboard for a puzzle date |

### Articles & Events
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/articles?category=all` | Fetch news articles |
| GET | `/api/articles/daily-briefing` | AI-generated daily news summary |
| GET | `/api/events` | Campus events from Aggie Life |

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/users/auth/apple` | Apple Sign-In |
| POST | `/api/users/auth/google` | Google Sign-In |
| POST | `/api/users/auth/phone` | Phone/SMS auth |
| GET | `/api/users/me` | Current user profile |

## Deployment

### Backend → Cloud Run
```bash
cd tapin-backend
gcloud run deploy --source .
```

Required environment variables in Cloud Run:
- `SECRET_KEY` — JWT signing key
- `GCP_PROJECT` — Firestore project ID
- `CLAUDE_API_KEY` — For AI summaries (via Secret Manager)

### iOS → App Store
1. Register App ID in Apple Developer portal
2. Update bundle identifier in Xcode Signing & Capabilities
3. Archive and upload via Xcode → Product → Archive

## Team

Built by UC Davis students — ECS 191, Winter 2026.
