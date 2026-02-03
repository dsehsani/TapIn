//
//  HeaderView.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/20/26.
//
//  MARK: - View Layer (MVVM)
//  This view renders the app header with title and navigation controls.
//  It provides access to the archive and return-to-today functionality.
//
//  Integration Notes:
//  - Used by ContentView as the top navigation bar
//  - Displays different controls based on isArchiveMode
//  - Calendar button opens the archive sheet
//  - Home button returns to today's game (archive mode only)
//

import SwiftUI

// MARK: - Header View
/// Renders the app header with title and navigation controls.
///
/// Layout:
/// - Left: Calendar button (opens archive)
/// - Center: App title "WordleType"
/// - Right: Home button (visible in archive mode)
///
/// Archive mode behavior:
/// - Shows the current date being played
/// - Home button appears to return to today's game
///
struct HeaderView: View {
    // MARK: - Properties

    /// Whether currently viewing an archived game
    /// Controls visibility of home button and date display
    let isArchiveMode: Bool

    /// Formatted date string for archive games
    /// Example: "Jan 22, 2026"
    let currentDate: String

    /// Called when the calendar button is tapped
    /// Should present the archive sheet
    let onArchiveTap: () -> Void

    /// Called when the home button is tapped (archive mode)
    /// Should load today's game
    let onBackToToday: () -> Void

    /// Called when back button is tapped to return to games list
    var onBack: (() -> Void)? = nil

    /// Color scheme for dark mode support
    var colorScheme: ColorScheme = .light

    // MARK: - Computed Properties

    private var accentColor: Color {
        Color.adaptiveAccent(colorScheme)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Main header bar
            HStack {
                // Back button (left side)
                if let onBack = onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                    .padding(.trailing, 8)
                }

                // Archive button
                Button(action: onArchiveTap) {
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(accentColor)
                }

                Spacer()

                // App title (center)
                Text("WordleType")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)

                Spacer()

                // Home button (right side) - only visible in archive mode
                if isArchiveMode {
                    Button(action: onBackToToday) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(accentColor)
                    }
                } else {
                    // Invisible placeholder for layout symmetry
                    Image(systemName: "house.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Date indicator (archive mode only)
            if isArchiveMode {
                Text(currentDate)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .background(Color.wordleHeaderBackground(colorScheme))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 2, y: 2)
    }
}

// MARK: - Preview
#Preview {
    VStack {
        HeaderView(
            isArchiveMode: false,
            currentDate: "Jan 30, 2026",
            onArchiveTap: { },
            onBackToToday: { }
        )

        HeaderView(
            isArchiveMode: true,
            currentDate: "Jan 22, 2026",
            onArchiveTap: { },
            onBackToToday: { }
        )
    }
}
