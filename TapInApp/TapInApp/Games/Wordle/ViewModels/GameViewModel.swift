//
//  GameViewModel.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/20/26.
//
//  MARK: - ViewModel Layer (MVVM)
//  This is the central ViewModel for the Wordle game. It manages all game logic,
//  state, and coordinates between the View layer and data persistence.
//
//  Architecture:
//  - Uses @Observable macro for reactive state updates
//  - Communicates with GameStorage for persistence
//  - Uses DateWordGenerator for daily word selection
//
//  Integration Notes:
//  - Instantiate in ContentView using @State
//  - Call loadGameForDate() to switch between dates
//  - Input methods: addLetter(), deleteLetter(), submitGuess()
//  - State is automatically persisted after each guess
//
//  Dependencies:
//  - Models: LetterTile, LetterState, GameState
//  - Services: GameStorage, DateWordGenerator
//

import SwiftUI

// MARK: - Game View Model
/// Central ViewModel managing all Wordle game logic and state.
///
/// Responsibilities:
/// 1. Grid state management (6 rows x 5 tiles)
/// 2. Input handling (add/delete letters, submit guesses)
/// 3. Word evaluation (correct/wrong position/not in word)
/// 4. Keyboard state tracking (letter colors)
/// 5. Animation coordination (staggered tile reveals)
/// 6. Game persistence (save/restore per date)
/// 7. Daily mode support (deterministic word per date)
///
/// Usage:
/// ```swift
/// @State private var viewModel = GameViewModel()
///
/// // In view body:
/// GameGridView(grid: viewModel.grid, revealingRow: viewModel.revealingRow)
/// KeyboardView(onKeyTap: viewModel.addLetter, ...)
/// ```
///
@Observable
class GameViewModel {

    // MARK: - Game Configuration

    /// Maximum number of guess attempts allowed
    let maxGuesses = 6

    /// Number of letters per word
    let wordLength = 5

    // MARK: - Game State

    /// The target word to guess (uppercase)
    var targetWord: String = ""

    /// Current row index (0-5) where next letter will be placed
    var currentRow: Int = 0

    /// Current tile index (0-4) within the current row
    var currentTile: Int = 0

    /// Current game state (playing, won, or lost)
    var gameState: GameState = .playing

    /// 2D array of tiles representing the game board
    /// Structure: grid[row][column] where row is guess attempt, column is letter position
    var grid: [[LetterTile]] = []

    /// Tracks the evaluation state of each letter on the keyboard
    /// Key: Uppercase letter character, Value: Best known state for that letter
    var keyboardStates: [Character: LetterState] = [:]

    /// Whether to show the "Not in word list" alert
    var showInvalidWordAlert: Bool = false

    // MARK: - Daily Mode Properties

    /// The date for the current game session
    var currentDate: Date = DateWordGenerator.today

    /// Whether viewing an archived game (not today)
    var isArchiveMode: Bool = false

    /// Whether the game is in read-only mode (completed archive game)
    var isReadOnly: Bool = false

    // MARK: - Animation Properties

    /// Whether a reveal animation is currently in progress
    var isRevealing: Bool = false

    /// Index of the row currently being revealed (-1 if none)
    var revealingRow: Int = -1

    /// Delay between each tile flip in the reveal animation (seconds)
    private let revealDelay: Double = 0.15

    // MARK: - Leaderboard Properties

    /// Start time of the current game session (for tracking duration)
    private var gameStartTime: Date?

    /// Total time taken for the game (in seconds)
    var gameDurationSeconds: Int = 0

    /// Username assigned by the server after score submission
    var assignedUsername: String?

    /// Whether the score has been submitted for this game
    var scoreSubmitted: Bool = false

    // MARK: - Word Lists

    /// Combined set of valid words (answers + valid guesses)
    private let validWords: Set<String>

    /// List of possible answer words
    private let answerWords: [String]

    // MARK: - Initialization

    /// Creates a new GameViewModel and loads today's game
    init() {
        // Initialize word lists
        self.validWords = Set(WordList.validGuesses + WordList.answers)
        self.answerWords = WordList.answers

        // Initialize game for today
        loadGameForDate(DateWordGenerator.today)
    }

    // MARK: - Daily Mode Methods

