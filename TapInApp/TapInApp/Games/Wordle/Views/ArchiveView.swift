//
//  ArchiveView.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/22/26.
//
//  MARK: - View Layer (MVVM)
//  This view displays a calendar-based archive of past Wordle games.
//  Users can browse months and select past dates to replay.
//
//  Architecture:
//  - Presented as a sheet from ContentView
//  - Queries GameStorage for completed games
//  - Uses DateWordGenerator for date utilities
//
//  Integration Notes:
//  - Presented via .sheet modifier in ContentView
//  - Calls onSelectDate callback when user picks a date
//  - Colors indicate win (green), loss (gold), or not played (border only)
//

import SwiftUI

// MARK: - Archive View
/// Calendar-based browser for past Wordle games.
///
/// Features:
/// - Month-by-month navigation
/// - Color-coded status for each day (won/lost/not played)
/// - Today highlighted with blue border
/// - Future dates disabled
/// - Legend explaining color codes
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showArchive) {
///     ArchiveView(
///         onSelectDate: { date in
///             viewModel.loadGameForDate(date)
///         },
///         onDismiss: { showArchive = false }
///     )
/// }
/// ```
///
struct ArchiveView: View {
    // MARK: - Callbacks

    /// Called when user selects a date to play
    /// Parent should load the game for this date
    let onSelectDate: (Date) -> Void

    /// Called when user dismisses the archive
    let onDismiss: () -> Void

    // MARK: - Environment
    @Environment(\.colorScheme) var colorScheme

    // MARK: - State

    /// Cached list of completed games with win/loss status
    @State private var completedGames: [(date: Date, won: Bool)] = []

    /// Currently displayed month
    @State private var selectedMonth: Date = DateWordGenerator.today

    /// Calendar instance for date calculations
    private let calendar = Calendar.current

    // MARK: - Computed Properties

    private var accentColor: Color {
        Color.adaptiveAccent(colorScheme)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month navigation (previous/next)
                monthNavigator
                    .padding(.vertical, 12)

                // Calendar grid with days
                calendarGrid
                    .padding(.horizontal, 16)

                Spacer()

                // Legend explaining colors
                legendView
                    .padding(.bottom, 20)
            }
            .background(Color.wordleBackground(colorScheme))
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
        .onAppear {
            loadCompletedGames()
        }
    }

    // MARK: - Month Navigator

    /// Navigation controls for switching between months
    private var monthNavigator: some View {
        HStack {
            // Previous month button
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            Spacer()

            // Current month/year display
            Text(monthYearString(for: selectedMonth))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(accentColor)

            Spacer()

            // Next month button (disabled if would go past today)
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(canGoToNextMonth ? accentColor : .gray.opacity(0.3))
            }
            .disabled(!canGoToNextMonth)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Calendar Grid

    /// Grid of days for the selected month
    private var calendarGrid: some View {
        let days = daysInMonth()
        let firstWeekday = firstWeekdayOfMonth()

        return VStack(spacing: 8) {
            // Weekday headers (S M T W T F S)
            HStack(spacing: 4) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Days grid (7 columns)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                // Empty cells for offset (days before 1st of month)
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear
                        .frame(height: 44)
                }

                // Day cells
                ForEach(days, id: \.self) { date in
                    DayCell(
                        date: date,
                        status: statusForDate(date),
                        isToday: calendar.isDateInToday(date),
                        isFuture: date > DateWordGenerator.today,
                        colorScheme: colorScheme,
                        onTap: {
                            if date <= DateWordGenerator.today {
                                onSelectDate(date)
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Legend

    /// Explains the color coding for day cells
    private var legendView: some View {
        HStack(spacing: 24) {
            legendItem(color: .wordleGreen, text: "Won")
            legendItem(color: .ucdGold, text: "Lost")
            legendItem(color: .tileBorder, text: "Not Played")
        }
    }

    /// Single legend item with color swatch and label
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 16, height: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Data Loading

    /// Loads completed games from storage
    private func loadCompletedGames() {
        completedGames = GameStorage.shared.getCompletedDatesWithStatus()
    }

    // MARK: - Date Helpers

    /// Formats month and year for display
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    /// Returns all days in the selected month
    private func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) else {
            return []
        }

        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
    }

    /// Returns the weekday index (0-6) of the first day of month
    private func firstWeekdayOfMonth() -> Int {
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) else {
            return 0
        }
        return calendar.component(.weekday, from: firstDay) - 1
    }

    /// Returns the display status for a given date
    private func statusForDate(_ date: Date) -> DayStatus {
        if let game = completedGames.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return game.won ? .won : .lost
        }
        if GameStorage.shared.hasPlayedDate(date) {
            return .inProgress
        }
        return .notPlayed
    }

    /// Whether navigation to next month is allowed
    private var canGoToNextMonth: Bool {
        guard let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else {
            return false
        }
        let nextMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonthDate))!
        return nextMonthStart <= DateWordGenerator.today
    }

    /// Navigate to previous month
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }

    /// Navigate to next month
    private func nextMonth() {
        if canGoToNextMonth, let newDate = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}

// MARK: - Day Status
/// Represents the status of a day in the archive calendar
enum DayStatus {
    /// Game was played and won
    case won
    /// Game was played and lost
    case lost
    /// Game was started but not completed
    case inProgress
    /// No game data exists for this date
    case notPlayed
}

// MARK: - Day Cell
/// Renders a single day in the archive calendar.
///
/// Visual states:
/// - Won: Green background
/// - Lost: Gold background
/// - In Progress: Gray background (50% opacity)
/// - Not Played: Border only
/// - Today: Additional blue border
/// - Future: Dimmed and disabled
///
struct DayCell: View {
    /// The date this cell represents
    let date: Date

    /// Win/loss/progress status for coloring
    let status: DayStatus

    /// Whether this is today's date
    let isToday: Bool

    /// Whether this date is in the future
    let isFuture: Bool

    /// Color scheme for dark mode support
    var colorScheme: ColorScheme = .light

    /// Called when the cell is tapped
    let onTap: () -> Void

    // MARK: - Computed Properties

    /// Day number string (1-31)
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    /// Background color based on status
    private var backgroundColor: Color {
        if isFuture { return Color.clear }
        switch status {
        case .won: return .wordleGreen
        case .lost: return .ucdGold
        case .inProgress: return .wordleGray.opacity(0.5)
        case .notPlayed: return Color.clear
        }
    }

    /// Text color based on status
    private var textColor: Color {
        if isFuture { return .gray.opacity(0.3) }
        switch status {
        case .won, .lost: return .white
        case .inProgress: return .white
        case .notPlayed: return colorScheme == .dark ? .white : .primary
        }
    }

    private var accentColor: Color {
        Color.adaptiveAccent(colorScheme)
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background fill
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)

                // Border for not-played dates
                if status == .notPlayed && !isFuture {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.wordleTileBorder(colorScheme), lineWidth: 1)
                }

                // Today indicator (accent color border)
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(accentColor, lineWidth: 2)
                }

                // Day number
                Text(dayNumber)
                    .font(.system(size: 16, weight: isToday ? .bold : .medium, design: .rounded))
                    .foregroundColor(textColor)
            }
            .frame(height: 44)
        }
        .disabled(isFuture)
    }
}

// MARK: - Preview
#Preview {
    ArchiveView(
        onSelectDate: { _ in },
        onDismiss: { }
    )
}
