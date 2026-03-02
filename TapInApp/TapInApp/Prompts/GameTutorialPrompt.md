# Task: Add First-Time Onboarding Overlays for iOS Mini-Games

**Context:** I have an iOS news app that features three sub-games: Wordle, Pipes, and Echo. The core functionality and gameplay logic for all three games currently work perfectly. 

**Objective:** I need to implement a first-time user onboarding tutorial overlay for each of these three games. 

**Requirements:**
1. **First-Time Check:** The app needs to track if it's a new account or the user's first time opening that specific game (e.g., using `@AppStorage` or `UserDefaults`).
2. **Tutorial Overlay:** If it is their first time playing, a clean, visually appealing overlay should appear explaining the basic rules of that specific game.
3. **Start Trigger:** The overlay must include a clear "Start" or "Play" button. 
4. **Timer Integration:** Tapping the "Start" button should dismiss the tutorial overlay and *immediately begin the game's timer*. The timer should strictly remain paused while the tutorial is visible.

**Specific Games to Include:**
Please provide the UI code and state logic integration for the following three games:
* **Wordle:** Standard Wordle rules (guess the 5-letter word in 6 tries, color-coded feedback).
* **Pipes:** Connect the pieces to create a continuous pipeline before time runs out.
* **Echo:** Memorize and repeat the growing sequence of patterns/sounds.

**Output Request:**
Please write the iOS code (preferably SwiftUI) showing:
1. The reusable or game-specific tutorial overlay views.
2. The state management for checking if it's a first-time user.
3. How to hook up the "Start" button so it seamlessly triggers the existing timer logic. 
Keep the design clean, modern, and suitable for a news app environment.
