I am building **TapIn**, a native iOS companion app for UC Davis students (Gen Z, 18–24). The app is built in **SwiftUI (iOS 17+)** with a Python/Flask backend.

**The Goal:** I want to replace standard, skippable onboarding slides with a **"Gold Standard" Progressive Disclosure** system. I need a native SwiftUI implementation of contextual tooltips and "hotspots" that guide the user without blocking them, plus "Smart Empty States" that drive action.

**App Context & Core Loop:**
* **Value Prop:** The single daily touchpoint for campus life.
* **The "North Star" Flow:** Open App → Read "What's Happening Today" (AI Summary) → Play "DailyFive" (Wordle-style game).
* **Design Aesthetic:** "Instagram meets Campus Bulletin Board." UC Davis Blue (#022851) & Gold (#FFBF00). Clean, visual, slightly witty/casual tone.

**Current Issues to Fix:**
1.  **The "Saved" Tab is a dead end:** Currently, if a user has no saved articles, it just says "No saved articles." It needs to drive them back to the News tab.
2.  **Feature Blindness:** Users might miss that the "What's Happening" card is a clickable summary or that the Games tab exists.

**Requirements for the Solution:**

### 1. The Architecture (Native SwiftUI)
Since I am not using third-party libraries like `SwiftUI-Introspect`, please design a lightweight, custom **OnboardingManager** using standard SwiftUI (e.g., `ViewModifier`, `ZStack` overlays, or `matchedGeometryEffect`).
* It must handle state persistence (e.g., `AppStorage`) so a tip is only shown once.
* It must support a "Pulsing Hotspot" visual style.

### 2. The "Happy Path" Walkthrough (Script & Logic)
Design the logic for this specific flow:
* **Step 1 (First App Open - News Tab):** A subtle pulse on the "What's Happening Today" card.
    * *Tooltip Copy:* "Get the tea ☕️. Your daily AI breakdown of campus news."
* **Step 2 (After reading news - Games Tab):** If the user navigates to Games, pulse the "DailyFive" card.
    * *Tooltip Copy:* "Brain awake yet? 🧠 Keep your streak alive."
* **Step 3 (Profile Tab):** Pulse the "Year/Major" edit button if it's default.
    * *Tooltip Copy:* "Don't be a stranger. Set your year & major."

### 3. Smart Empty States (The Fix)
Rewrite the `SavedView` UI code to include **Actionable Empty States**.
* Instead of just text, include a highly visible button that deep-links or switches tabs to the content source.
* *Copy for Saved Articles:* "Your bookmarks is looking dry. Go find some headlines." -> [Button: "Explore News"]
* *Copy for Saved Events:* "No plans this weekend? Let's fix that." -> [Button: "Find Events"]

**Deliverables:**
1.  **Swift Code:** A reusable `OnboardingTipView` and `ViewModifier` I can attach to any view.
2.  **Swift Code:** The revamped `SavedView` with the actionable empty state logic.
3.  **UI Polish:** Ensure the colors match UC Davis branding and the tooltips look modern (frosted glass or bold colors), not like generic system alerts.
