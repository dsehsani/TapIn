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
            .navigationTitle("Wordle Leaderboard")
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

            if !viewModel.isToday {
                Button {
                    viewModel.goToToday()
                } label: {
                    Text("Today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.ucdGold))
                }
            }
        }
    }

    // MARK: - Rankings List

    private var rankingsList: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.entries) { entry in
                LeaderboardRowView(
                    entry: entry,
                    isCurrentUser: viewModel.isCurrentUserEntry(entry),
                    colorScheme: colorScheme
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
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
