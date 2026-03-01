//
//  LeaderboardView.swift
//  TapInApp
//
//  Created by Claude on 2/21/26.
//

import SwiftUI

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = LeaderboardViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Date Navigator
                    dateNavigator
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    Divider()

                    // Content
                    ScrollView {
                        if viewModel.isLoading {
                            loadingView
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                        } else if viewModel.hasEntries {
                            rankingsList
                        } else {
                            emptyView
                        }
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("DailyFive Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingDatePicker) {
                DatePickerSheet(
                    selectedDate: viewModel.selectedDate,
                    onSelect: { viewModel.selectDate($0) },
                    onCancel: { viewModel.showingDatePicker = false }
                )
                .presentationDetents([.medium])
            }
            .task {
                viewModel.selectedDate = Date()
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Date Navigator

    private var dateNavigator: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.previousDay()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            }

            Button {
                viewModel.showingDatePicker = true
            } label: {
                Text(viewModel.formattedDate)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            }

            Button {
                viewModel.nextDay()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.canGoForward ? (colorScheme == .dark ? .white : .primary) : .gray.opacity(0.4))
            }
            .disabled(!viewModel.canGoForward)

            Spacer()

            if viewModel.isToday {
                Text("Today")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.ucdGold))
            }
        }
    }

    // MARK: - Rankings List

    private var rankingsList: some View {
        VStack(spacing: 16) {
            // Podium for top 3
            let top3 = viewModel.entries.filter { $0.rank <= 3 }
            if !top3.isEmpty {
                podiumView(top3: top3)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            // Remaining entries (4th+)
            let remaining = viewModel.entries.filter { $0.rank > 3 }
            if !remaining.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(remaining) { entry in
                        LeaderboardRowView(
                            entry: entry,
                            isCurrentUser: viewModel.isCurrentUserEntry(entry),
                            colorScheme: colorScheme
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Podium

    private func podiumView(top3: [LeaderboardEntryResponse]) -> some View {
        let first = top3.first(where: { $0.rank == 1 })
        let second = top3.first(where: { $0.rank == 2 })
        let third = top3.first(where: { $0.rank == 3 })

        return HStack(alignment: .bottom, spacing: 10) {
            // 2nd place
            if let entry = second {
                podiumSlot(entry: entry, height: 64, medalEmoji: "🥈")
            } else {
                Spacer().frame(maxWidth: .infinity)
            }

            // 1st place
            if let entry = first {
                podiumSlot(entry: entry, height: 88, medalEmoji: "🥇")
            } else {
                Spacer().frame(maxWidth: .infinity)
            }

            // 3rd place
            if let entry = third {
                podiumSlot(entry: entry, height: 48, medalEmoji: "🥉")
            } else {
                Spacer().frame(maxWidth: .infinity)
            }
        }
    }

    private func podiumSlot(entry: LeaderboardEntryResponse, height: CGFloat, medalEmoji: String) -> some View {
        let isMe = viewModel.isCurrentUserEntry(entry)
        let podiumColor: Color = {
            switch entry.rank {
            case 1: return Color.ucdGold
            case 2: return Color(hex: "#94a3b8")
            case 3: return Color(hex: "#b45309")
            default: return Color.gray
            }
        }()

        return VStack(spacing: 0) {
            Text(medalEmoji)
                .font(.system(size: 26))
                .padding(.bottom, 4)

            Text(entry.username)
                .font(.system(size: 13, weight: isMe ? .bold : .semibold))
                .foregroundColor(isMe ? Color.ucdGold : (colorScheme == .dark ? .white : .primary))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.bottom, 2)

            Text("\(entry.guesses)/6 · \(formatTime(entry.timeSeconds))")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
                .padding(.bottom, 8)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(podiumColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(podiumColor.opacity(0.3), lineWidth: 1)
                )
                .frame(height: height)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading leaderboard...")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundColor(.textSecondary.opacity(0.5))
            Text("No scores yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            Text("Be the first to complete today's Wordle!")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.textSecondary.opacity(0.5))
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            Button("Try Again") {
                Task { await viewModel.loadData() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.ucdGold))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    let selectedDate: Date
    let onSelect: (Date) -> Void
    let onCancel: () -> Void

    @State private var pickerDate: Date = Date()
    @Environment(\.colorScheme) private var colorScheme

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
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme))
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onSelect(pickerDate) }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            pickerDate = selectedDate
        }
    }
}

#Preview {
    LeaderboardView()
}
