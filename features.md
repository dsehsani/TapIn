# Features Documentation

## Feature Overview

TapIn provides a comprehensive local news and games experience for the UC Davis community. Below is documentation for all implemented and planned features.

---

## 1. Aggie Wordle

### Description

A daily word-guessing game inspired by the New York Times Wordle, customized for the UC Davis community. Players have 6 attempts to guess a 5-letter word, with color-coded feedback after each guess.

### Status: **Implemented**

### User Stories

- As a player, I want to play a daily Wordle puzzle so that I can challenge myself each day
- As a player, I want to see my guess results with color feedback so I know which letters are correct
- As a player, I want my progress saved so I can return to an incomplete game
- As a player, I want to compete on a leaderboard so I can compare with other players
- As a player, I want to play past puzzles from the archive so I can catch up on missed days

### Game Rules

1. Guess the 5-letter word in 6 tries or fewer
2. After each guess, tiles change color:
   - **Green**: Letter is correct and in the right position
   - **Gold**: Letter is in the word but wrong position
   - **Gray**: Letter is not in the word
3. Each guess must be a valid 5-letter word
4. One puzzle per day (same word for all players)

### Technical Implementation

| Component | Location |
|-----------|----------|
| Game View | `Games/Wordle/Views/WordleGameView.swift` |
| Game Logic | `Games/Wordle/ViewModels/GameViewModel.swift` |
| Grid Display | `Games/Wordle/Views/GameGridView.swift` |
| Keyboard | `Games/Wordle/Views/KeyboardView.swift` |
| Tile Animation | `Games/Wordle/Views/TileView.swift` |
| Archive | `Games/Wordle/Views/ArchiveView.swift` |
| Persistence | `Games/Wordle/Services/GameStorage.swift` |
| Daily Word | `Games/Wordle/Services/DateWordGenerator.swift` |
| Leaderboard API | `Services/LeaderboardService.swift` |

### Sub-Features

#### Daily Mode
- Deterministic word generation based on date
- Same word for all players on the same day
- Progress persists across app restarts
- Score submitted to leaderboard upon completion

#### Archive Mode
- Browse and play past puzzles
- Calendar-based date selection
- Completed puzzles marked with win/loss status
- Archive scores not submitted to leaderboard

#### Animated Tile Reveals
- Staggered flip animation on guess submission
- Each tile flips with slight delay for dramatic effect
- Color revealed during flip animation

#### Leaderboard Integration
- Automatic score submission for daily puzzles
- Top 5 players displayed after game completion
- Ranking by guesses (primary) and time (secondary)
- Anonymous usernames (Adjective+Noun format)

### Test Cases

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| Valid guess submission | Enter valid 5-letter word | Word accepted, tiles flip with feedback |
| Invalid word rejection | Enter non-dictionary word | Error message, guess not consumed |
| Win condition | Guess correct word | Game ends, "You Won!" displayed, score submitted |
| Loss condition | Use all 6 guesses incorrectly | Game ends, correct word revealed |
| Letter state tracking | Enter duplicate letters | Each instance evaluated independently |
| Keyboard color update | Submit guess | Keyboard keys update to match tile colors |
| Game persistence | Close and reopen app | Game state restored exactly |
| Archive navigation | Select past date | Load that day's puzzle |
| Leaderboard display | Complete daily puzzle | Show top 5 with ranks and times |

---

## 2. News Feed

### Description

Browse UC Davis news and local articles with category filtering, search functionality, and featured article highlights.

### Status: **Implemented (Sample Data)**

### User Stories

- As a reader, I want to browse news articles so I can stay informed about campus events
- As a reader, I want to filter by category so I can find relevant content quickly
- As a reader, I want to search articles so I can find specific topics
- As a reader, I want to save articles for later reading

### Features

| Feature | Description |
|---------|-------------|
| Category Filtering | Filter by Research, Campus Life, Athletics, etc. |
| Featured Articles | Highlighted articles with larger cards |
| Search | Search articles by title and content |
| Pull to Refresh | Refresh article feed |
| Save/Bookmark | Save articles to read later |

### Technical Implementation

| Component | Location |
|-----------|----------|
| News View | `Views/NewsView.swift` |
| View Model | `ViewModels/NewsViewModel.swift` |
| Article Model | `Models/NewsArticle.swift` |
| Category Pills | `Components/CategoryPillsView.swift` |
| Featured Card | `Components/FeaturedArticleCard.swift` |

### Test Cases

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| Load articles | Open News tab | Articles display in feed |
| Filter by category | Tap category pill | Only matching articles shown |
| Search articles | Enter search query | Matching articles displayed |
| Save article | Tap bookmark icon | Article added to Saved tab |

---

## 3. Campus Events

### Description

View and filter campus events including official university events and student-posted activities.

### Status: **Implemented (Sample Data)**

