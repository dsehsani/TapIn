# Models

Data structures that represent the core entities in the TapIn application.

---

## Files

| File | Description |
|------|-------------|
| `CampusEvent.swift` | Represents campus events with properties like title, date, location, and whether it's official or student-posted. Includes `EventFilterType` enum for filtering events. |
| `Category.swift` | Represents news categories (e.g., Top Stories, Research, Campus, Athletics) with name, icon, and selection state. |
| `Game.swift` | Represents available games (Aggie Wordle, Campus Trivia, etc.) and includes `GameStats` for tracking player statistics. |
| `NewsArticle.swift` | Represents news articles with title, excerpt, category, author, timestamp, and featured status. |
| `TabItem.swift` | Enum defining the main navigation tabs (News, Campus, Games, Saved, Profile) with their icons. |
| `User.swift` | Represents user profile data including name, email, and profile image URL. |

---

## Design Patterns

- All models conform to `Identifiable` for use in SwiftUI lists
- Models include static `sampleData` for previews and development
- `Codable` conformance where persistence is needed (User, GameStats)
- `Hashable` conformance where needed for SwiftUI (Category)

---

## Sample Data

Each model provides sample data through extensions:
- `CampusEvent.sampleData`
- `Category.allCategories`
- `Game.sampleData`
- `NewsArticle.sampleData`
- `User.sampleUser` / `User.guest`
