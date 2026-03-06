//
//  LeaderboardView.swift
//  TapInApp
//
//  Created by Claude on 2/21/26.
//

import SwiftUI

enum LeaderboardGame: String, CaseIterable {
    case dailyFive = "DailyFive"
    case pipes = "Pipes"
    case echo = "Echo"

    var hasLeaderboard: Bool {
        switch self {
        case .dailyFive, .pipes: return true
        case .echo: return false
        }
    }

    var icon: String {
        switch self {
        case .dailyFive: return "puzzlepiece.extension.fill"
        case .echo: return "waveform.path"
        case .pipes: return "point.topleft.down.to.point.bottomright.curvepath.fill"
        }
    }
}

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
                    // Swipeable game pages
                    TabView(selection: Binding(
                        get: { viewModel.selectedGame },
                        set: { viewModel.switchGame(to: $0) }
                    )) {
                        ForEach(LeaderboardGame.allCases, id: \.self) { game in
                            gamePageView(for: game)
                                .tag(game)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.25), value: viewModel.selectedGame)

                    // Page indicator dots
                    HStack(spacing: 6) {
                        ForEach(LeaderboardGame.allCases, id: \.self) { game in
                            Circle()
                                .fill(viewModel.selectedGame == game ? Color.ucdGold : Color.secondary.opacity(0.35))
                                .frame(width: viewModel.selectedGame == game ? 8 : 6, height: viewModel.selectedGame == game ? 8 : 6)
                                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedGame)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Leaderboard")
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

    // MARK: - Game Page View

    @ViewBuilder
    private func gamePageView(for game: LeaderboardGame) -> some View {
        VStack(spacing: 0) {
            // Game title header
            HStack {
                Image(systemName: game.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(game.rawValue)
                    .font(.system(size: 17, weight: .bold))
                if !game.hasLeaderboard {
                    Text("Coming Soon")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.5)))
                }
            }
            .foregroundColor(colorScheme == .dark ? .white : .primary)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if game.hasLeaderboard {
                dateNavigator
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                Divider()

                ScrollView {
                    if viewModel.isLoading && viewModel.selectedGame == game {
                        loadingView
                    } else if let error = viewModel.errorMessage, viewModel.selectedGame == game {
                        errorView(error)
                    } else if game == .pipes {
                        if viewModel.hasPipesEntries {
                            pipesRankingsList
                        } else {
                            pipesEmptyView
                        }
                    } else if viewModel.hasEntries {
                        rankingsList
                    } else {
                        emptyView
                    }
                }
                .refreshable { await viewModel.refresh() }
            } else {
                comingSoonView
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
            Text("Be the first to complete today's DailyFive!")
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

    // MARK: - Pipes Rankings List

    private var pipesRankingsList: some View {
        VStack(spacing: 16) {
            let top3 = viewModel.pipesEntries.filter { $0.rank <= 3 }
            if !top3.isEmpty {
                pipesPodiumView(top3: top3)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            let remaining = viewModel.pipesEntries.filter { $0.rank > 3 }
            if !remaining.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(remaining) { entry in
                        pipesRowView(entry: entry)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Pipes Podium

    private func pipesPodiumView(top3: [PipesLeaderboardEntryResponse]) -> some View {
        let first = top3.first(where: { $0.rank == 1 })
        let second = top3.first(where: { $0.rank == 2 })
        let third = top3.first(where: { $0.rank == 3 })

        return HStack(alignment: .bottom, spacing: 10) {
            if let entry = second {
                pipesPodiumSlot(entry: entry, height: 64, medalEmoji: "🥈")
            } else {
                Spacer().frame(maxWidth: .infinity)
            }

            if let entry = first {
                pipesPodiumSlot(entry: entry, height: 88, medalEmoji: "🥇")
            } else {
                Spacer().frame(maxWidth: .infinity)
            }

            if let entry = third {
                pipesPodiumSlot(entry: entry, height: 48, medalEmoji: "🥉")
            } else {
                Spacer().frame(maxWidth: .infinity)
            }
        }
    }

    private func pipesPodiumSlot(entry: PipesLeaderboardEntryResponse, height: CGFloat, medalEmoji: String) -> some View {
        let isMe = viewModel.isCurrentUserPipesEntry(entry)
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

            Text("\(entry.totalMoves) moves · \(formatTime(entry.totalTimeSeconds))")
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

    // MARK: - Pipes Row

    private func pipesRowView(entry: PipesLeaderboardEntryResponse) -> some View {
        let isMe = viewModel.isCurrentUserPipesEntry(entry)

        return HStack(spacing: 12) {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(Color(hex: "#6B7280"))
                    .frame(width: 32, height: 32)
                Text("\(entry.rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.username)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                        .lineLimit(1)

                    if isMe {
                        Text("YOU")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.ucdGold))
                    }
                }

                Text("\(entry.puzzlesCompleted)/5 · \(entry.totalMoves) moves")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Text(formatTime(entry.totalTimeSeconds))
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMe
                      ? (colorScheme == .dark ? Color.ucdGold.opacity(0.15) : Color.ucdGold.opacity(0.1))
                      : (colorScheme == .dark ? Color(hex: "#1a2033") : .white))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isMe
                        ? Color.ucdGold.opacity(0.4)
                        : (colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9")),
                        lineWidth: 1)
        )
    }

    // MARK: - Pipes Empty View

    private var pipesEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundColor(.textSecondary.opacity(0.5))
            Text("No scores yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            Text("Be the first to complete today's Pipes puzzles!")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Coming Soon View

    private var comingSoonView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color(hex: "#1a2033") : Color(hex: "#f1f5f9"))
                    .frame(width: 90, height: 90)

                Image(systemName: viewModel.selectedGame.icon)
                    .font(.system(size: 36))
                    .foregroundColor(colorScheme == .dark ? Color(hex: "#cbd5e1") : Color(hex: "#94a3b8"))
            }

            Text("Coming Soon")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .primary)

            Text("\(viewModel.selectedGame.rawValue) leaderboards are on the way!")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
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
