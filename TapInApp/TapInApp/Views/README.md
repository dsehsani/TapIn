# Views

Main screen views that make up the app's primary navigation.

---

## Files

| File | Description |
|------|-------------|
| `ContentView.swift` | Root container view that manages tab navigation and instantiates all ViewModels. Hosts the `CustomTabBar` for navigation. |
| `NewsView.swift` | Home/News feed displaying featured articles, category pills, games banner, and latest updates. Includes `ArticleRowCard` for article list items. |
| `CampusView.swift` | Campus events listing with filter pills (All, Official, Student Events, Today, This Week). Includes `EventCard` component. |
| `GamesView.swift` | Games hub showing user stats, daily challenge, and available games. Includes `StatCard`, `FeaturedGameCard`, and `GameRowCard`. |
| `SavedView.swift` | Bookmarked content with segmented control for Articles/Events. Includes `EmptyStateView`, `SavedArticleCard`, and `SavedEventCard`. |
| `ProfileView.swift` | User profile and settings screen with sign in/out, notifications toggle, and dark mode toggle. Includes `SettingsRow` component. |

---

## View Hierarchy

```
ContentView
├── NewsView
│   ├── TopNavigationBar
│   ├── CategoryPillsView
│   ├── GamesBannerView
│   ├── FeaturedArticleCard
│   └── ArticleRowCard (list)
├── CampusView
│   └── EventCard (list)
├── GamesView
│   ├── StatCard (row)
│   ├── FeaturedGameCard
│   └── GameRowCard (list)
├── SavedView
│   ├── SavedArticleCard (list)
│   └── SavedEventCard (list)
└── ProfileView
    └── SettingsRow (list)
```

---

## Design Patterns

- Views receive ViewModels as `@ObservedObject` parameters
- Dark mode support via `@Environment(\.colorScheme)`
- Pull-to-refresh using `.refreshable` modifier
- Consistent card-based UI with rounded corners and shadows
