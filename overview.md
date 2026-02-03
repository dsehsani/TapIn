# TapIn - Project Overview

## Description

TapIn is a community-focused iOS application that brings UC Davis students and local residents together by combining trusted local journalism with engaging, free mini-games. The app makes staying informed social and fun through local leaderboards where players compete with friends and neighbors.

## Team Members

- Jake Stelly
- James Fu
- Yash Pradan
- Suhani Shokeen
- Darius Ehsani

## Tech Stack

### Client (iOS)
- **Language:** Swift 5.9+
- **Framework:** SwiftUI
- **Architecture:** MVVM (Model-View-ViewModel)
- **Minimum iOS Version:** iOS 17.0
- **IDE:** Xcode 15+

### Server
- **Language:** Python 3.11+
- **Framework:** Flask 3.0
- **Deployment:** Google App Engine
- **Database:** In-memory (Milestone 0), planned migration to Firestore

## App Sections

| Section | Description |
|---------|-------------|
| **News** | UC Davis news articles with category filtering and search |
| **Campus** | Campus events with filtering by type and date |
| **Games** | Mini-games hub featuring Aggie Wordle with leaderboards |
| **Saved** | Bookmarked articles and events |
| **Profile** | User authentication, settings, and preferences |

## Current Features (Milestone 0)

- Tab-based navigation with 5 main sections
- News article browsing with category filtering
- Campus event management
- **Aggie Wordle** - Daily word puzzle with:
  - Deterministic daily word generation
  - Archive mode to play past puzzles
  - Animated tile reveals
  - Online leaderboard integration
  - Persistent game state storage
- User authentication (sign in/register/sign out)
- Save/bookmark functionality
- Dark mode support
- Client-server communication via REST API

## Repository Structure

```
TapIn/
├── TapInApp/                    # iOS Application
│   ├── TapInApp/
│   │   ├── App/                 # App entry point and global state
│   │   ├── Views/               # SwiftUI views
│   │   ├── ViewModels/          # View models (business logic)
│   │   ├── Models/              # Data models
│   │   ├── Services/            # API and persistence services
│   │   ├── Components/          # Reusable UI components
│   │   ├── Extensions/          # Swift extensions
│   │   └── Games/               # Game implementations
│   │       └── Wordle/          # Aggie Wordle game
│   ├── TapInAppTests/           # Unit tests
│   └── TapInAppUITests/         # UI tests
│
├── wordle-leaderboard-server/   # Flask Backend
│   ├── app.py                   # Flask application
│   ├── models.py                # Data models
│   ├── api/                     # API endpoints
│   ├── services/                # Business logic
│   └── requirements.txt         # Python dependencies
│
├── overview.md                  # This file
├── client_architecture.md       # iOS architecture documentation
├── server_architecture.md       # Server architecture documentation
├── API.md                       # API documentation
├── features.md                  # Feature documentation
└── README.md                    # Quick start guide
```

## Getting Started

### iOS App
1. Open `TapInApp/TapInApp.xcodeproj` in Xcode 15+
2. Select an iOS 17+ simulator
3. Build and run (Cmd+R)

### Flask Server
1. Navigate to `wordle-leaderboard-server/`
2. Create virtual environment: `python3 -m venv venv`
3. Activate: `source venv/bin/activate`
4. Install dependencies: `pip install -r requirements.txt`
5. Run server: `python app.py`
6. Server available at `http://localhost:8080`

## Links

- **GitHub Repository:** [TapIn](https://github.com/your-repo/TapIn)
- **Project Proposal:** See `proposal.md`
