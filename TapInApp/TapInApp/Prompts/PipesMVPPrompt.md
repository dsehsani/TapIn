# Task: Implement "Pipes" Game (Flow Free Clone) for TapIn App

## Context
We are replacing the existing 'Crossword' module in the TapIn News + Games app with a new game called "Pipes". The goal is to create a functional MVP that maintains the TapIn design system (clean, modern, mobile-first).

## Core Game Logic (The "Flow" Mechanic)
1. **The Grid:** A 5x5 grid (for MVP) containing pairs of colored dots.
2. **The Connection:** Users must click/touch a dot and drag to create a path to its matching colored partner.
3. **The Constraints:**
   - Pipes cannot overlap or cross each other.
   - A pipe is "broken" if another color is drawn through it.
   - **Win Condition:** All pairs are connected AND every single cell in the grid is filled.
4. **Visual Feedback:** - Lines should be thick and color-coded.
   - Connected dots should glow or change state.

## Technical Requirements
- **Framework:** React with Tailwind CSS (standard for TapIn modules).
- **State Management:** - Track `gridState` (which cells contain which color path).
    - Track `activeColor` during a drag event.
- **Input:** Must support both MouseEvents and TouchEvents for mobile responsiveness.
- **Level Data:** Provide a hardcoded array of 3 levels of increasing difficulty for the MVP.

## UI/UX Integration
- **Header:** Display "Pipes" title, a "Reset" button, and a "Level 1/3" indicator.
- **Styling:** Use a dark-mode friendly palette. Ensure the grid is centered and scales to fit the container width.
- **Win State:** An overlay or modal showing "Puzzle Solved!" with a "Next Level" button.

## Replacement Instructions
- Please remove the `CrosswordGame` component and logic.
- Replace it with a new `PipesGame` component.
- Ensure the game exports correctly to be consumed by the main `App` layout.

## Level 1 Data (Example to get started):
Pairs: 
- Red: (0,0) and (4,0)
- Blue: (0,1) and (2,2)
- Green: (4,1) and (4,4)
- Yellow: (0,4) and (2,4)
- Orange: (1,1) and (3,3)
