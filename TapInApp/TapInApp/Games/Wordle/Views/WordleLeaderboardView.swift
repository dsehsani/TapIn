//
//  LeaderboardView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 3/1/26.
//
//  MARK: - Dedicated Leaderboard View
//  Full leaderboard sheet with podium for top 3 and scrollable list below.
//

import SwiftUI

struct WordleLeaderboardView: View {
    let entries: [LeaderboardEntryResponse]
    let assignedUsername: String?
    let isLoading: Bool
    let onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var muted: Color {
        colorScheme == .dark ? Color(hex: "#8b8fa3") : Color(hex: "#64748b")
    }

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "#0f172a")
    }

    private var bg: Color {
        colorScheme == .dark ? Color(hex: "#0f0f1e") : Color(hex: "#f8fafc")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading leaderboard...")
                        .foregroundColor(muted)
                } else if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trophy")
                            .font(.system(size: 40))
                            .foregroundColor(muted)
                        Text("No entries yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(muted)
                        Text("Be the first to complete today's puzzle!")
                            .font(.system(size: 14))
                            .foregroundColor(muted.opacity(0.7))
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Podium
                            podiumView
                                .padding(.top, 8)

                            // Remaining entries (4th place and below)
                            let remaining = entries.filter { $0.rank > 3 }
                            if !remaining.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(remaining) { entry in
                                        listRow(entry: entry)
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(colorScheme == .dark ? Color(hex: "#1a1a2e") : .white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color(hex: "#e2e8f0"), lineWidth: 1)
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Podium

    private var podiumView: some View {
        let top3 = Array(entries.prefix(3))
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
        .padding(.horizontal, 24)
    }

    private func podiumSlot(entry: LeaderboardEntryResponse, height: CGFloat, medalEmoji: String) -> some View {
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
            // Medal
            Text(medalEmoji)
                .font(.system(size: 24))
                .padding(.bottom, 4)

            // Username
            Text(entry.username)
                .font(.system(size: 13, weight: isMe ? .bold : .semibold))
                .foregroundColor(isMe ? Color.wordleGreen : textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.bottom, 2)

            // Stats
            Text("\(entry.guesses)/6 · \(formatTime(entry.timeSeconds))")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(muted)
                .padding(.bottom, 8)

            // Pedestal block
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

    // MARK: - List Row

    private func listRow(entry: LeaderboardEntryResponse) -> some View {
        let isMe = assignedUsername != nil && entry.username == assignedUsername

        return HStack(spacing: 12) {
            // Rank
            Text("#\(entry.rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(muted)
                .frame(width: 32, alignment: .leading)

            // Username
            Text(entry.username)
                .font(.system(size: 15, weight: isMe ? .bold : .medium))
                .foregroundColor(isMe ? Color.wordleGreen : textPrimary)
                .lineLimit(1)

            Spacer()

            // Guesses
            Text("\(entry.guesses)/6")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(muted)

            // Time
            Text(formatTime(entry.timeSeconds))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(muted)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isMe ? Color.wordleGreen.opacity(0.08) : Color.clear)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
