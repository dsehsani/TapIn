//
//  PipesArchiveView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Calendar-based archive for past Pipes daily-five games.
//  Adapted from Wordle's ArchiveView.swift.
//

import SwiftUI

struct PipesArchiveView: View {

    /// Called when user selects a date to play
    let onSelectDate: (Date) -> Void

    /// Called when user dismisses the archive
    let onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme

    @State private var playedDates: [String: PipesDayStatus] = [:]
    @State private var selectedMonth: Date = Date()

    private let calendar = Calendar.current

    private var accentColor: Color {
        Color.adaptiveAccent(colorScheme)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthNavigator
                    .padding(.vertical, 12)

                calendarGrid
                    .padding(.horizontal, 16)

                Spacer()

                legendView
                    .padding(.bottom, 20)
            }
            .background(Color.adaptiveBackground(colorScheme))
            .navigationTitle("Pipes Archive")
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
            loadPlayedDates()
        }
        .onChange(of: selectedMonth) {
            loadPlayedDates()
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(canGoToPreviousMonth ? accentColor : .gray.opacity(0.3))
            }
            .disabled(!canGoToPreviousMonth)

            Spacer()

            Text(monthYearString(for: selectedMonth))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(accentColor)

            Spacer()

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

    private var calendarGrid: some View {
        let days = daysInMonth()
        let firstWeekday = firstWeekdayOfMonth()

        return VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear
                        .frame(height: 44)
                }

                ForEach(days, id: \.self) { date in
                    PipesDayCell(
                        date: date,
                        status: statusForDate(date),
                        isToday: calendar.isDateInToday(date),
                        isFuture: date > Date(),
                        isBeforeStart: date < PipesPuzzleProvider.startDate,
                        colorScheme: colorScheme,
                        onTap: {
                            if date <= Date() && date >= PipesPuzzleProvider.startDate {
                                onSelectDate(date)
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: 24) {
            legendItem(color: .green, text: "All 5")
            legendItem(color: Color.ucdGold, text: "Partial")
            legendItem(color: .clear, borderColor: Color.secondary.opacity(0.3), text: "Not Played")
        }
    }

    private func legendItem(color: Color, borderColor: Color? = nil, text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(borderColor ?? .clear, lineWidth: borderColor != nil ? 1 : 0)
                )
                .frame(width: 16, height: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Data Loading

    private func loadPlayedDates() {
        playedDates = PipesGameStorage.shared.getAllPlayedDates()
    }

    // MARK: - Date Helpers

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) else {
            return []
        }

        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
    }

    private func firstWeekdayOfMonth() -> Int {
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) else {
            return 0
        }
        return calendar.component(.weekday, from: firstDay) - 1
    }

    private func statusForDate(_ date: Date) -> PipesDayStatus {
        let key = PipesPuzzleProvider.shared.dateKey(for: date)
        return playedDates[key] ?? .notPlayed
    }

    private var canGoToNextMonth: Bool {
        guard let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else {
            return false
        }
        let nextMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonthDate))!
        return nextMonthStart <= Date()
    }

    private var canGoToPreviousMonth: Bool {
        guard let prevMonthDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else {
            return false
        }
        // Don't go before the start date's month
        let startComponents = calendar.dateComponents([.year, .month], from: PipesPuzzleProvider.startDate)
        let prevComponents = calendar.dateComponents([.year, .month], from: prevMonthDate)
        if let startYear = startComponents.year, let startMonth = startComponents.month,
           let prevYear = prevComponents.year, let prevMonth = prevComponents.month {
            return prevYear > startYear || (prevYear == startYear && prevMonth >= startMonth)
        }
        return true
    }

    private func previousMonth() {
        if canGoToPreviousMonth, let newDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }

    private func nextMonth() {
        if canGoToNextMonth, let newDate = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}

// MARK: - Pipes Day Cell

struct PipesDayCell: View {
    let date: Date
    let status: PipesDayStatus
    let isToday: Bool
    let isFuture: Bool
    let isBeforeStart: Bool
    var colorScheme: ColorScheme = .light
    let onTap: () -> Void

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var backgroundColor: Color {
        if isFuture || isBeforeStart { return Color.clear }
        switch status {
        case .allComplete: return .green
        case .partial: return Color.ucdGold
        case .notPlayed: return Color.clear
        }
    }

    private var textColor: Color {
        if isFuture || isBeforeStart { return .gray.opacity(0.3) }
        switch status {
        case .allComplete, .partial: return .white
        case .notPlayed: return colorScheme == .dark ? .white : .primary
        }
    }

    private var accentColor: Color {
        Color.adaptiveAccent(colorScheme)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)

                if status == .notPlayed && !isFuture && !isBeforeStart {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                }

                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(accentColor, lineWidth: 2)
                }

                Text(dayNumber)
                    .font(.system(size: 16, weight: isToday ? .bold : .medium, design: .rounded))
                    .foregroundColor(textColor)
            }
            .frame(height: 44)
        }
        .disabled(isFuture || isBeforeStart)
    }
}
