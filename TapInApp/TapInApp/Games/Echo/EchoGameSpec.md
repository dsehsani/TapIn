# Echo Game Specification

## Overview

**Echo** is a memory-meets-logic puzzle game where the player is shown a short sequence of colored shapes, then must reconstruct the final sequence after a series of transformation rules are applied to it. The player sees the original sequence for 2 seconds, then rules appear one by one. The player must mentally apply each rule in order and input the resulting final sequence. They have 3 attempts before the correct answer is revealed.

---

## Architecture

This game follows the existing **MVVM (Model-View-ViewModel)** pattern established in the TapIn codebase.

```
Games/Echo/
├── Models/
│   ├── EchoShape.swift
│   ├── EchoColor.swift
│   ├── EchoItem.swift
│   ├── EchoRule.swift
│   ├── EchoRound.swift
│   └── EchoGameState.swift
├── Views/
│   ├── EchoGameView.swift          (root game view, state router)
│   ├── SequenceDisplayView.swift   (shows the original sequence)
│   ├── RuleRevealView.swift        (reveals rules one by one)
│   ├── SequenceInputView.swift     (player builds their answer)
│   ├── ShapeItemView.swift         (renders a single shape+color)
│   ├── ShapePicker.swift           (shape selection toolbar)
│   ├── FeedbackView.swift          (correct/incorrect after submit)
│   ├── RoundResultView.swift       (end-of-round summary)
│   └── EchoHeaderView.swift        (top bar with back, round, attempts)
├── ViewModels/
│   └── EchoGameViewModel.swift
└── Services/
    └── EchoRoundGenerator.swift    (generates sequences and rules)
```

---

## Data Models

### `EchoShape` (enum)

Represents the four possible geometric shapes.

```
enum EchoShape: String, CaseIterable, Codable {
    case circle
    case triangle
    case square
    case pentagon
}
```

**SF Symbol mapping for rendering:**
| Shape    | SF Symbol             |
|----------|-----------------------|
| circle   | `circle.fill`         |
| triangle | `triangle.fill`       |
| square   | `square.fill`         |
| pentagon | `pentagon.fill`       |

### `EchoColor` (enum)

Represents the four possible colors for shapes.

```
enum EchoColor: String, CaseIterable, Codable {
    case blue
    case red
    case yellow
    case green
}
```

**SwiftUI Color mapping:**
| EchoColor | SwiftUI Color          |
|-----------|------------------------|
| blue      | `Color.blue`           |
| red       | `Color.red`            |
| yellow    | `Color.yellow`         |
| green     | `Color.green`          |

**Color swap cycle (used by the `colorSwap` rule):**
```
blue -> red -> yellow -> green -> blue
```
Each color advances one step forward in the cycle.

### `EchoItem` (struct)

A single element in a sequence: one shape with one color.

```
struct EchoItem: Identifiable, Equatable, Codable {
    let id: UUID
    var shape: EchoShape
    var color: EchoColor
}
```

### `EchoRule` (enum)

The four transformation rules that can be applied to a sequence.

```
enum EchoRule: String, CaseIterable, Codable {
    case reversed
    case shifted
    case removedEverySecond
    case colorSwapped
}
```

**Rule definitions:**

| Rule                | Display Name          | Description                                         | Example (input -> output)                                    |
|---------------------|-----------------------|-----------------------------------------------------|--------------------------------------------------------------|
| `reversed`          | "Reverse"             | Reverse the order of the entire sequence.           | `[A, B, C, D]` -> `[D, C, B, A]`                            |
| `shifted`           | "Shift Right"         | Move the last item to the front (rotate right by 1).| `[A, B, C, D]` -> `[D, A, B, C]`                            |
| `removedEverySecond`| "Remove Every 2nd"    | Remove items at index 1, 3, 5... (0-indexed).       | `[A, B, C, D]` -> `[A, C]`                                  |
| `colorSwapped`      | "Color Swap"          | Advance every item's color one step in the cycle.   | `[blue-circle, red-triangle]` -> `[red-circle, yellow-triangle]` |