### User Stories

- As a student, I want to see upcoming campus events so I can plan my schedule
- As a student, I want to filter events by type so I can find relevant activities
- As a student, I want to distinguish official from student events

### Features

| Feature | Description |
|---------|-------------|
| Event List | Scrollable list of upcoming events |
| Filter Options | All, Official, Student Posted, Today, This Week |
| Event Details | Title, description, date, time, location |
| Official Badge | Visual indicator for official events |
| Save Events | Bookmark events for reference |

### Technical Implementation

| Component | Location |
|-----------|----------|
| Campus View | `Views/CampusView.swift` |
| View Model | `ViewModels/CampusViewModel.swift` |
| Event Model | `Models/CampusEvent.swift` |

### Test Cases

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| Load events | Open Campus tab | Events display in list |
| Filter by type | Select filter option | Only matching events shown |
| Official badge | View official event | Badge displayed on card |
| Save event | Tap save button | Event added to Saved tab |

---

## 4. Saved Content

### Description

Manage bookmarked articles and events in a centralized location.

### Status: **Implemented**

### User Stories

- As a user, I want to view all my saved content in one place
- As a user, I want to remove items I no longer need
- As a user, I want to separate saved articles from saved events

### Features

| Feature | Description |
|---------|-------------|
| Segmented View | Toggle between Articles and Events |
| Remove Items | Swipe or tap to remove saved items |
| Empty States | Helpful message when no saved content |
| Quick Access | Tap to navigate to full content |

### Technical Implementation

| Component | Location |
|-----------|----------|
| Saved View | `Views/SavedView.swift` |
| View Model | `ViewModels/SavedViewModel.swift` |

### Test Cases

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| View saved articles | Open Saved tab, Articles segment | Saved articles displayed |
| View saved events | Switch to Events segment | Saved events displayed |
| Remove article | Tap remove button | Article removed from list |
| Empty state | No saved content | Empty state message shown |

---

## 5. User Profile & Settings

### Description

User authentication, profile management, and app settings.

### Status: **Implemented**

### User Stories

- As a user, I want to create an account so my data syncs across devices
- As a user, I want to sign in so I can access my saved content
- As a user, I want to toggle dark mode for comfortable viewing
- As a user, I want to manage notification preferences

### Features

| Feature | Description |
|---------|-------------|
| Sign In/Register | Email-based authentication |
| Profile Display | User name and avatar |
| Dark Mode Toggle | Switch between light and dark themes |
| Notifications Toggle | Enable/disable push notifications |
| Sign Out | Log out of account |
| About/Help | App information and support |

### Technical Implementation

| Component | Location |
|-----------|----------|
| Profile View | `Views/ProfileView.swift` |
| View Model | `ViewModels/ProfileViewModel.swift` |
| App State | `App/AppState.swift` |

### Test Cases

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| Sign in | Enter credentials, tap Sign In | User authenticated, profile shown |
| Register | Enter details, tap Register | Account created, user signed in |
| Toggle dark mode | Tap dark mode switch | App theme changes |
| Sign out | Tap Sign Out | User logged out, sign in shown |

---

## 6. Custom Navigation

### Description

Custom tab bar navigation with UC Davis branding and intuitive section switching.

### Status: **Implemented**

### Features

| Feature | Description |
|---------|-------------|
| 5-Tab Navigation | News, Campus, Games, Saved, Profile |
| Games Highlight | Gold accent on Games tab |
| Active Indicator | Visual highlight for selected tab |
| Smooth Animation | Animated tab transitions |

### Technical Implementation

| Component | Location |
|-----------|----------|
| Tab Bar | `Components/CustomTabBar.swift` |
| Tab Model | `Models/TabItem.swift` |
| Main Container | `Views/ContentView.swift` |

---

## 7. Game Statistics

### Description

Track and display player performance across all games.

### Status: **Implemented**

### Features

| Feature | Description |
|---------|-------------|
| Games Played | Total number of games completed |
| Win Count | Total games won |
| Current Streak | Consecutive days played/won |
| Best Streak | Maximum consecutive streak |

### Technical Implementation

| Component | Location |
|-----------|----------|
| Games View | `Views/GamesView.swift` |
| View Model | `ViewModels/GamesViewModel.swift` |
| Stats Model | `Models/Game.swift` (GameStats) |

---

## Planned Features

### Trivia Game
- UC Davis themed trivia questions
- Multiple choice format
- Leaderboard integration

### Crossword Puzzle
- UC Davis themed crosswords
- Touch-based input
- Hint system

### News Web Scraping
- Automatic article fetching from UC Davis sources
- Real-time updates

### Push Notifications
- Daily puzzle reminders
- Breaking news alerts
- Event reminders

### Social Features
- Friend leaderboards
- Share game results
- Challenge friends
