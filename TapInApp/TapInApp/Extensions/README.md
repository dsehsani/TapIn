# Extensions

Swift extensions that add utility functions and design tokens.

---

## Files

| File | Description |
|------|-------------|
| `ColorExtensions.swift` | Extends `Color` with hex initializer, UC Davis brand colors, and adaptive color helpers for dark mode support. |
| `FontExtensions.swift` | Extends `Font` with predefined typography styles for consistent text styling across the app. |

---

## Color Palette

### Brand Colors
| Name | Hex | Usage |
|------|-----|-------|
| `ucdBlue` | `#022851` | Primary brand color, buttons, headers |
| `ucdGold` | `#FFBF00` | Accent color, badges, highlights |

### Background Colors
| Name | Hex | Usage |
|------|-----|-------|
| `backgroundLight` | `#f5f7f8` | Light mode background |
| `backgroundDark` | `#0f1923` | Dark mode background |

### Text Colors
| Name | Hex | Usage |
|------|-----|-------|
| `textPrimary` | `#0f172a` | Main text |
| `textSecondary` | `#94a3b8` | Subtitles, metadata |
| `textMuted` | `#64748b` | Disabled, hints |

---

## Adaptive Colors

```swift
// Automatically adapts to light/dark mode
Color.adaptiveBackground(colorScheme)
Color.adaptiveCardBackground(colorScheme)
Color.adaptiveText(colorScheme)
Color.adaptiveAccent(colorScheme)
```

---

## Typography Scale

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| `articleTitle` | 24pt | Bold | Featured headlines |
| `articleTitleSmall` | 16pt | Bold | Card titles |
| `sectionTitle` | 18pt | Bold | Section headers |
| `articleExcerpt` | 14pt | Regular | Body text |
| `categoryTag` | 10pt | Bold | Category labels |
| `timestamp` | 10pt | Regular | Date/time text |

---

## Hex Color Usage

```swift
// Initialize any color from hex
Color(hex: "#FF5733")
Color(hex: "#FF5733FF") // With alpha
```