    /// Loads the game for a specific date
    ///
    /// This method:
    /// 1. Sets the target word deterministically based on date
    /// 2. Resets the grid to empty state
    /// 3. Restores any saved progress for this date
    /// 4. Sets read-only mode if game is completed
    ///
    /// - Parameter date: The date to load the game for
    func loadGameForDate(_ date: Date) {
        currentDate = date
        isArchiveMode = !Calendar.current.isDateInToday(date)

        // Get deterministic word for this date
        targetWord = DateWordGenerator.wordForDate(date, from: answerWords).uppercased()

        // Reset grid to empty state
        grid = (0..<maxGuesses).map { _ in
            (0..<wordLength).map { _ in LetterTile() }
        }

        // Reset state
        currentRow = 0
        currentTile = 0
        gameState = .playing
        keyboardStates = [:]
        showInvalidWordAlert = false
        isRevealing = false
        revealingRow = -1

        // Load saved state if exists
        if let savedState = GameStorage.shared.loadGameState(for: date) {
            restoreFromSavedState(savedState)
        }

        // Set read-only if archive mode and completed
        isReadOnly = isArchiveMode && gameState != .playing

        // Start timer for new games (leaderboard integration)
        if gameState == .playing && !isArchiveMode {
            gameStartTime = Date()
            scoreSubmitted = false
            assignedUsername = nil
        }
    }

    /// Loads today's game (convenience method)
    func loadTodaysGame() {
        loadGameForDate(DateWordGenerator.today)
    }

    /// Restores game state from a saved StoredGameState
    /// - Parameter state: The saved state to restore
    private func restoreFromSavedState(_ state: StoredGameState) {
        // Restore each saved guess
        for (rowIndex, guess) in state.guesses.enumerated() {
            let guessUpper = guess.uppercased()
            for (colIndex, char) in guessUpper.enumerated() {
                grid[rowIndex][colIndex].letter = char
            }
            // Re-evaluate to set colors (without animation)
            evaluateRestoredGuess(guessUpper, row: rowIndex)
        }

        currentRow = state.guesses.count
        currentTile = 0

        // Restore game state from string
        switch state.gameState {
        case "won": gameState = .won
        case "lost": gameState = .lost
        default: gameState = .playing
        }
    }

    /// Evaluates a restored guess and sets tile/keyboard states
    /// Used when loading saved games (no animation)
    /// - Parameters:
    ///   - guess: The guess word to evaluate
    ///   - row: The row index to update
    private func evaluateRestoredGuess(_ guess: String, row: Int) {
        let guessArray = Array(guess)
        let targetArray = Array(targetWord)

        // Count occurrences of each letter in target word
        var targetLetterCounts: [Character: Int] = [:]
        for char in targetArray {
            targetLetterCounts[char, default: 0] += 1
        }

        var states: [LetterState] = Array(repeating: .notInWord, count: wordLength)

        // First pass: mark correct positions (exact matches)
        for i in 0..<wordLength {
            if guessArray[i] == targetArray[i] {
                states[i] = .correct
                targetLetterCounts[guessArray[i], default: 0] -= 1
            }
        }

        // Second pass: mark wrong positions (letter exists but wrong spot)
        for i in 0..<wordLength {
            if states[i] != .correct {
                let letter = guessArray[i]
                if targetLetterCounts[letter, default: 0] > 0 {
                    states[i] = .wrongPosition
                    targetLetterCounts[letter, default: 0] -= 1
                }
            }
        }

        // Apply states without animation
        for i in 0..<wordLength {
            grid[row][i].state = states[i]
            updateKeyboardState(for: guessArray[i], with: states[i])
        }
    }

    /// Persists the current game state to storage
    private func saveCurrentState() {
        let guesses = (0..<currentRow).map { row in
            String(grid[row].compactMap { $0.letter })
        }
        GameStorage.shared.saveGameState(for: currentDate, guesses: guesses, gameState: gameState)
    }

    /// Resets the game for the current date (clears progress)
    func resetGame() {
        loadGameForDate(currentDate)
    }

    // MARK: - Input Handling

    /// Adds a letter to the current position
    /// - Parameter letter: The letter to add (uppercase)
    func addLetter(_ letter: Character) {
        guard gameState == .playing else { return }
        guard currentTile < wordLength else { return }

        grid[currentRow][currentTile].letter = letter
        grid[currentRow][currentTile].state = .filled
        currentTile += 1
    }

