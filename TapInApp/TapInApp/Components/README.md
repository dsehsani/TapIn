# Components

Reusable UI components used across multiple views.

---

## Files

| File | Description |
|------|-------------|
| `CategoryPillsView.swift` | Horizontal scrolling category filter with pill-shaped buttons. Used in NewsView for filtering articles by category. Includes `CategoryPill` subcomponent. |
| `CustomTabBar.swift` | Custom bottom navigation bar with 5 tabs. Games tab has a prominent golden icon. Includes `TabBarItem` subcomponent. |
| `FeaturedArticleCard.swift` | Large card for displaying featured/hero articles with image placeholder, badge, title, excerpt, and author. Includes `Date.timeAgoDisplay()` extension. |
| `GamesBannerView.swift` | Promotional banner for the Games section with gradient background and "Play Now" CTA. Includes `ScaleButtonStyle` for button animation. |
| `TopNavigationBar.swift` | App header with logo, search bar, and settings button. Uses blur material background for overlay effect. |

---

## Usage Examples

### CategoryPillsView
```swift
CategoryPillsView(
    selectedCategory: $viewModel.selectedCategory,
    categories: viewModel.categories,
    onCategoryTap: { category in
        viewModel.selectCategory(category)
    }
)
```

### CustomTabBar
```swift
CustomTabBar(selectedTab: $selectedTab)
```

### FeaturedArticleCard
```swift
FeaturedArticleCard(
    article: featuredArticle,
    onTap: { /* Navigate to detail */ }
)
```

---

## Design System

All components follow consistent styling:
- **Colors**: UC Davis Blue (`#022851`) and Gold (`#FFBF00`)
- **Corners**: 12-16pt rounded corners
- **Shadows**: Subtle shadows for depth
- **Dark Mode**: Full support via `colorScheme` environment
