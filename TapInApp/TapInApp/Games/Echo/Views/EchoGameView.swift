//
//  EchoGameView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Root entry view for the Echo game. Orchestrates all sub-views
//  and switches between game states. Handles feedback overlay,
//  round result, and game over screens inline.
//

import SwiftUI

// MARK: - Echo Game View
struct EchoGameView: View {
    var onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = EchoGameViewModel()

    var body: some View {
        ZStack {
            // Background
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header (always visible except game over)
                if viewModel.gameState != .gameOver {
                    EchoHeaderView(
                        onBack: onDismiss,
                        roundIndex: viewModel.currentRoundIndex,
                        totalRounds: viewModel.totalRounds,
                        attemptsRemaining: viewModel.attemptsRemaining,
                        maxAttempts: viewModel.maxAttempts,
                        showAttempts: viewModel.gameState == .playerInput || viewModel.gameState == .evaluating,
                        colorScheme: colorScheme
                    )
                }

                // Main content area — switches on game state
                switch viewModel.gameState {
                case .showingSequence:
                    sequenceDisplayPhase

                case .revealingRules:
                    ruleRevealPhase

                case .playerInput:
                    playerInputPhase

                case .evaluating:
                    evaluatingPhase

                case .roundComplete:
                    roundCompletePhase

                case .gameOver:
                    gameOverPhase
                }
            }
        }
    }

    // MARK: - Phase Views

    @ViewBuilder
    private var sequenceDisplayPhase: some View {
        if let round = viewModel.currentRound {
            SequenceDisplayView(
                sequence: round.originalSequence,
                isVisible: viewModel.sequenceVisible,
                countdownProgress: viewModel.countdownProgress,
                colorScheme: colorScheme
            )
        }
    }

    @ViewBuilder
    private var ruleRevealPhase: some View {
        if let round = viewModel.currentRound {
            RuleRevealView(
                rules: round.rules,
                revealedCount: viewModel.revealedRuleCount,
                colorScheme: colorScheme
            )
        }
    }

    private var playerInputPhase: some View {
        SequenceInputView(
            rules: viewModel.currentRound?.rules ?? [],
            playerSequence: viewModel.playerSequence,
            onShapeSelected: { shape in viewModel.addItemToSequence(shape: shape) },
            onCycleColor: { index in viewModel.cycleColor(at: index) },
            onRemoveItem: { index in viewModel.removeItem(at: index) },
            onClear: { viewModel.clearPlayerSequence() },
            onSubmit: { viewModel.submitAnswer() },
            colorScheme: colorScheme
        )
    }

    // MARK: - Evaluating / Feedback Phase

    @ViewBuilder
    private var evaluatingPhase: some View {
        VStack(spacing: 24) {
            Spacer()

            if viewModel.lastSubmissionCorrect == true {
                // Correct feedback
                correctFeedback
            } else if viewModel.showCorrectAnswer {
                // Out of attempts — show correct answer
                outOfAttemptsFeedback
            } else {
                // Incorrect but attempts remain
                incorrectFeedback
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var correctFeedback: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .scaleEffect(viewModel.lastSubmissionCorrect == true ? 1.0 : 0.5)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.lastSubmissionCorrect)

            Text("Correct!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.green)

            // Show player's sequence with green borders
            HStack(spacing: 12) {
                ForEach(viewModel.playerSequence) { item in
                    ShapeItemView(item: item, size: 44, showBorder: true, borderColor: .green)
                }
            }
        }
    }

    private var incorrectFeedback: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
                .modifier(ShakeEffect(shakes: 3))

            Text("Not quite...")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.red)

            Text("\(viewModel.attemptsRemaining) attempt\(viewModel.attemptsRemaining == 1 ? "" : "s") remaining")
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)

            // Show player's sequence with red borders
            HStack(spacing: 12) {
                ForEach(viewModel.playerSequence) { item in
                    ShapeItemView(item: item, size: 44, showBorder: true, borderColor: .red)
                }
            }

            Button(action: { viewModel.retryAfterIncorrect() }) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.ucdBlue)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var outOfAttemptsFeedback: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Out of attempts")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.red)

            // Player's answer
            VStack(spacing: 8) {
                Text("Your answer:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
                HStack(spacing: 10) {
                    ForEach(viewModel.playerSequence) { item in
                        ShapeItemView(item: item, size: 40, showBorder: true, borderColor: .red)
                    }
                }
            }

            // Correct answer
            if let round = viewModel.currentRound {
                VStack(spacing: 8) {
                    Text("Correct answer:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                    HStack(spacing: 10) {
                        ForEach(round.correctAnswer) { item in
                            ShapeItemView(item: item, size: 40, showBorder: true, borderColor: .green)
                        }
                    }
                }
            }

            Button(action: { viewModel.continueAfterFailure() }) {
                Text("Continue")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.ucdBlue)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Round Complete Phase

    private var roundCompletePhase: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Round Complete!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)

            // Result card
            VStack(spacing: 16) {
                let solved = viewModel.roundResults.last ?? false
                let roundScore = viewModel.roundScores.last ?? 0
                let attemptsUsed = viewModel.attemptsUsedPerRound.last ?? 0

                HStack(spacing: 12) {
                    Image(systemName: solved ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(solved ? .green : .red)
                    Text(solved ? "Solved" : "Failed")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(solved ? .green : .red)
                }

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("Attempts")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                        Text("\(attemptsUsed + (solved ? 1 : 0))/\(viewModel.maxAttempts)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)
                    }

                    VStack(spacing: 4) {
                        Text("Score")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                        Text("+\(roundScore)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.ucdGold)
                    }
                }
            }
            .padding(24)
            .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"), lineWidth: 1)
            )
            .padding(.horizontal, 32)

            // Total score
            Text("Total: \(viewModel.score)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.ucdGold)

            // Round progress dots
            HStack(spacing: 10) {
                ForEach(0..<viewModel.totalRounds, id: \.self) { index in
                    Circle()
                        .fill(roundDotColor(for: index))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.textSecondary.opacity(0.3), lineWidth: index >= viewModel.roundResults.count ? 1 : 0)
                        )
                }
            }

            Spacer()

            // Next round / See results button
            Button(action: { viewModel.advanceToNextRound() }) {
                Text(viewModel.currentRoundIndex + 1 >= viewModel.totalRounds ? "See Results" : "Next Round")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.ucdBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.ucdGold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private func roundDotColor(for index: Int) -> Color {
        if index < viewModel.roundResults.count {
            return viewModel.roundResults[index] ? .green : .red
        }
        return Color.textSecondary.opacity(0.15)
    }

    // MARK: - Game Over Phase

    private var gameOverPhase: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Text("Game Complete!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)

                // Final score
                VStack(spacing: 4) {
                    Text("Final Score")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                    Text("\(viewModel.score)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color.ucdGold)
                    Text("out of \(viewModel.totalRounds * 300)")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }

                // Stats card
                VStack(spacing: 16) {
                    StatRow(label: "Rounds solved", value: "\(viewModel.roundsSolved)/\(viewModel.totalRounds)", colorScheme: colorScheme)
                    StatRow(label: "Perfect rounds", value: "\(viewModel.perfectRounds)", colorScheme: colorScheme)
                    StatRow(label: "Total attempts", value: "\(viewModel.totalAttemptsUsed + viewModel.roundsSolved)/\(viewModel.totalRounds * viewModel.maxAttempts)", colorScheme: colorScheme)
                }
                .padding(20)
                .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"), lineWidth: 1)
                )
                .padding(.horizontal, 32)

                // Round breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Round Breakdown")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)

                    ForEach(0..<viewModel.totalRounds, id: \.self) { index in
                        if index < viewModel.roundResults.count {
                            RoundBreakdownRow(
                                roundNumber: index + 1,
                                solved: viewModel.roundResults[index],
                                score: viewModel.roundScores[index],
                                attemptsUsed: viewModel.attemptsUsedPerRound[index],
                                colorScheme: colorScheme
                            )
                        }
                    }
                }
                .padding(.horizontal, 32)

                // Action buttons
                HStack(spacing: 16) {
                    Button(action: { viewModel.startGame() }) {
                        Text("Play Again")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.ucdBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.ucdGold)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: onDismiss) {
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let label: String
    let value: String
    var colorScheme: ColorScheme = .light

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)
        }
    }
}

struct RoundBreakdownRow: View {
    let roundNumber: Int
    let solved: Bool
    let score: Int
    let attemptsUsed: Int
    var colorScheme: ColorScheme = .light

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: solved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(solved ? .green : .red)
                .font(.system(size: 16))

            Text("R\(roundNumber)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)

            Spacer()

            if solved {
                Text("\(score)pts")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.ucdGold)

                let attemptLabel = attemptsUsed == 0 ? "1st try" : attemptsUsed == 1 ? "2nd try" : "3rd try"
                Text("(\(attemptLabel))")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            } else {
                Text("0pts")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

// MARK: - Shake Effect Modifier

struct ShakeEffect: ViewModifier {
    var shakes: Int
    @State private var shakeOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onAppear {
                withAnimation(.default.repeatCount(shakes * 2, autoreverses: true).speed(6)) {
                    shakeOffset = 8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    shakeOffset = 0
                }
            }
    }
}

// MARK: - Preview
#Preview {
    EchoGameView(onDismiss: {})
}
