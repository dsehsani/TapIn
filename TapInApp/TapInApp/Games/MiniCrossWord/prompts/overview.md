# MiniCrossword

We are building an iOS mobile app that mimics the New York Times "The Mini" crossword 
puzzle. "The Mini" is a daily crossword puzzle featuring a 5x5 grid where cells are 
selectively filled based on intersecting across and down clues.

## Core Features

### Crossword Gameplay
- 5x5 interactive grid with cell selection and input
- Across and Down clues displayed in separate sections
- Real-time answer validation
- Cell navigation (tap to select, auto-advance after typing)
- Direction toggling for cells that belong to both across and down words
- Win state detection when puzzle is correctly completed
- Timer to track solve duration

### Puzzle Management
- Mock puzzle data with 2-3 sample puzzles for testing
- Puzzle data structure supporting variable grid layouts (some cells blocked/unused)
- Ability to check answers or reveal solutions
- Progress persistence (save current puzzle state locally)

## Technical Stack

### iOS Client (SwiftUI)
- SwiftUI for UI components (Grid-based layout)
- State management for game logic (@State, @Published, ObservableObject)
- Local persistence using UserDefaults or SwiftData for puzzle progress
- Keyboard input handling
- Accessibility support (VoiceOver, Dynamic Type)

### Data Structure
- Puzzle model containing grid layout, clues, and solutions
- Cell model tracking position, correct answer, user input, and associated clues
- Support for blocked/unused cells in the 5x5 grid
- Mock data service providing hardcoded sample puzzles

### Mock Data
- 2-3 pre-built puzzles with varying difficulty
- JSON structure for puzzles (can be loaded from local JSON files or hardcoded)
- Sample puzzles designed to test different grid patterns and word intersections

## Development Approach

Building iOS SwiftUI implementation with focus on:
1. Core crossword gameplay mechanics
2. Grid rendering and interaction
3. Mock puzzle data service
4. Local puzzle solving and validation
5. State persistence between app sessions

All puzzle data will be mocked locally, allowing full functionality without any backend dependency.

## Project organization

From the top level directory of this repo, here are the main
subdirectories:

  - TapInApp: Currently where the main homepage that will act as a dashboard
  to interact wtth apps will be

  - MiniCrossword: Where the mini crossword game will be
  
  - prompts: Contains the prompts and information for the MiniCrossword

## Rules

- Don't edit any of the files in `prompts`. These are files that I
  will update manually as my specification evolves. The rest of the
  directories are where you will implement code and can make
  modifications.

- Don't commit any code using `git`. I'd like to inspect code you
  write before committing it.

- Don't push any code to GitHub. I'll handle pull request creation,
  etc, manually.

- Don't modify iOS project files. These are extremely tricky to get
  right, so I'll add any files you need manually.

- I will be making changes to the code periodically, so from one
  prompt to the next code may have changed. Please re-read any files
  you use to get their current state and don't assume that they are
  unchanged since your last modifications.

- Ask questions if something is unclear! I'm here to help so if my
  instructions are too ambiguous or unclear, let me know and I can
  elaborate.
