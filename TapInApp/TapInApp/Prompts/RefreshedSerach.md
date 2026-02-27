# Prompt: Refactor Bottom Navigation & Search to Apple News Style

**Role:** You are an expert iOS Developer specializing in SwiftUI, advanced UI/UX animations, and custom navigation paradigms.

**Objective:** Redesign our app's bottom navigation bar and search experience to closely mimic the Apple News app, specifically implementing a floating "liquid glass" navigation pill with a detached search button, and a dynamic category-based Search View.

**Context & Constraints:**
- This new navigation style should **only** be active when our `liquid glass` visual mode/toggle is enabled. (Please structure the code to gracefully fallback to our standard navigation if it's disabled).
- Our core navigation tabs are: **News, Campus, Games, Saved**.

**Requirement 1: The Apple News Style Bottom Nav**
- Create a custom bottom navigation layout that sits above the content.
- **Main Nav Pill:** A floating, horizontal rounded pill containing the 4 tabs (`News`, `Campus`, `Games`, `Saved`). It must use our "liquid glass" material/blur effect.
- **Search Button:** A separate, detached circular button positioned to the right of the main nav pill. It should also use the liquid glass effect.

**Requirement 2: Dynamic Search Bar State**
- When the user taps the detached Search circle, it should seamlessly transition to or open a new `SearchView`.
- **Contextual Search Bar:** The search input field at the bottom of the `SearchView` must be context-aware. It needs to display a small circular profile/icon of the tab the user was just on. For example, if I tap search while on the "News" tab, the search bar's leading icon should be the "News" icon (indicating I am searching within News). 

**Requirement 3: The Search View UI**
- Build a custom `SearchView` that looks like the Apple News search screen.
- **Category Grid:** The main content of this view should be a `LazyVGrid` (2 columns) of vibrant, colorful, rounded-rectangular category widgets (e.g., Sports, Politics, Business, Entertainment). 
- Each category card should have a solid background color or soft gradient, a title, and an icon or image positioned dynamically (like the trophies or microphones in Apple News).
- Provide a mock data array and model for these search categories to populate the grid so I can see it working immediately.

**Tasks Required:**
1. Provide the SwiftUI code for the `LiquidGlassTabBar` component (handling the pill + detached search circle).
2. Provide the SwiftUI code for the context-aware `SearchView` and the `CategoryGrid`.
3. Show how to integrate this into the main `ContentView` or `AppRouter`, ensuring the `if isLiquidGlassEnabled` logic routes between the old nav and this new custom layout.
4. Ensure smooth transitions and that the keyboard interacts properly with the custom search bar.