**Rule application order:** Rules are applied **sequentially** in the order they are revealed. The output of rule N becomes the input of rule N+1.

### `EchoRound` (struct)

Represents one complete round of the game.

```
struct EchoRound {
    let originalSequence: [EchoItem]
    let rules: [EchoRule]
    let correctAnswer: [EchoItem]     // pre-computed result of applying all rules
}
```

### `EchoGameState` (enum)

The overall state machine for the game.

```
enum EchoGameState {
    case showingSequence       // displaying original sequence (2-second timer)
    case revealingRules        // rules appearing one by one
    case playerInput           // player is building their answer sequence
    case evaluating            // checking the player's submission
    case roundComplete         // showing result of the round (correct or out of attempts)
    case gameOver              // all rounds completed, final summary
}
```

---

## ViewModel

### `EchoGameViewModel` (class, @Observable)

Central game logic manager. Uses the `@Observable` macro (consistent with the Wordle game's pattern).

**Properties:**

```
// --- Game Configuration ---
let totalRounds: Int = 5                     // number of rounds per game session
let maxAttempts: Int = 3                     // attempts allowed per round
let sequenceDisplayDuration: Double = 2.0    // seconds to show the original sequence
let ruleRevealInterval: Double = 1.5         // seconds between each rule reveal

// --- Round State ---
var currentRoundIndex: Int = 0               // 0-based index of the current round
var currentRound: EchoRound?                 // the active round data
var attemptsRemaining: Int = 3               // attempts left for this round
var gameState: EchoGameState = .showingSequence

// --- Player Input ---
var playerSequence: [EchoItem] = []          // the sequence the player is building
var selectedSlotIndex: Int? = nil            // which slot the player is currently editing (nil = appending)

// --- Rule Reveal State ---
var revealedRuleCount: Int = 0               // how many rules have been shown so far
var currentlyRevealingRuleIndex: Int = -1    // index of rule currently animating in

// --- Feedback ---
var lastSubmissionCorrect: Bool? = nil       // nil = not yet submitted, true/false after check
var showCorrectAnswer: Bool = false          // true when all attempts exhausted

// --- Scoring ---
var score: Int = 0                           // cumulative score across rounds
var roundScores: [Int] = []                  // score for each completed round
var roundResults: [Bool] = []                // true = solved, false = failed, per round

// --- All Rounds ---
var rounds: [EchoRound] = []                 // pre-generated rounds for this session
```

**Key Methods:**

```
// --- Lifecycle ---
func startGame()
    // Generates all rounds via EchoRoundGenerator, resets all state, begins round 1.

func startRound()
    // Sets currentRound, resets attemptsRemaining to 3, clears playerSequence,
    // transitions to .showingSequence state, starts 2-second display timer.

func advanceToNextRound()
    // Increments currentRoundIndex. If < totalRounds, calls startRound().
    // Otherwise transitions to .gameOver.

// --- Sequence Display Phase ---
func onSequenceDisplayComplete()
    // Called after the 2-second timer. Transitions to .revealingRules.
    // Starts revealing rules one by one.

// --- Rule Reveal Phase ---
func revealNextRule()
    // Increments revealedRuleCount. Shows the next rule with animation.
    // After all rules revealed, waits ruleRevealInterval then transitions
    // to .playerInput.

// --- Player Input Phase ---
func addItemToSequence(shape: EchoShape, color: EchoColor)
    // Appends a new EchoItem to playerSequence.

func updateItem(at index: Int, shape: EchoShape)
    // Changes the shape of the item at the given index.

func updateItem(at index: Int, color: EchoColor)
    // Changes the color of the item at the given index.

func cycleColor(at index: Int)
    // Advances the color of the item at the given index to the next color
    // in the cycle: blue -> red -> yellow -> green -> blue.
    // This is the primary way users change color — by tapping an already-placed shape.

func removeItem(at index: Int)
    // Removes the item at the given index from playerSequence.

func clearPlayerSequence()
    // Removes all items from playerSequence.

// --- Submission ---
func submitAnswer()
    // Compares playerSequence to currentRound.correctAnswer.
    // If correct: set lastSubmissionCorrect = true, calculate score, transition to .roundComplete.
    // If incorrect: decrement attemptsRemaining.
    //   - If attemptsRemaining > 0: set lastSubmissionCorrect = false (player can retry).
    //   - If attemptsRemaining == 0: set showCorrectAnswer = true, transition to .roundComplete.

// --- Scoring ---
func calculateRoundScore() -> Int
    // Score = attemptsRemaining * 100
    // (300 for first try, 200 for second, 100 for third, 0 if failed)
```

---

## Round Generation

### `EchoRoundGenerator` (struct/class)

Generates random rounds with increasing difficulty.

**Difficulty Progression (by round index 0-4):**

| Round | Sequence Length | Number of Rules |
|-------|----------------|-----------------|
| 0     | 3              | 1               |
| 1     | 4              | 1               |
| 2     | 4              | 2               |
| 3     | 5              | 2               |
| 4     | 5              | 3               |

**Generation Logic:**

```
func generateRound(roundIndex: Int) -> EchoRound
```

1. Determine `sequenceLength` and `ruleCount` from the difficulty table above.
2. Generate `sequenceLength` random `EchoItem`s (random shape + random color each).
3. Select `ruleCount` random rules from `EchoRule.allCases` (rules CAN repeat across rounds, but within a single round each rule should be unique — no duplicate rules in one round).
4. **Constraint:** If the sequence will have `removedEverySecond` applied, ensure the sequence has at least 3 items at the point that rule is applied (so the result is non-empty). If after applying prior rules the sequence has fewer than 3 items, re-select that rule.
5. Compute `correctAnswer` by applying each rule sequentially to the sequence.
6. Return the `EchoRound`.

**Rule Application Implementation:**

```
func applyRule(_ rule: EchoRule, to sequence: [EchoItem]) -> [EchoItem]
```

- `reversed`: `sequence.reversed()`
- `shifted`: Move last element to index 0. `[sequence.last!] + sequence.dropLast()`
- `removedEverySecond`: Keep items at even indices (0, 2, 4...). `sequence.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }`
- `colorSwapped`: Map each item's color to the next in cycle. New `EchoItem` with same shape, next color.

---

## Screens & States

The game has **6 distinct screens/states**, controlled by `EchoGameState`. The root `EchoGameView` switches between them.

---

### Screen 1: Sequence Display (`EchoGameState.showingSequence`)

**Purpose:** Show the original sequence to the player for memorization.

**Layout:**

```
┌─────────────────────────────────────┐
│  [<Back]     Round 1/5      ●●●    │  <- EchoHeaderView
│                                     │
│                                     │
│            "Memorize this           │
│             sequence"               │
│                                     │
│                                     │
│     🔺    🔵    🔺    🟨           │  <- SequenceDisplayView
│    (red) (blue) (red) (yellow)      │     (colored shapes in a row)
│                                     │
│                                     │
│          ━━━━━━━━━━━━━━━            │  <- 2-second countdown bar
│          (progress bar)             │     (animates from full to empty)
│                                     │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

**Behavior:**
- Shapes appear with a scale-in animation (each shape pops in with a 0.15s stagger).
- A horizontal progress bar counts down 2 seconds.
- After 2 seconds, the sequence fades out and transitions to rule reveal.
- The `●●●` in the header represents attempts remaining (3 filled dots).

**Components used:**
- `EchoHeaderView` — displays back button, round indicator (`Round X/5`), and attempt dots.
- `SequenceDisplayView` — renders the `[EchoItem]` as a horizontal row of `ShapeItemView`s.
- A `ProgressView` or custom bar for the countdown timer.

---

### Screen 2: Rule Reveal (`EchoGameState.revealingRules`)

**Purpose:** Show the transformation rules one at a time so the player knows what to apply.

**Layout:**

```
┌─────────────────────────────────────┐
│  [<Back]     Round 1/5      ●●●    │  <- EchoHeaderView
│                                     │
│                                     │
│          "Apply these rules"        │
│                                     │
│   ┌─────────────────────────────┐   │
│   │  1. Reverse                 │   │  <- Rule card (slides in from right)
│   │     "Reverse the sequence"  │   │
│   └─────────────────────────────┘   │
│                                     │
│   ┌─────────────────────────────┐   │
│   │  2. Color Swap              │   │  <- Rule card (slides in after delay)
│   │     "Advance each color     │   │
│   │      one step in the cycle" │   │
│   └─────────────────────────────┘   │
│                                     │
│         (waiting for next rule      │
│          or transition...)          │
│                                     │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

**Behavior:**
- Rules appear one at a time with a slide-in-from-right animation.
- Each rule card shows: the rule number, the rule name (bold), and a short description.
- `ruleRevealInterval` (1.5 seconds) pause between each rule appearing.
- After the last rule is revealed, a 1.5-second pause, then auto-transition to player input.
- The original sequence is NOT visible on this screen (the player must remember it).

**Rule card descriptions:**

| Rule                | Card Title         | Card Description                                |
|---------------------|--------------------|-------------------------------------------------|
| `reversed`          | "Reverse"          | "Reverse the order of the sequence"             |
| `shifted`           | "Shift Right"      | "Move the last item to the front"               |
| `removedEverySecond`| "Remove Every 2nd" | "Remove every second item (2nd, 4th, ...)"      |
| `colorSwapped`      | "Color Swap"       | "Advance each color one step in the cycle"       |

**Components used:**
- `EchoHeaderView`
- `RuleRevealView` — manages the staggered reveal of rule cards.

---

### Screen 3: Player Input (`EchoGameState.playerInput`)

**Purpose:** The player constructs their answer sequence by selecting shapes and tapping to cycle colors.

**Layout:**

```
┌─────────────────────────────────────┐
│  [<Back]     Round 1/5      ●●○    │  <- EchoHeaderView (1 attempt used)
│                                     │
│           "Build your answer"       │
│                                     │
│  Rules applied:                     │
│  [Reverse] [Color Swap]            │  <- Compact rule reminder pills
│                                     │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │   🔺    🔵    🔺    +      │    │  <- Answer slots (player's sequence)
│  │  (tap shape to cycle color) │    │     Last slot is "+" to add more
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌──────┐┌──────┐┌──────┐┌──────┐  │
│  │  ○   ││  △   ││  □   ││  ⬠   │  │  <- ShapePicker (tap to append)
│  │circle││ tri  ││ sq   ││penta │  │     Each shape shown in default blue
│  └──────┘└──────┘└──────┘└──────┘  │
│                                     │
│    [Clear]                [Submit]  │  <- Action buttons
│                                     │
└─────────────────────────────────────┘
```

**Behavior:**

1. **Shape Picker (bottom toolbar):**
   - 4 buttons, one for each shape (circle, triangle, square, pentagon).
   - Each button shows the shape icon rendered in a neutral/default color (blue).
   - Tapping a shape button **appends** a new `EchoItem(shape: tappedShape, color: .blue)` to `playerSequence`.

2. **Answer Slots (center area):**
   - Displays the current `playerSequence` as a horizontal row of `ShapeItemView`s.
   - Each placed shape is rendered in its current color.
   - **Tapping an existing shape** cycles its color to the next in the cycle: `blue -> red -> yellow -> green -> blue`. This calls `cycleColor(at:)`.
   - **Long-pressing an existing shape** removes it from the sequence. This calls `removeItem(at:)`.
   - A `+` placeholder appears after the last item to indicate more can be added.
   - If the sequence is empty, a placeholder text reads "Tap a shape below to begin".

3. **Rule Reminder Pills:**
   - Small horizontal pill-shaped labels showing the rules that were revealed (e.g., `[Reverse]` `[Color Swap]`).
   - These are static reminders so the player doesn't need to memorize the rules.

4. **Action Buttons:**
   - **"Clear"** (left) — Calls `clearPlayerSequence()`. Removes all items. Disabled if sequence is empty.
   - **"Submit"** (right) — Calls `submitAnswer()`. Disabled if `playerSequence` is empty.

5. **Attempt indicator:**
   - The header shows filled/empty dots for remaining attempts (e.g., `●●○` = 1 attempt used, 2 remaining).

**Components used:**
- `EchoHeaderView`
- `SequenceInputView` — the answer slot area with tappable shapes.
- `ShapePicker` — the 4-shape selection toolbar.
- Compact rule pills (inline within `SequenceInputView` or `EchoGameView`).

---

### Screen 4: Evaluating / Feedback (`EchoGameState.evaluating`)

**Purpose:** Brief visual feedback after the player submits their answer.

This is a transient state (0.5-1 second) that overlays the input screen.

**If correct:**

```
┌─────────────────────────────────────┐
│                                     │
│            ✓ Correct!               │  <- Green checkmark, scale-up animation
│                                     │
│     🔺    🔵    🔺    🟨           │  <- Player's sequence with green
│                                     │     highlight/border on each item
│                                     │
└─────────────────────────────────────┘
```

**If incorrect (attempts remaining):**

```
┌─────────────────────────────────────┐
│                                     │
│          ✗ Not quite...             │  <- Red X, shake animation
│        "2 attempts remaining"       │
│                                     │
│     🔺    🔵    🔺    🟨           │  <- Player's sequence with red
│                                     │     highlight/border on each item
│                                     │
│          [Try Again]                │  <- Button returns to .playerInput
│                                     │
└─────────────────────────────────────┘
```

**If incorrect (no attempts remaining):**

```
┌─────────────────────────────────────┐
│                                     │
│         ✗ Out of attempts           │  <- Red X
│                                     │
│  Your answer:                       │
│     🔺    🔵    🔺    🟨           │  <- Player's (wrong) sequence
│                                     │
│  Correct answer:                    │
│     🟨    🔺    🔵    🔺           │  <- The correct sequence
│                                     │
│          [Continue]                 │  <- Proceeds to .roundComplete
│                                     │
└─────────────────────────────────────┘
```

**Behavior:**
- On correct: auto-transitions to `.roundComplete` after 1.5 seconds.
- On incorrect with attempts remaining: player taps "Try Again" to return to `.playerInput`. The `playerSequence` is NOT cleared — the player can modify their existing answer.
- On incorrect with 0 attempts: shows both sequences for comparison. Player taps "Continue" to proceed to `.roundComplete`.

**Components used:**
- `FeedbackView` — handles all three feedback states.

---

### Screen 5: Round Complete (`EchoGameState.roundComplete`)

**Purpose:** Summary of the round before moving to the next one.

**Layout:**

```
┌─────────────────────────────────────┐
│  [<Back]     Round 3/5             │
│                                     │
│                                     │
│          Round Complete!            │
│                                     │
│   ┌─────────────────────────────┐   │
│   │  Result:  ✓ Solved          │   │  <- or "✗ Failed"
│   │  Attempts used: 2/3         │   │
│   │  Round score: +200          │   │
│   └─────────────────────────────┘   │
│                                     │
│   Total score: 700                  │
│                                     │
│   Round history:                    │
│   [●] [●] [●] [○] [○]             │  <- Filled = completed, color = result
│    ✓   ✓   ✗                        │     green=solved, red=failed
│                                     │
│                                     │
│         [Next Round]                │  <- or [See Results] on last round
│                                     │
└─────────────────────────────────────┘
```

**Behavior:**
- Shows whether the round was solved or failed.
- Shows attempts used and the round's score contribution.
- Shows total cumulative score.
- Round history dots: one per round, filled for completed rounds, green for solved, red for failed, empty for upcoming.
- "Next Round" button calls `advanceToNextRound()`.
- On the final round (round 5), button reads "See Results" and transitions to `.gameOver`.

**Components used:**
- `RoundResultView`

---

### Screen 6: Game Over (`EchoGameState.gameOver`)

**Purpose:** Final summary of the entire game session.

**Layout:**

```
┌─────────────────────────────────────┐
│                                     │
│           Game Complete!            │
│                                     │
│        Final Score: 1100            │  <- Large, bold number
│                                     │
│   ┌─────────────────────────────┐   │
│   │  Rounds solved: 4/5         │   │
│   │  Perfect rounds: 2          │   │  <- solved on first attempt
│   │  Total attempts used: 9/15  │   │
│   └─────────────────────────────┘   │
│                                     │
│   Round breakdown:                  │
│   R1: ✓ 300pts (1st try)           │
│   R2: ✓ 200pts (2nd try)           │
│   R3: ✗   0pts                      │
│   R4: ✓ 300pts (1st try)           │
│   R5: ✓ 300pts (1st try)           │
│                                     │
│                                     │
│  [Play Again]          [Back]       │
│                                     │
└─────────────────────────────────────┘
```

**Behavior:**
- "Play Again" calls `startGame()` to generate fresh rounds and restart.
- "Back" calls the `onDismiss` closure to return to the games hub.
- Scoring breakdown per round with attempt info.
- Summary stats: rounds solved, perfect rounds (first-try solves), total attempts.

**Components used:**
- A section within `EchoGameView` or a dedicated `GameOverSummaryView`.

---

## Game Flow (State Machine)

```
                    ┌──────────────┐
    startGame() -->│ showingSequence│
                    └──────┬───────┘
                           │ (2 sec timer)
                           ▼
                    ┌──────────────┐
                    │revealingRules│
                    └──────┬───────┘
                           │ (all rules revealed + 1.5s)
                           ▼
               ┌──>┌──────────────┐
               │   │ playerInput  │
               │   └──────┬───────┘
               │          │ (submit)
               │          ▼
               │   ┌──────────────┐
               │   │  evaluating  │
               │   └──────┬───────┘
               │          │
               │    ┌─────┴──────┐
               │    │            │
               │ incorrect   correct
               │ (attempts>0)(or attempts==0)
               │    │            │
               └────┘            ▼
                          ┌──────────────┐
                          │roundComplete │
                          └──────┬───────┘
                                 │
                          ┌──────┴──────┐
                          │             │
                     more rounds    last round
                          │             │
                          ▼             ▼
                   ┌──────────┐  ┌──────────┐
                   │(next     │  │ gameOver  │
                   │ round    │  └───────────┘
                   │ ->showing│
                   │ Sequence)│
                   └──────────┘
```

---

## Component Details

### `ShapeItemView`

Renders a single `EchoItem` as a colored shape.

**Props:**
- `item: EchoItem` — the shape and color to render.
- `size: CGFloat` — width and height of the shape (default 50).
- `showBorder: Bool` — whether to show a selection/highlight border.
- `borderColor: Color` — color of the border (used for feedback: green = correct, red = incorrect).

**Rendering:**
- Uses SF Symbols: `circle.fill`, `triangle.fill`, `square.fill`, `pentagon.fill`.
- The symbol is rendered at the given `size` and colored with the item's `EchoColor` mapped to SwiftUI `Color`.
- When `showBorder` is true, a rounded rectangle outline appears around the shape.

### `ShapePicker`

A horizontal toolbar of 4 shape buttons.

**Props:**
- `onShapeSelected: (EchoShape) -> Void` — callback when a shape is tapped.

**Layout:** 4 equally-spaced buttons in an `HStack`. Each button shows the shape SF Symbol in a muted style (`.secondary` opacity or light gray background) with the shape name below it. Tapping calls the callback.

### `EchoHeaderView`

Consistent top navigation bar.

**Props:**
- `onBack: () -> Void` — back button action.
- `roundIndex: Int` — current round (0-based, displayed as 1-based).
- `totalRounds: Int` — total rounds.
- `attemptsRemaining: Int` — for rendering attempt dots.
- `maxAttempts: Int` — total possible attempts.
- `showAttempts: Bool` — whether to show the attempt dots (hidden during sequence display and rule reveal).

**Layout:**
```
[< Back]    Round X/Y    ●●○
```
- Back button on the left.
- "Round X/Y" centered.
- Attempt dots on the right (filled dot = attempt remaining, empty dot = attempt used).

---

## Animations

| Transition                        | Animation Type              | Duration |
|-----------------------------------|-----------------------------|----------|
| Sequence items appearing          | Scale from 0 to 1, stagger | 0.15s per item |
| Sequence fading out               | Opacity 1 -> 0             | 0.3s     |
| Rule card sliding in              | Slide from trailing edge    | 0.4s     |
| Transition to player input        | Opacity crossfade           | 0.3s     |
| Correct answer feedback           | Scale pulse (1 -> 1.1 -> 1)| 0.3s     |
| Incorrect answer feedback         | Horizontal shake            | 0.3s     |
| Player shape placed               | Scale from 0.5 to 1        | 0.2s     |
| Color cycle on tap                | Quick color crossfade       | 0.15s    |
| Round result card appearing       | Slide up from bottom        | 0.4s     |

---

## Scoring System

| Outcome            | Points |
|--------------------|--------|
| Correct on 1st try | 300    |
| Correct on 2nd try | 200    |
| Correct on 3rd try | 100    |
| Failed (0 attempts)| 0      |

**Maximum possible score:** 5 rounds x 300 = **1500 points**

---

## Integration with TapIn App

### 1. Register in `GameType` enum (`Models/Game.swift`)

Add a new case:
```swift
case echo = "echo"
```

With display name:
```swift
case .echo: return "Echo"
```

### 2. Add to `Game.sampleData` (`Models/Game.swift`)

```swift
Game(
    type: .echo,
    name: "Echo",
    description: "Memory meets logic — transform the sequence",
    iconName: "waveform.path",
    isMultiplayer: false,
    hasLeaderboard: true
)
```

### 3. Add navigation in `GamesViewModel` (`ViewModels/GamesViewModel.swift`)

Add a `@Published var showingEcho: Bool = false` property.

In `startGame(_:)`, add:
```swift
if game.type == .echo {
    showingEcho = true
}
```

In `dismissGame()`, add:
```swift
showingEcho = false
```

### 4. Add fullScreenCover in `GamesView` (`Views/GamesView.swift`)

```swift
.fullScreenCover(isPresented: $viewModel.showingEcho) {
    EchoGameView(onDismiss: {
        viewModel.dismissGame()
    })
}
```

### 5. `EchoGameView` entry point signature

```swift
struct EchoGameView: View {
    var onDismiss: () -> Void
    @State private var viewModel = EchoGameViewModel()
    @Environment(\.colorScheme) var colorScheme
    // ...
}
```

This matches the existing `WordleGameView` pattern.

---

## Color Scheme / Theming

Follow the existing app conventions:
- Use `Color.adaptiveBackground(colorScheme)` for the root background.
- Use `Color.ucdBlue` and `Color.ucdGold` for accents where appropriate.
- Dark mode support: use `colorScheme == .dark` conditionals as seen in the Wordle views.
- Rule cards and result cards should use the same card styling as `GameRowCard` in `GamesView.swift` (rounded rectangle, subtle border, shadow).

---

## Edge Cases

1. **`removedEverySecond` on a 2-item sequence:** Results in a 1-item sequence. This is valid.
2. **`removedEverySecond` on a 1-item sequence:** Results in a 1-item sequence (index 0 is kept). This is valid but trivial — the generator should avoid this by ensuring sequences have >= 3 items when this rule is selected.
3. **Multiple rules compounding:** e.g., `removedEverySecond` then `reversed` on a 4-item sequence yields a 2-item reversed sequence. The player must track the intermediate state.
4. **Player submits wrong-length sequence:** This is inherently handled — the submission comparison checks both length and content. A wrong-length answer is simply incorrect.
5. **Empty player sequence on submit:** The submit button is disabled when `playerSequence` is empty.
