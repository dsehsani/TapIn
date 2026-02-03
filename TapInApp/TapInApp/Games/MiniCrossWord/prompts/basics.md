# MiniCrossWord Implementation Plan

## Overview

Implement a 5x5 MiniCrossWord game for the TapIn iOS app, following the existing MVVM architecture pattern from the Wordle game. The crossword mimics the NY Times "The Mini" with interactive cell selection, direction toggling, clue highlighting, timer, and progress persistence.

---

## File Structure

```
TapInApp/TapInApp/Games/MiniCrossWord/
├── Models/
│   ├── CrosswordDirection.swift      # Enum: across, down
│   ├── CrosswordGameState.swift      # Enum: playing, completed
│   ├── CrosswordClue.swift           # Clue with direction, number, text, answer
│   ├── CrosswordCell.swift           # Single grid cell with clue associations
│   ├── CrosswordPuzzle.swift         # Complete puzzle definition
│   └── StoredCrosswordState.swift    # Codable for persistence
├── ViewModels/
│   └── CrosswordViewModel.swift      # @Observable game logic
├── Views/
│   ├── MiniCrosswordGameView.swift   # Main entry view
│   ├── CrosswordGridView.swift       # 5x5 grid container
│   ├── CrosswordCellView.swift       # Individual cell
│   ├── ClueListView.swift            # Scrollable clue display
│   ├── ClueRowView.swift             # Single clue row
│   ├── CrosswordHeaderView.swift     # Navigation and timer
│   ├── CrosswordKeyboardView.swift   # Letter input
│   └── CrosswordCompletionView.swift # Results overlay
├── Services/
│   ├── CrosswordStorage.swift        # UserDefaults persistence
│   └── CrosswordPuzzleProvider.swift # Puzzle loading/selection
└── Data/
    └── SamplePuzzles.swift           # 2-3 hardcoded sample puzzles
```

---

## Data Models

### CrosswordDirection.swift

```swift
enum CrosswordDirection: String, Codable {
    case across, down
    var opposite: CrosswordDirection { self == .across ? .down : .across }
}
```

### CrosswordClue.swift

- `number: Int` - Clue number (1, 2, 3...)
- `direction: CrosswordDirection`
- `text: String` - The clue hint
- `answer: String` - Correct answer (uppercase)
- `startRow: Int`, `startCol: Int` - Grid position
- **Computed:** `cellPositions` - All cells this clue spans

### CrosswordCell.swift

- `row: Int`, `col: Int` - Position
- `isBlocked: Bool` - Black/unused cell
- `letter: Character?` - User input
- `correctLetter: Character` - Correct answer
- `clueNumber: Int?` - Number in top-left (if word start)
- `acrossClueID: UUID?`, `downClueID: UUID?` - Clue associations
- `isRevealed: Bool`, `isChecked: Bool`, `isIncorrect: Bool` - Validation states

### CrosswordPuzzle.swift

- `title: String`, `author: String`
- `dateKey: String` - "2026-02-01" format
- `gridSize: Int` - Always 5
- `clues: [CrosswordClue]`
- `blockedCells: Set<String>` - "row,col" format

---

## ViewModel: CrosswordViewModel.swift

### State Properties

- `currentPuzzle: CrosswordPuzzle?`
- `grid: [[CrosswordCell]]` - 5x5 cell array
- `gameState: CrosswordGameState`
- `selectedRow: Int?`, `selectedCol: Int?`
- `currentDirection: CrosswordDirection`
- `selectedClue: CrosswordClue?`
- `elapsedSeconds: Int`

### Key Methods

- `loadPuzzle(for dateKey:)` - Load and build grid
- `selectCell(row:col:)` - Handle cell tap
- `toggleDirection()` - Switch across/down
- `inputLetter(_:)` - Add letter, auto-advance
- `deleteLetter()` - Remove letter, move back
- `selectClue(_:)` - Select from clue list
- `checkAnswers()` - Validate user input
- `revealCell()` / `revealWord()` / `revealPuzzle()` - Show answers
- `checkCompletion()` - Detect win state

### Cell Selection Logic

1. Tap unselected cell → select it, use across (or down if no across clue)
2. Tap selected cell → toggle direction if intersection
3. After typing → auto-advance to next cell in direction
4. Backspace → delete current letter, move to previous cell

---

## View Components

### MiniCrosswordGameView.swift (Main Entry)