    /// Deletes the last entered letter
    func deleteLetter() {
        guard gameState == .playing else { return }
        guard currentTile > 0 else { return }

        currentTile -= 1
        grid[currentRow][currentTile].letter = nil
        grid[currentRow][currentTile].state = .empty
    }

    /// Submits the current guess for evaluation
    ///
    /// Validation:
    /// - Game must be in playing state
    /// - Not in read-only mode
    /// - Row must be complete (5 letters)
    /// - No reveal animation in progress
    /// - Word must be in valid word list
    func submitGuess() {
        guard gameState == .playing else { return }
        guard !isReadOnly else { return }
        guard currentTile == wordLength else { return }
        guard !isRevealing else { return }

        // Get the current guess
        let guess = String(grid[currentRow].compactMap { $0.letter })

        // Validate word is in dictionary
        guard validWords.contains(guess.lowercased()) else {
            showInvalidWordAlert = true
            return
        }

        // Start animated reveal
        isRevealing = true
        revealingRow = currentRow
        evaluateGuessWithAnimation(guess)
    }

    // MARK: - Guess Evaluation

    /// Evaluates a guess and triggers tile flip animations
    /// - Parameter guess: The guess word to evaluate
    private func evaluateGuessWithAnimation(_ guess: String) {
        let guessArray = Array(guess)
        let targetArray = Array(targetWord)

        // Count occurrences of each letter in target word
        var targetLetterCounts: [Character: Int] = [:]
        for char in targetArray {
            targetLetterCounts[char, default: 0] += 1
        }

        var states: [LetterState] = Array(repeating: .notInWord, count: wordLength)

        // First pass: mark correct positions
        for i in 0..<wordLength {
            if guessArray[i] == targetArray[i] {
                states[i] = .correct
                targetLetterCounts[guessArray[i], default: 0] -= 1
            }
        }

        // Second pass: mark wrong positions
        for i in 0..<wordLength {
            if states[i] != .correct {
                let letter = guessArray[i]
                if targetLetterCounts[letter, default: 0] > 0 {
                    states[i] = .wrongPosition
                    targetLetterCounts[letter, default: 0] -= 1
                }
            }
        }

        // Animate each tile with staggered delay
        for i in 0..<wordLength {
            let delay = Double(i) * revealDelay
            grid[currentRow][i].revealDelay = delay
            grid[currentRow][i].isRevealing = true

            // Update state after delay (midpoint of flip)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                self.grid[self.revealingRow][i].state = states[i]
                self.updateKeyboardState(for: guessArray[i], with: states[i])
            }
        }

