# UI Redesign Instruction — Apple News Style Bottom Toolbar

I want you to redesign my app’s bottom toolbar to feel very similar to the Apple News app layout (reference: Apple News iOS bottom navigation format).

This is NOT a full redesign of my app.  
This is specifically about the **bottom navigation bar and search placement**.

---

## 🎯 Overall Goal

Create a modern, minimal, Apple News–inspired bottom toolbar with:

- Clean spacing
- Rounded floating appearance
- Subtle translucency (if using iOS native blur)
- Clear active state
- Bottom-right circular search button like Apple News

The style should feel:
- Native iOS
- Premium
- Clean
- Balanced
- Not cluttered

---

## 📱 Toolbar Layout Requirements

### 1. Bottom Navigation Bar Structure

- Use a floating-style bottom bar (not a full-width hard edge tab bar).
- Slight rounded corners (like Apple News).
- Centered horizontally with padding on left and right.
- Slight shadow for elevation.
- Background: translucent material (iOS system material if available).

---

### 2. Navigation Items

Replace Apple News labels with MY labels:

These should:
- Be evenly spaced
- Use icon + label
- Have a subtle inactive state (muted color)
- Have a bold or highlighted active state
- Animate smoothly when switching

Active state should:
- Slightly increase icon weight
- Use my brand accent color
- Slight background pill highlight (subtle)

---

### 3. Bottom Right Search Button

This is important.

I want:
- A circular floating search button
- Positioned slightly overlapping the bottom right of the toolbar
- Similar placement to Apple News search
- Slightly elevated with shadow
- Uses magnifying glass icon
- Tappable and visually distinct from tabs

This should feel like:
- A primary utility action
- Not just another tab
- Slight hover elevation effect (if applicable)

---

## 🎨 Styling Notes

- Use Apple system font (SF Pro if available).
- Icons should be clean line style (SF Symbols style).
- Spacing must feel breathable.
- Avoid thick borders.
- Keep contrast high in dark mode.
- Support light and dark mode.

---

## ⚙️ Implementation Notes

If this is SwiftUI:
- Prefer TabView customization OR a custom bottom bar.
- Use .background(.ultraThinMaterial) if possible.
- Use safe area insets correctly.
- Respect iPhone Pro Max sizes.
- Avoid clipping content.

If this is React Native:
- Use absolute positioning for floating search button.
- Avoid hardcoded pixel positioning.
- Make layout responsive.

---

## ❗ Important Constraints

- Do NOT copy Apple exactly.
- Maintain my brand identity.
- Keep my color system intact.
- Do not introduce new sections.
- Do not redesign the entire app.
- Only adjust bottom navigation and search placement.

---

## Output Format

Return:
1. Clean layout structure
2. Updated component code
3. Styling adjustments
4. Clear explanation of design choices

Make the implementation production-ready.
Keep it clean and elegant.
Do not overcomplicate it.
