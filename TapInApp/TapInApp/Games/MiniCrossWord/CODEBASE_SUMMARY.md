# MiniCrossword Codebase Summary & Implementation Plan

This document summarizes the existing TapIn app architecture and provides a detailed implementation plan for the MiniCrossword game. Read this before implementing to avoid re-exploring the codebase.

---

## Table of Contents

1. [Existing Architecture Overview](#existing-architecture-overview)
2. [Wordle Game Patterns](#wordle-game-patterns)
3. [Game Integration System](#game-integration-system)
4. [Color System](#color-system)
5. [Implementation Plan](#implementation-plan)
6. [File Templates](#file-templates)

---

## Existing Architecture Overview

### Directory Structure

```
TapInApp/TapInApp/
├── Models/
│   └── Game.swift                    # GameType enum, Game struct
├── ViewModels/
│   └── GamesViewModel.swift          # Game selection/routing
├── Views/
│   └── GamesView.swift               # Game list UI with fullScreenCover
├── Extensions/
│   └── ColorExtensions.swift         # All color definitions
└── Games/
    ├── Wordle/                       # Reference implementation
    │   ├── Models/
    │   ├── ViewModels/
    │   ├── Views/
    │   └── Services/
    └── MiniCrossWord/                # To be implemented
        └── prompts/                  # Specifications (don't edit)
```

---

## Wordle Game Patterns

### Models Layer

**Location:** `Games/Wordle/Models/`

| File | Purpose |
|------|---------|
| `GameState.swift` | Enum: `.playing`, `.won`, `.lost` |
| `LetterState.swift` | Enum: `.empty`, `.filled`, `.correct`, `.wrongPosition`, `.notInWord` with computed color properties |
| `LetterTile.swift` | Struct: `id`, `letter`, `state`, `isRevealing`, `revealDelay` |
| `StoredGameState.swift` | Codable struct for persistence: `guesses`, `gameState`, `dateKey` |

**Key Pattern:** Enums with computed properties for colors/styling.

### ViewModel Layer

**Location:** `Games/Wordle/ViewModels/GameViewModel.swift`

```swift
@Observable
class GameViewModel {
    // Configuration
    let maxGuesses = 6
    let wordLength = 5

    // State
    var targetWord: String = ""
    var currentRow: Int = 0
    var currentTile: Int = 0
    var gameState: GameState = .playing
    var grid: [[LetterTile]] = []
    var keyboardStates: [Character: LetterState] = [:]

    // Daily mode
    var currentDate: Date = DateWordGenerator.today

    // Animation
    var isRevealing: Bool = false
    var revealingRow: Int = -1

    // Methods
    func loadGameForDate(_ date: Date)
    func addLetter(_ letter: Character)
    func deleteLetter()
    func submitGuess()
    func saveCurrentState()
}
```

**Key Pattern:** `@Observable` class with grid as 2D array, auto-save on changes.

### Views Layer

**Location:** `Games/Wordle/Views/`

| File | Purpose |
|------|---------|
| `WordleGameView.swift` | Main entry with `onDismiss: () -> Void` callback |
| `GameGridView.swift` | Renders grid, receives `[[LetterTile]]` |
| `TileView.swift` | Individual tile with flip animation |
| `KeyboardView.swift` | QWERTY layout with callbacks |
| `HeaderView.swift` | Back button, title, menu |
| `GameOverView.swift` | Win/lose overlay |

**Main View Structure:**
```swift
struct WordleGameView: View {
    var onDismiss: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            Color.wordleBackground(colorScheme).ignoresSafeArea()
            VStack(spacing: 0) {
                HeaderView(onBack: onDismiss, ...)
                Spacer()
                GameGridView(grid: viewModel.grid, ...)
                Spacer()
                KeyboardView(onKeyTap: { viewModel.addLetter($0) }, ...)
            }
            if viewModel.gameState != .playing {
                GameOverView(onBack: onDismiss, ...)
            }
        }
    }
}
```

**Key Pattern:** Callbacks passed to child views, ZStack with conditional overlay.

### Services Layer

**Location:** `Games/Wordle/Services/`

**GameStorage.swift (Singleton):**
```swift
class GameStorage {
    static let shared = GameStorage()
    private let storageKey = "wordleGameStates"

    func saveGameState(for date: Date, guesses: [String], gameState: GameState)
    func loadGameState(for date: Date) -> StoredGameState?
    func isDateCompleted(_ date: Date) -> Bool
    func getAllPlayedDates() -> [Date]

    private func loadAllStates() -> [String: StoredGameState]
    private func saveAllStates(_ states: [String: StoredGameState])
}
```

**Key Pattern:** Singleton with UserDefaults, date-keyed storage, JSON encoding.

---

## Game Integration System

### Game Model

**Location:** `Models/Game.swift`

```swift
enum GameType: String, Codable, CaseIterable {
    case wordle = "wordle"
    case trivia = "trivia"
    case crossword = "crossword"  // Already defined!

    var displayName: String {
        switch self {
        case .wordle: return "Aggie Wordle"
        case .trivia: return "Campus Trivia"
        case .crossword: return "Aggie Crossword"
        }
    }
}

struct Game: Identifiable, Codable {
    var id: UUID
    var type: GameType
    var name: String
    var description: String
    var iconName: String
    var isMultiplayer: Bool
    var hasLeaderboard: Bool
}
```

**Note:** `GameType.crossword` is already defined. Sample data includes crossword game.

### GamesViewModel

**Location:** `ViewModels/GamesViewModel.swift`

```swift
class GamesViewModel: ObservableObject {
    @Published var availableGames: [Game] = []
    @Published var currentGame: Game?
    @Published var showingWordle: Bool = false
    // Need to add: @Published var showingCrossword: Bool = false

    func startGame(_ game: Game) {
        currentGame = game
        if game.name == "Aggie Wordle" {
            showingWordle = true
        }
        // Need to add: crossword routing
    }

    func dismissGame() {
        showingWordle = false
        // Need to add: showingCrossword = false
        currentGame = nil
    }
}
```

### GamesView

**Location:** `Views/GamesView.swift`

```swift
struct GamesView: View {
    @ObservedObject var viewModel: GamesViewModel

    var body: some View {
        ZStack {
            // Game list content...
        }
        .fullScreenCover(isPresented: $viewModel.showingWordle) {
            WordleGameView(onDismiss: { viewModel.dismissGame() })
        }
        // Need to add: .fullScreenCover for crossword
    }
}
```

---

## Color System

**Location:** `Extensions/ColorExtensions.swift`

### Naming Convention

- Hex colors: `ucdBlue`, `ucdGold`, `backgroundLight`, `backgroundDark`
- Game colors: `wordle[Green|Gray]`, `tileBorder[Filled][Dark]`
- Adaptive functions: `wordleBackground(_ colorScheme:)`

### Wordle Colors

```swift
extension Color {
    // Status indicators (RGB 0-1 scale)
    static let wordleGreen = Color(red: 0.42, green: 0.67, blue: 0.46)
    static let wordleGray = Color(red: 0.47, green: 0.49, blue: 0.51)

    // Tile borders
    static let tileBorder = Color(red: 0.83, green: 0.84, blue: 0.85)
    static let tileBorderDark = Color(red: 0.35, green: 0.38, blue: 0.42)

    // Adaptive functions
    static func wordleBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .backgroundDark : .appBackground
    }
}
```

### Crossword Colors to Add

```swift
// MARK: - Crossword Game Colors
static let crosswordSelected = Color(red: 1.0, green: 0.84, blue: 0.0)      // Gold
static let crosswordHighlighted = Color(red: 1.0, green: 0.95, blue: 0.7)   // Light gold
static let crosswordBlocked = Color.black
static let crosswordIncorrect = Color(red: 1.0, green: 0.8, blue: 0.8)      // Light red
static let crosswordRevealed = Color(red: 1.0, green: 0.9, blue: 0.7)       // Light orange

// MARK: - Crossword Adaptive Colors
static func crosswordCellBorder(_ colorScheme: ColorScheme) -> Color { ... }
static func crosswordBackground(_ colorScheme: ColorScheme) -> Color { ... }
```

---

## Implementation Plan

### Phase 1: Models (6 files)

Create in `Games/MiniCrossWord/Models/`:

| # | File | Description |
|---|------|-------------|
| 1 | `CrosswordDirection.swift` | Enum: `across`, `down` with `opposite` computed property |
| 2 | `CrosswordGameState.swift` | Enum: `playing`, `completed` |
| 3 | `CrosswordClue.swift` | Struct with `id`, `number`, `direction`, `text`, `answer`, `startRow`, `startCol`, computed `cellPositions` |
| 4 | `CrosswordCell.swift` | Struct with `id`, `row`, `col`, `isBlocked`, `letter`, `correctLetter`, `clueNumber`, `acrossClueID`, `downClueID`, validation states |
| 5 | `CrosswordPuzzle.swift` | Struct with `id`, `title`, `author`, `dateKey`, `gridSize`, `clues`, `blockedCells` |
| 6 | `StoredCrosswordState.swift` | Codable struct: `dateKey`, `letters`, `gameState`, `elapsedSeconds` |

### Phase 2: Data & Services (3 files)

| # | File | Location | Description |
|---|------|----------|-------------|
| 7 | `SamplePuzzles.swift` | `Data/` | 2-3 random themed puzzles |
| 8 | `CrosswordPuzzleProvider.swift` | `Services/` | Singleton, `puzzleForDate(_:)`, `todaysPuzzle()` |
| 9 | `CrosswordStorage.swift` | `Services/` | Singleton, persistence with key `"crosswordGameStates"` |

### Phase 3: ViewModel (1 file)

| # | File | Description |
|---|------|-------------|
| 10 | `CrosswordViewModel.swift` | `@Observable` class with grid, selection, input, timer, persistence |

**Key Properties:**
- `currentPuzzle: CrosswordPuzzle?`
- `grid: [[CrosswordCell]]`
- `gameState: CrosswordGameState`
- `selectedRow: Int?`, `selectedCol: Int?`
- `currentDirection: CrosswordDirection`
- `selectedClue: CrosswordClue?`
- `elapsedSeconds: Int`

**Key Methods:**
- `loadPuzzle(for:)`, `selectCell(row:col:)`, `toggleDirection()`
- `inputLetter(_:)`, `deleteLetter()`, `selectClue(_:)`
- `checkAnswers()`, `revealCell()`, `revealWord()`, `revealPuzzle()`
- `checkCompletion()`, `saveCurrentState()`

### Phase 4: Core Views (4 files)

| # | File | Description |
|---|------|-------------|
| 11 | `CrosswordCellView.swift` | Individual cell with states: blocked, selected, highlighted, incorrect, revealed |
| 12 | `CrosswordGridView.swift` | 5x5 grid container |
| 13 | `CrosswordKeyboardView.swift` | QWERTY keyboard (similar to Wordle) |
| 14 | `MiniCrosswordGameView.swift` | Main entry with `onDismiss` callback |

### Phase 5: Supporting Views (4 files)

| # | File | Description |
|---|------|-------------|
| 15 | `ClueRowView.swift` | Single clue: number + text, highlight when selected |
| 16 | `ClueListView.swift` | Tabs (Across/Down), ScrollView, auto-scroll |
| 17 | `CrosswordHeaderView.swift` | Back button, timer, menu |
| 18 | `CrosswordCompletionView.swift` | Completion overlay with time and back button |

### Phase 6: App Integration (3 changes)

| # | File | Changes |
|---|------|---------|
| 19 | `GamesViewModel.swift` | Add `showingCrossword`, update `startGame()` and `dismissGame()` |
| 20 | `GamesView.swift` | Add `.fullScreenCover(isPresented: $viewModel.showingCrossword)` |
| 21 | `ColorExtensions.swift` | Add crossword colors and adaptive functions |

---

## File Templates

### Model Template (CrosswordDirection.swift)

```swift
import Foundation

enum CrosswordDirection: String, Codable {
    case across
    case down

    var opposite: CrosswordDirection {
        self == .across ? .down : .across
    }
}
```

### ViewModel Template

```swift
import SwiftUI

@Observable
class CrosswordViewModel {
    // MARK: - Properties
    var currentPuzzle: CrosswordPuzzle?
    var grid: [[CrosswordCell]] = []
    var gameState: CrosswordGameState = .playing
    var selectedRow: Int?
    var selectedCol: Int?
    var currentDirection: CrosswordDirection = .across
    var elapsedSeconds: Int = 0

    private var timer: Timer?

    // MARK: - Initialization
    init() {
        loadTodaysPuzzle()
    }

    // MARK: - Public Methods
    func loadPuzzle(for dateKey: String) { ... }
    func selectCell(row: Int, col: Int) { ... }
    func inputLetter(_ letter: Character) { ... }
    func deleteLetter() { ... }

    // MARK: - Private Methods
    private func saveCurrentState() { ... }
    private func startTimer() { ... }
}
```

### Main View Template

```swift
import SwiftUI

struct MiniCrosswordGameView: View {
    var onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = CrosswordViewModel()

    var body: some View {
        ZStack {
            Color.crosswordBackground(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                CrosswordHeaderView(
                    elapsedSeconds: viewModel.elapsedSeconds,
                    onBack: onDismiss,
                    colorScheme: colorScheme
                )

                // Current clue banner
                if let clue = viewModel.selectedClue {
                    CurrentClueView(clue: clue)
                }

                Spacer()

                CrosswordGridView(
                    grid: viewModel.grid,
                    selectedRow: viewModel.selectedRow,
                    selectedCol: viewModel.selectedCol,
                    currentDirection: viewModel.currentDirection,
                    onCellTap: { row, col in
                        viewModel.selectCell(row: row, col: col)
                    }
                )

                Spacer()

                ClueListView(
                    clues: viewModel.currentPuzzle?.clues ?? [],
                    selectedClue: viewModel.selectedClue,
                    onClueSelect: { clue in
                        viewModel.selectClue(clue)
                    }
                )

                CrosswordKeyboardView(
                    onKeyTap: { letter in
                        viewModel.inputLetter(letter)
                    },
                    onDelete: {
                        viewModel.deleteLetter()
                    }
                )
            }

            if viewModel.gameState == .completed {
                CrosswordCompletionView(
                    elapsedSeconds: viewModel.elapsedSeconds,
                    onBack: onDismiss
                )
            }
        }
    }
}
```

---

## Verification Checklist

- [ ] Build and run in Xcode simulator
- [ ] Navigate to Games tab and tap "Aggie Crossword"
- [ ] Test cell selection: tap cells, verify highlighting
- [ ] Test direction toggle: tap same cell twice at intersection
- [ ] Test input: type letters, verify auto-advance
- [ ] Test backspace: delete letters, verify navigation
- [ ] Test clue interaction: tap clues, verify grid selection
- [ ] Complete puzzle: fill all cells correctly, verify completion overlay
- [ ] Test persistence: close and reopen app, verify state restored
- [ ] Test timer: verify time tracking works

---

## Notes

- **Don't edit files in `prompts/`** - specifications only
- **Don't commit code** - user handles git
- **Don't modify iOS project files** - user will add files to Xcode manually
- **Re-read files before modifying** - code may have changed
- **Ask questions if unclear**
