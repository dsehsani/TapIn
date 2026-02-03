# App

The entry point and core configuration for the TapIn application.

---

## Files

| File | Description |
|------|-------------|
| `TapInAppApp.swift` | Main entry point for the application. Defines the `@main` App struct and initializes the root `ContentView`. |

---

## Architecture

This app uses **MVVM (Model-View-ViewModel)** architecture with **SwiftUI**.

```
App
 └── TapInAppApp.swift (@main)
      └── ContentView (root view)
           ├── NewsView
           ├── CampusView
           ├── GamesView
           ├── SavedView
           └── ProfileView
```

---

## Getting Started

The app launches from `TapInAppApp.swift`, which creates a `WindowGroup` containing the main `ContentView`. All ViewModels are instantiated in `ContentView` and passed down to child views.
