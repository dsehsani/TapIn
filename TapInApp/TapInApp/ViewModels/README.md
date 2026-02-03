# ViewModels

Business logic and state management layer following the MVVM pattern.

---

## Files

| File | Description |
|------|-------------|
| `CampusViewModel.swift` | Manages campus events data, loading states, and event filtering (All, Official, Student Events, Today, This Week). |
| `GamesViewModel.swift` | Handles available games list, current game state, and user statistics tracking (games played, wins, streaks). |
| `NewsViewModel.swift` | Controls news articles, featured content, category selection, and search functionality. |
| `ProfileViewModel.swift` | Manages user authentication state, profile data, and app settings (notifications, dark mode). |
| `SavedViewModel.swift` | Handles bookmarked articles and saved events with add/remove functionality. |

---

## Architecture

All ViewModels:
- Inherit from `ObservableObject`
- Use `@Published` properties for reactive UI updates
- Are instantiated once in `ContentView` and passed to child views
- Include async methods for data fetching with loading states

---

## TODO Markers

Each ViewModel contains `// TODO:` comments indicating where to implement:
- **NewsViewModel**: Web scraping logic for real news data
- **CampusViewModel**: Events data source integration
- **GamesViewModel**: Game logic implementation
- **ProfileViewModel**: User authentication
- **SavedViewModel**: Persistence (UserDefaults/CoreData)

---

## Common Patterns

```swift
class ExampleViewModel: ObservableObject {
    @Published var data: [Item] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func fetchData() async {
        await MainActor.run { isLoading = true }
        // Fetch data...
        await MainActor.run { isLoading = false }
    }
}
```
