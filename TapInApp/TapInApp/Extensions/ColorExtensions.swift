//
//  ColorExtensions.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

extension Color {
    // MARK: - Hex Color Initializer (must be first)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // MARK: - Primary UC Davis Colors
    static let ucdBlue = Color(hex: "#022851")
    static let ucdGold = Color(hex: "#FFBF00")

    // MARK: - Background Colors
    static let backgroundLight = Color(hex: "#f5f7f8")
    static let backgroundDark = Color(hex: "#0f1923")

    // MARK: - UI Colors
    static let cardBackground = Color.white
    static let cardBackgroundDark = Color(hex: "#1C1C1E")
    static let textPrimary = Color(hex: "#0f172a")
    static let textSecondary = Color(hex: "#94a3b8")
    static let textMuted = Color(hex: "#64748b")
    static let borderLight = Color(hex: "#f1f5f9")
    static let borderDark = Color(hex: "#1e293b")

    // MARK: - Wordle Game Colors
    /// Correct position indicator (green)
    static let wordleGreen = Color(red: 0.42, green: 0.67, blue: 0.46)
    /// Not in word indicator (gray)
    static let wordleGray = Color(red: 0.47, green: 0.49, blue: 0.51)
    /// Empty tile border (light mode)
    static let tileBorder = Color(red: 0.83, green: 0.84, blue: 0.85)
    /// Empty tile border (dark mode)
    static let tileBorderDark = Color(red: 0.35, green: 0.38, blue: 0.42)
    /// Filled tile border (light mode)
    static let tileBorderFilled = Color(red: 0.53, green: 0.54, blue: 0.55)
    /// Filled tile border (dark mode)
    static let tileBorderFilledDark = Color(red: 0.55, green: 0.58, blue: 0.62)
    /// Wordle app background (light mode)
    static let appBackground = Color(red: 0.98, green: 0.98, blue: 0.98)
    /// Keyboard key background (light mode)
    static let keyBackground = Color(red: 0.82, green: 0.84, blue: 0.86)
    /// Keyboard key background (dark mode)
    static let keyBackgroundDark = Color(red: 0.32, green: 0.35, blue: 0.40)
    /// Keyboard key text color
    static let keyText = Color.black

    // MARK: - Wordle Adaptive Colors
    static func wordleBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundDark : appBackground
    }

    static func wordleHeaderBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#1a1a2e") : .white
    }

    static func wordleTileBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? tileBorderDark : tileBorder
    }

    static func wordleTileBorderFilled(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? tileBorderFilledDark : tileBorderFilled
    }

    static func wordleKeyBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? keyBackgroundDark : keyBackground
    }

    static func wordleKeyText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    static func wordleTileText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    // MARK: - Adaptive Colors
    static func adaptiveBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundDark : backgroundLight
    }

    static func adaptiveCardBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardBackgroundDark : cardBackground
    }

    static func adaptiveText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : textPrimary
    }

    static func adaptiveAccent(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? ucdGold : ucdBlue
    }

    // MARK: - Sudoku Game Colors

    /// Sudoku grid thick border (box dividers)
    static func sudokuThickBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#555555") : Color(hex: "#333333")
    }

    /// Sudoku grid thin border (cell dividers)
    static func sudokuThinBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#444444") : Color(hex: "#cccccc")
    }

    /// Sudoku background
    static func sudokuBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundDark : Color(hex: "#f8f9fa")
    }

    /// Sudoku header background
    static func sudokuHeaderBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#1a1a2e") : .white
    }

    /// Sudoku numpad key background
    static func sudokuKeyBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#2a2a3e") : Color(hex: "#f0f0f0")
    }
}
