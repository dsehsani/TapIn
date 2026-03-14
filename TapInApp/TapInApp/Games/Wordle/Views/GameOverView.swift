//
//  GameOverView.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/20/26.
//
//  MARK: - View Layer (MVVM)
//  Bottom sheet overlay showing game results, podium leaderboard, and actions.
//

import SwiftUI

struct GameOverView: View {
    // MARK: - Properties

    let gameState: GameState
    let targetWord: String
    let attempts: Int
    let isArchiveMode: Bool
    let isTodayCompleted: Bool

    var leaderboardEntries: [LeaderboardEntryResponse] = []
    var assignedUsername: String? = nil
    var isLoadingLeaderboard: Bool = false

    let onPlayToday: () -> Void
    let onBrowseArchive: () -> Void
    let onDismiss: () -> Void
    let onBack: () -> Void

    var colorScheme: ColorScheme = .light

    // MARK: - Drag / Expand State

    @State private var sheetDragOffset: CGFloat = 0
    @State private var isLeaderboardExpanded: Bool = false

    // MARK: - Helpers

    private var cardBg: Color {
        colorScheme == .dark ? Color(hex: "#141424") : .white
    }

    private var muted: Color {
        colorScheme == .dark ? Color(hex: "#8b8fa3") : Color(hex: "#64748b")
    }

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "#0f172a")
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Backdrop
            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    isLeaderboardExpanded = false
                    onDismiss()
                }

            // Bottom sheet
            VStack(spacing: 0) {
                // Drag indicator + close button
                ZStack {
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 36, height: 4)

                    HStack {
                        Spacer()
                        Button(action: {
                            isLeaderboardExpanded = false
                            onDismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                                .frame(width: 28, height: 28)
                                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 10)
                .padding(.bottom, 16)

                // Result header
                resultHeader
                    .padding(.bottom, 18)

                // Leaderboard (win + non-archive only)
                if gameState == .won && !isArchiveMode {
                    if AppState.shared.isGuestMode {
                        guestLeaderboardBanner
                            .padding(.bottom, 18)
                    } else {
                        leaderboardSection
                            .padding(.bottom, 18)
                    }
                }

                // Actions
                actionSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
            }
            .contentShape(Rectangle())
            .offset(y: sheetDragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let dy = value.translation.height
                        if isLeaderboardExpanded {
                            if dy > 0 { sheetDragOffset = dy }
                        } else {
                            sheetDragOffset = dy
                        }
                    }
                    .onEnded { value in
                        let dy = value.translation.height
                        if isLeaderboardExpanded {
                            if dy > 80 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    isLeaderboardExpanded = false
                                }
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sheetDragOffset = 0
                            }
                        } else {
                            if dy < -60 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    isLeaderboardExpanded = true
                                    sheetDragOffset = 0
                                }
                            } else if dy > 120 {
                                isLeaderboardExpanded = false
                                onDismiss()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    sheetDragOffset = 0
                                }
                            }
                        }
                    }
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardBg)
                    .shadow(color: .black.opacity(0.2), radius: 30, y: -5)
                    .offset(y: sheetDragOffset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : .clear, lineWidth: 1)
                    .offset(y: sheetDragOffset)
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isLeaderboardExpanded)
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: gameState == .won ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 38))
                .foregroundColor(gameState == .won ? Color.wordleGreen : Color(red: 0.85, green: 0.3, blue: 0.3))

            Text(gameState == .won ? "Nice Work!" : "Game Over")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(textPrimary)

            if gameState == .won {
                Text("\(attempts)/6 guesses")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(muted)
            } else {
                HStack(spacing: 6) {
                    Text("Answer:")
                        .font(.system(size: 14))
                        .foregroundColor(muted)
                    Text(targetWord)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.wordleGreen)
                }
            }
        }
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(spacing: 12) {
            // Header row
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.ucdGold)
                    Text("LEADERBOARD")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(muted)
                }
                Spacer()
                if !isLeaderboardExpanded {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                        Text("See top 10")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(muted)
                }
            }
            .padding(.horizontal, 24)

            if isLoadingLeaderboard {
                ProgressView()
                    .padding(.vertical, 16)
            } else if leaderboardEntries.isEmpty {
                Text("No entries yet — you might be first!")
                    .font(.system(size: 13))
                    .foregroundColor(muted)
                    .padding(.vertical, 8)

            } else if isLeaderboardExpanded {
                // Expanded: full scrollable list
                fullLeaderboardList
                    .padding(.horizontal, 24)

            } else {
                // Collapsed: podium (top 3)
                podiumView
                    .padding(.horizontal, 24)

                // Current user rank (if not in top 3)
                if let me = leaderboardEntries.first(where: { assignedUsername != nil && $0.username == assignedUsername }),
                   me.rank > 3 {
                    HStack(spacing: 8) {
                        Text("#\(me.rank)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.wordleGreen)
                        Text(me.username)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(textPrimary)
                        Spacer()
                        Text(me.guessesDisplay)
                            .font(.system(size: 12))
                        Text(formatTime(me.timeSeconds))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(muted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.wordleGreen.opacity(0.1))
                    )
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    // MARK: - Guest Leaderboard Banner

    private var guestLeaderboardBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.ucdGold)
                Text("LEADERBOARD")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(muted)
            }

            VStack(spacing: 6) {
                Text("Sign in to compete")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                Text("Create an account to submit scores and appear on the leaderboard.")
                    .font(.system(size: 12))
                    .foregroundColor(muted)
                    .multilineTextAlignment(.center)

                Button {
                    AppState.shared.signOut()
                } label: {
                    Text("Sign In")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.wordleGreen, in: Capsule())
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Podium

    private var podiumView: some View {
        let top3 = Array(leaderboardEntries.prefix(3))
        let first = top3.first(where: { $0.rank == 1 })
        let second = top3.first(where: { $0.rank == 2 })
        let third = top3.first(where: { $0.rank == 3 })

        return HStack(alignment: .bottom, spacing: 8) {
            // 2nd place (left)
            if let entry = second {
                podiumSlot(entry: entry, height: 52, medal: "2")
            } else {
                Spacer().frame(maxWidth: .infinity)
            }

            // 1st place (center, tallest)
            if let entry = first {
                podiumSlot(entry: entry, height: 72, medal: "1")
            } else {
                Spacer().frame(maxWidth: .infinity)
            }

            // 3rd place (right)
            if let entry = third {
                podiumSlot(entry: entry, height: 40, medal: "3")
            } else {
                Spacer().frame(maxWidth: .infinity)
            }
        }
    }

    private func podiumSlot(entry: LeaderboardEntryResponse, height: CGFloat, medal: String) -> some View {
        let isMe = assignedUsername != nil && entry.username == assignedUsername
        let podiumColor: Color = {
            switch entry.rank {
            case 1: return Color.ucdGold
            case 2: return Color(hex: "#94a3b8")
            case 3: return Color(hex: "#b45309")
            default: return Color.gray
            }
        }()

        return VStack(spacing: 0) {
            // Username
            Text(entry.username)
                .font(.system(size: 11, weight: isMe ? .bold : .semibold))
                .foregroundColor(isMe ? Color.wordleGreen : textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.bottom, 4)

            // Stats
            Text("\(entry.guesses)/6")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(muted)
                .padding(.bottom, 6)

            // Pedestal
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(podiumColor.opacity(colorScheme == .dark ? 0.3 : 0.15))

                VStack(spacing: 2) {
                    Text(medal)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(podiumColor)
                    Text(formatTime(entry.timeSeconds))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(muted)
                }
            }
            .frame(height: height)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private var actionSection: some View {
        VStack(spacing: 10) {
            if isArchiveMode {
                if !isTodayCompleted {
                    actionButton("Play Today's Word", filled: true, action: onPlayToday)
                }
                actionButton("Browse Archive", filled: isTodayCompleted, action: onBrowseArchive)
            } else {
                actionButton("Browse Archive", filled: true, action: onBrowseArchive)
            }
            actionButton("Back to Games", filled: false, action: onBack)
        }
    }

    private func actionButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(filled ? .white : textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(filled ? Color.wordleGreen : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(filled ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.12) : Color(hex: "#e2e8f0")), lineWidth: 1)
                )
        }
    }

    // MARK: - Full Leaderboard List (Expanded)

    private var fullLeaderboardList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                    let isMe = assignedUsername != nil && entry.username == assignedUsername

                    HStack(spacing: 12) {
                        Text("#\(entry.rank)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(rankColor(for: entry.rank))
                            .frame(width: 32, alignment: .leading)

                        Text(entry.username)
                            .font(.system(size: 14, weight: isMe ? .bold : .semibold))
                            .foregroundColor(isMe ? Color.wordleGreen : textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(entry.guesses)/6")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(muted)

                        Text(formatTime(entry.timeSeconds))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(muted)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isMe ? Color.wordleGreen.opacity(0.08) : Color.clear)
                    )

                    if index < leaderboardEntries.count - 1 {
                        Divider()
                            .opacity(0.4)
                            .padding(.leading, 44)
                    }
                }
            }
        }
        .frame(maxHeight: 340)
    }

    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color.ucdGold
        case 2: return Color(hex: "#94a3b8")
        case 3: return Color(hex: "#b45309")
        default: return Color.secondary
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        GameOverView(
            gameState: .won,
            targetWord: "BRAIN",
            attempts: 4,
            isArchiveMode: false,
            isTodayCompleted: true,
            leaderboardEntries: [
                LeaderboardEntryResponse(rank: 1, username: "darius", guesses: 3, guesses_display: "🟩🟩🟩", time_seconds: 45),
                LeaderboardEntryResponse(rank: 2, username: "alex", guesses: 4, guesses_display: "🟩🟩🟩🟩", time_seconds: 72),
                LeaderboardEntryResponse(rank: 3, username: "maya", guesses: 5, guesses_display: "🟩🟩🟩🟩🟩", time_seconds: 120),
            ],
            assignedUsername: "darius",
            onPlayToday: { },
            onBrowseArchive: { },
            onDismiss: { },
            onBack: { }
        )
    }
}
