# TapIn (iOS) — UC Davis News & Games

TapIn is a SwiftUI app built with MVVM that brings UC Davis news and campus-centric mini‑games into one experience. It includes a daily “Aggie Wordle” with an archive browser, animated grid and keyboard, and an optional online leaderboard powered by a separate Flask backend (wordle‑leadboard‑server) that you run or deploy independently.

This README documents both the iOS app and the external Flask server API used by the Wordle leaderboard.


## At a glance
- SwiftUI app with MVVM architecture and a custom tab bar
- Main sections: News, Campus, Games, Saved, Profile
- Aggie Wordle
  - Daily puzzle with deterministic word per date
  - Archive browser to replay previous days
  - Animated tile reveals and adaptive keyboard coloring
  - Local persistence of progress and results
  - Optional online leaderboard (Flask server)


## Requirements
- Xcode 15 or later (Swift Concurrency and the #Preview macro)
- iOS 17 or later target
- To use the leaderboard features during development: Python 3.11+ for the Flask server, or a deployed server URL


## Getting started (iOS app)
1. Open the project in Xcode and select a simulator (iOS 17+).
2. Build and run.
3. If you want the leaderboard to work in development:
   - Start the Flask server on port 8080 (see “Flask Leaderboard Server” below).
   - Or change the app’s base URL to your deployed server (HTTPS recommended).

On-device testing tip: If you run the server on your Mac and test on a physical iPhone, replace `localhost` with your Mac’s LAN IP (e.g., `http://192.168.1.10:8080`) in the app configuration.


## Configuration: Leaderboard base URL
The Wordle leaderboard is optional and controlled by `LeaderboardService`.

```swift:LeaderboardService.swift
private init() {
    // Use localhost for development
    // TODO: Update to App Engine URL when deployed
    self.baseURL = "http://localhost:8080/api/leaderboard"
    ...
}```