        // After all tiles revealed, check game state
        let totalDelay = Double(wordLength) * revealDelay + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) { [weak self] in
            guard let self = self else { return }
            self.finishGuess(guess)
        }
    }

    /// Completes the guess after animation finishes
    /// - Parameter guess: The guess that was just revealed
    private func finishGuess(_ guess: String) {
        // Reset revealing state for all tiles in row
        for i in 0..<wordLength {
            grid[revealingRow][i].isRevealing = false
        }

        // Check win condition
        if guess == targetWord {
            gameState = .won
            saveCurrentState()
            submitScoreToLeaderboard()  // Submit score to leaderboard API
            isRevealing = false
            revealingRow = -1
            return
        }

        // Move to next row
        currentRow += 1
        currentTile = 0

        // Check lose condition
        if currentRow >= maxGuesses {
            gameState = .lost
        }

        // Save progress
        saveCurrentState()
        isRevealing = false
        revealingRow = -1
    }

    // MARK: - Leaderboard Integration

    /// Submits the completed game score to the leaderboard.
    ///
    /// Called automatically when a game is won.
    /// Only submits if playing today's game (not archive mode).
    ///
    /// - Note: This method handles errors gracefully and does not
    ///   block the user from continuing to use the app.
    func submitScoreToLeaderboard() {
        // Only submit for today's game
        guard !isArchiveMode else { return }

        // Only submit winning games
        guard gameState == .won else { return }

        // Don't submit twice
        guard !scoreSubmitted else { return }

        // Calculate time if we have a start time
        guard let startTime = gameStartTime else { return }

        let duration = Int(Date().timeIntervalSince(startTime))
        gameDurationSeconds = duration

        // Format date for API (YYYY-MM-DD)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let puzzleDate = dateFormatter.string(from: currentDate)

        // Submit score asynchronously
        Task {
            do {
                let response = try await LeaderboardService.shared.submitScore(
                    guesses: currentRow,
                    timeSeconds: duration,
                    puzzleDate: puzzleDate
                )

                // Store the assigned username
                await MainActor.run {
                    self.assignedUsername = response.score.username
                    self.scoreSubmitted = true
                }

                print("Score submitted! Username: \(response.score.username)")
            } catch {
                // Log error but don't disrupt user experience
                print("Failed to submit score: \(error)")
            }
        }
    }

    // MARK: - Keyboard State Management

    /// Updates the keyboard state for a letter based on evaluation result
    ///
    /// Priority: correct > wrongPosition > notInWord
    /// A letter that was found correct should not be downgraded
    ///
    /// - Parameters:
    ///   - letter: The letter to update
    ///   - state: The new state from evaluation
    private func updateKeyboardState(for letter: Character, with state: LetterState) {
        let currentKeyState = keyboardStates[letter]
        switch state {
        case .correct:
            // Correct always wins
            keyboardStates[letter] = .correct
        case .wrongPosition:
            // Wrong position only if not already correct
            if currentKeyState != .correct {
                keyboardStates[letter] = .wrongPosition
            }
        case .notInWord:
            // Not in word only if no prior state
            if currentKeyState == nil {
                keyboardStates[letter] = .notInWord
            }
        default:
            break
        }
    }

    /// Returns the keyboard state for a letter
    /// - Parameter letter: The letter to check
    /// - Returns: The current state, or .filled if unknown
    func getKeyState(for letter: Character) -> LetterState {
        return keyboardStates[letter] ?? .filled
    }

    // MARK: - Computed Properties

    /// Formatted string of the current date
    var formattedCurrentDate: String {
        DateWordGenerator.formatDate(currentDate)
    }

    /// Whether the current game is for today
    var isToday: Bool {
        Calendar.current.isDateInToday(currentDate)
    }

    /// Whether today's game has been completed
    var isTodayCompleted: Bool {
        GameStorage.shared.isDateCompleted(DateWordGenerator.today)
    }
}

// MARK: - Word List
/// Container for word lists used in the game.
///
/// Words are loaded:
/// - Answers: Embedded array of curated 5-letter words
/// - Valid guesses: Loaded from bundled text file
///
struct WordList {
    /// Curated list of answer words (education/campus themed)
    /// These are the possible daily words
    static let answers: [String] = [
        "aggie", "study", "brain", "learn", "smart", "teach", "think", "write",
        "class", "grade", "paper", "books", "essay", "notes", "group", "table",
        "chair", "board", "chalk", "drive", "water", "plant", "green", "earth",
        "sport", "games", "track", "field", "light", "sound", "music", "dance",
        "apple", "grape", "lemon", "peach", "berry", "melon", "mango", "olive",
        "bread", "toast", "pasta", "pizza", "salad", "steak", "bacon", "cream",
        "house", "dwell", "rooms", "doors", "floor", "walls", "brick",
        "world", "globe", "atlas", "north", "south", "ocean", "river", "beach",
        "happy", "smile", "laugh", "cheer", "peace", "calm", "quiet", "relax",
        "quick", "speed", "swift", "rapid", "blaze", "spark", "flame", "shine",
        "cloud", "storm", "rainy", "sunny", "foggy", "windy", "frost", "snowy",
        "money", "coins", "bills", "spend", "saved", "banks", "loans", "funds",
        "phone", "email", "texts", "calls", "video", "media", "press", "radio",
        "sleep", "dream", "awake", "arise", "early", "night", "dusk", "dawn",
        "young", "child", "adult", "elder", "human", "being", "folks",
        "heart", "blood", "bones", "brain", "lungs", "hands", "feet", "eyes",
        "paint", "brush", "color", "shade", "lines", "shape", "forms", "style",
        "stone", "metal", "glass", "steel", "woods", "cloth", "silk", "wool",
        "speak", "words", "voice", "talks", "chats", "story", "tales", "prose",
        "pride", "glory", "honor", "noble", "brave", "valor", "loyal", "trust"
    ]

    /// Load valid guesses from the bundled text file
    /// Returns an array of lowercase 5-letter words
    static let validGuesses: [String] = {
        guard let url = Bundle.main.url(forResource: "valid-wordle-words", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { $0.count == 5 }
    }()
}
