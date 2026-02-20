//
//  LeaderboardView.swift
//  TapInApp
//
//  MARK: - Leaderboard View
//  Main view for displaying game leaderboards.
//  Supports game type filtering, date selection, and score listing.
//

import SwiftUI

// MARK: - Leaderboard View

struct LeaderboardView: View {
    @State private var viewModel: LeaderboardViewModel
    let onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme

    init(initialGameType: GameType? = nil, onDismiss: @escaping () -> Void) {
        self._viewModel = State(initialValue: LeaderboardViewModel(initialGameType: initialGameType))
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // Background
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation Header
                navigationHeader

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header with game selector, date, stats
                        LeaderboardHeaderView(
                            viewModel: viewModel,
                            colorScheme: colorScheme
                        )

                        // Scores List
                        scoresSection
                    }
                    .padding(.vertical, 16)
                }
                .refreshable {
                    viewModel.refresh()
                }
            }
        }
        .sheet(isPresented: $viewModel.showingDatePicker) {
            DatePickerSheet(
                selectedDate: viewModel.selectedDate,
                onSelect: { date in
                    viewModel.selectDate(date)
                },
                colorScheme: colorScheme
            )
            .presentationDetents([.height(400)])
        }
    }

    // MARK: - Navigation Header

    private var navigationHeader: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                    .frame(width: 36, height: 36)
                    .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Leaderboard")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)

                Text(viewModel.selectedGameDisplayName)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
    }

    // MARK: - Scores Section

    private var scoresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Rankings")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

                Spacer()

                if viewModel.hasScores {
                    Text("\(viewModel.scoreCount) player\(viewModel.scoreCount == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, 16)

            // Scores list or empty state
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasScores {
                scoresList
            } else {
                emptyStateView
            }
        }
    }

    // MARK: - Scores List

    private var scoresList: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(viewModel.scores.enumerated()), id: \.element.id) { index, score in
                LeaderboardRowView(
                    score: score,
                    rank: index + 1,
                    isCurrentUser: viewModel.isUserScore(score),
                    colorScheme: colorScheme
                )
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundColor(Color.ucdGold.opacity(0.5))

            Text("No scores yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

            Text("Play \(viewModel.selectedGameDisplayName) to see your score here!")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            if !viewModel.isToday {
                Button(action: viewModel.goToToday) {
                    Text("View Today's Scores")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.ucdBlue)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 16)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading scores...")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    let selectedDate: Date
    let onSelect: (Date) -> Void
    let colorScheme: ColorScheme

    @State private var pickerDate: Date
    @Environment(\.dismiss) var dismiss

    init(selectedDate: Date, onSelect: @escaping (Date) -> Void, colorScheme: ColorScheme) {
        self.selectedDate = selectedDate
        self.onSelect = onSelect
        self.colorScheme = colorScheme
        self._pickerDate = State(initialValue: selectedDate)
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $pickerDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .accentColor(Color.ucdBlue)
                .padding()

                Spacer()
            }
            .background(Color.adaptiveBackground(colorScheme))
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSelect(pickerDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LeaderboardView(onDismiss: {})
}
