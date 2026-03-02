//
//  LeaveGameDialog.swift
//  TapInApp
//
//  Custom overlay dialog shown when the user tries to leave an in-progress Wordle game.
//  Features a 10-second countdown ring that auto-dismisses (user stays, score still eligible).
//

import SwiftUI
import Combine

struct LeaveGameDialog: View {
    /// Called when the user chooses to stay (or the timer expires)
    var onStay: () -> Void
    /// Called when the user chooses to leave (disqualifies score)
    var onLeave: () -> Void

    @Environment(\.colorScheme) var colorScheme

    // MARK: - Countdown State

    private let totalSeconds = 10
    @State private var secondsRemaining = 10
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { /* block taps behind dialog */ }

            // Dialog card
            VStack(spacing: 20) {
                // Title
                Text("Leave game?")
                    .font(.title2.bold())
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#022851"))

                // Message
                Text("If you leave now, your score won't be submitted to the leaderboard.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)

                // Countdown ring
                ZStack {
                    // Background track
                    Circle()
                        .stroke(Color.gray.opacity(0.25), lineWidth: 4)

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: CGFloat(secondsRemaining) / CGFloat(totalSeconds))
                        .stroke(Color.ucdGold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: secondsRemaining)

                    // Seconds label
                    Text("\(secondsRemaining)")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#022851"))
                }
                .frame(width: 56, height: 56)

                // Buttons
                HStack(spacing: 16) {
                    // Stay button
                    Button {
                        stopTimer()
                        onStay()
                    } label: {
                        Text("Stay")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.ucdGold)
                            .cornerRadius(10)
                    }

                    // Leave button
                    Button {
                        stopTimer()
                        onLeave()
                    } label: {
                        Text("Leave")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(10)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.wordleBackground(colorScheme))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            )
            .padding(.horizontal, 40)
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Timer

    private func startTimer() {
        secondsRemaining = totalSeconds
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if secondsRemaining > 1 {
                    secondsRemaining -= 1
                } else {
                    // Timer expired — auto-dismiss, user stays
                    stopTimer()
                    onStay()
                }
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}