```swift
ZStack {
    Background color
    VStack {
        CrosswordHeaderView (back button, timer, menu)
        CurrentClueView (selected clue banner)
        CrosswordGridView (5x5 grid)
        ClueListView (Across/Down tabs)
        CrosswordKeyboardView
    }
    CrosswordCompletionView (overlay when won)
}
```

### CrosswordCellView.swift

- **Background colors:** blocked (black), selected (gold), highlighted (light gold), incorrect (red tint), revealed (orange tint)
- Clue number in top-left corner
- Letter centered
- Border highlights selection

### ClueListView.swift

- Tabs for Across / Down
- Scrollable list of ClueRowView
- Auto-scroll to selected clue

---

## Services

### CrosswordStorage.swift (Singleton)

- `saveGameState(...)` - Persist to UserDefaults
- `loadGameState(for:)` - Restore saved state
- `isDateCompleted(_:)` - Check completion status
- **Key:** `"crosswordGameStates"`

### CrosswordPuzzleProvider.swift (Singleton)

- `puzzleForDate(_:)` - Get puzzle (cycles through samples)
- `todaysPuzzle()` - Convenience for today

---

## Sample Puzzle Data (SamplePuzzles.swift)

**Puzzle 1: "Go Aggies!" (UC Davis Theme)**

```
      0   1   2   3   4
  0 [A] [G] [G] [I] [E]   1-Across: AGGIE
  1 [R] [B] [L] [U] [E]   4-Across: BLUE
  2 [S] [T] [U] [D] [Y]   6-Across: STUDY
  3 [█] [█] [C] [O] [W]   8-Across: COW
  4 [T] [R] [E] [K] [█]   9-Across: TREK
```

Create 2-3 puzzles with UC Davis / college themes.

---

## Implementation Order

### Phase 1: Models (Files 1-6)

1. CrosswordDirection.swift
2. CrosswordGameState.swift
3. CrosswordClue.swift
4. CrosswordCell.swift
5. CrosswordPuzzle.swift
6. StoredCrosswordState.swift

### Phase 2: Data Layer (Files 7-9)

7. SamplePuzzles.swift
8. CrosswordPuzzleProvider.swift
9. CrosswordStorage.swift

### Phase 3: ViewModel (File 10)

10. CrosswordViewModel.swift - Grid init, selection, input, navigation

### Phase 4: Core Views (Files 11-14)

11. CrosswordCellView.swift
12. CrosswordGridView.swift
13. CrosswordKeyboardView.swift
14. MiniCrosswordGameView.swift

### Phase 5: Supporting Views (Files 15-18)

15. ClueRowView.swift
16. ClueListView.swift
17. CrosswordHeaderView.swift
18. CrosswordCompletionView.swift

### Phase 6: Features

19. Timer functionality
20. Check answers feature
21. Reveal cell/word/puzzle
22. Win detection
23. Progress persistence

### Phase 7: App Integration

24. Update GamesViewModel.swift - Add showingCrossword property
25. Update GamesView.swift - Add .fullScreenCover for crossword
26. Add crossword colors to ColorExtensions.swift if needed

---

## App Integration Changes

### GamesViewModel.swift

```swift
@Published var showingCrossword: Bool = false

func startGame(_ game: Game) {
    currentGame = game
    switch game.type {
    case .wordle: showingWordle = true
    case .crossword: showingCrossword = true
    case .trivia: break
    }
}
```

### GamesView.swift

```swift
.fullScreenCover(isPresented: $viewModel.showingCrossword) {
    MiniCrosswordGameView(onDismiss: { viewModel.dismissGame() })
}
```

---

## Critical Reference Files

- `Games/Wordle/ViewModels/GameViewModel.swift` - ViewModel pattern
- `Games/Wordle/Views/WordleGameView.swift` - View structure
- `Games/Wordle/Services/GameStorage.swift` - Persistence pattern
- `ViewModels/GamesViewModel.swift` - Integration point
- `Extensions/ColorExtensions.swift` - Color definitions

---

## Verification

1. Build and run the app in Xcode simulator
2. Navigate to Games tab and tap "Aggie Crossword"
3. Test cell selection: tap cells, verify highlighting
4. Test direction toggle: tap same cell twice at intersection
5. Test input: type letters, verify auto-advance
6. Test backspace: delete letters, verify navigation
7. Test clue interaction: tap clues, verify grid selection
8. Complete puzzle: fill all cells correctly, verify completion overlay
9. Test persistence: close and reopen app, verify state restored
10. Test timer: verify time tracking works
