//
//  EchoGameViewModel.swift
//  TapInApp
//
//  MARK: - ViewModel Layer (MVVM)
//  Central ViewModel for the Echo game. Manages all game logic,
//  state transitions, timers, scoring, and player input.
//
//  Architecture:
//  - Uses @Observable macro for reactive state updates
//  - Coordinates timer-based phase transitions (sequence display, rule reveal)
//  - Manages player input for sequence building
//
//  Dependencies:
//  - Models: EchoItem, EchoShape, EchoColor, EchoRule, EchoRound, EchoGameState
//  - Services: EchoRoundGenerator
//

import SwiftUI

// MARK: - Echo Game ViewModel
@Observable
class EchoGameViewModel {

    // MARK: - Game Configuration

    let totalRounds: Int = 5
    let maxAttempts: Int = 3
    let sequenceDisplayDuration: Double = 2.0
    let ruleRevealInterval: Double = 1.5

    // MARK: - Round State

    var currentRoundIndex: Int = 0
    var currentRound: EchoRound?
    var attemptsRemaining: Int = 3
    var gameState: EchoGameState = .showingSequence

    // MARK: - Player Input

    var playerSequence: [EchoItem] = []

    // MARK: - Rule Reveal State

    var revealedRuleCount: Int = 0

    // MARK: - Feedback

    var lastSubmissionCorrect: Bool? = nil
    var showCorrectAnswer: Bool = false

    // MARK: - Scoring

    var score: Int = 0
    var roundScores: [Int] = []
    var roundResults: [Bool] = []
    var attemptsUsedPerRound: [Int] = []

    // MARK: - All Rounds

    var rounds: [EchoRound] = []

    // MARK: - Animation State

    var sequenceVisible: Bool = false
    var countdownProgress: Double = 1.0

    // MARK: - Initialization

    init() {
        startGame()
    }

    // MARK: - Lifecycle

    func startGame() {
        rounds = EchoRoundGenerator.generateAllRounds(count: totalRounds)
        currentRoundIndex = 0
        score = 0
        roundScores = []
        roundResults = []
        attemptsUsedPerRound = []
        startRound()
    }

    func startRound() {
        guard currentRoundIndex < rounds.count else {
            gameState = .gameOver
            return
        }

        currentRound = rounds[currentRoundIndex]
        attemptsRemaining = maxAttempts
        playerSequence = []
        revealedRuleCount = 0
        lastSubmissionCorrect = nil
        showCorrectAnswer = false
        sequenceVisible = false
        countdownProgress = 1.0
        gameState = .showingSequence

        // Start the sequence display phase
        beginSequenceDisplay()
    }

    func advanceToNextRound() {
        currentRoundIndex += 1
        if currentRoundIndex < totalRounds {
            startRound()
        } else {
            gameState = .gameOver
        }
    }

    // MARK: - Sequence Display Phase

    private func beginSequenceDisplay() {
        // Show shapes with staggered animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.sequenceVisible = true
            }
        }

        // Animate countdown bar
        withAnimation(.linear(duration: sequenceDisplayDuration).delay(0.3)) {
            countdownProgress = 0.0
        }

        // After display duration, transition to rule reveal
        let totalDisplayTime = sequenceDisplayDuration + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDisplayTime) {
            self.onSequenceDisplayComplete()
        }
    }

    func onSequenceDisplayComplete() {
        withAnimation(.easeInOut(duration: 0.3)) {
            sequenceVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.gameState = .revealingRules
            self.beginRuleReveal()
        }
    }

    // MARK: - Rule Reveal Phase

    private func beginRuleReveal() {
        revealedRuleCount = 0
        revealNextRule()
    }

    func revealNextRule() {
        guard let round = currentRound else { return }

        if revealedRuleCount < round.rules.count {
            withAnimation(.easeOut(duration: 0.4)) {
                self.revealedRuleCount += 1
            }

            // Schedule next rule or transition to input
            if revealedRuleCount < round.rules.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + ruleRevealInterval) {
                    self.revealNextRule()
                }
            } else {
                // All rules revealed, wait then transition to input
                DispatchQueue.main.asyncAfter(deadline: .now() + ruleRevealInterval) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.gameState = .playerInput
                    }
                }
            }
        }
    }

    // MARK: - Player Input

    func addItemToSequence(shape: EchoShape) {
        guard gameState == .playerInput else { return }
        let newItem = EchoItem(shape: shape, color: .blue)
        withAnimation(.easeOut(duration: 0.2)) {
            playerSequence.append(newItem)
        }
    }

    func cycleColor(at index: Int) {
        guard gameState == .playerInput else { return }
        guard index < playerSequence.count else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            playerSequence[index].color = playerSequence[index].color.nextInCycle
        }
    }

    func removeItem(at index: Int) {
        guard gameState == .playerInput else { return }
        guard index < playerSequence.count else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            _ = playerSequence.remove(at: index)
        }
    }

    func clearPlayerSequence() {
        guard gameState == .playerInput else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            playerSequence.removeAll()
        }
    }

    // MARK: - Submission

    func submitAnswer() {
        guard gameState == .playerInput else { return }
        guard !playerSequence.isEmpty else { return }
        guard let round = currentRound else { return }

        gameState = .evaluating

        let isCorrect = sequencesMatch(playerSequence, round.correctAnswer)

        if isCorrect {
            lastSubmissionCorrect = true
            let roundScore = calculateRoundScore()
            score += roundScore
            roundScores.append(roundScore)
            roundResults.append(true)
            attemptsUsedPerRound.append(maxAttempts - attemptsRemaining)

            // Auto-transition to round complete after feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.gameState = .roundComplete
                }
            }
        } else {
            lastSubmissionCorrect = false
            attemptsRemaining -= 1

            if attemptsRemaining <= 0 {
                showCorrectAnswer = true
                roundScores.append(0)
                roundResults.append(false)
                attemptsUsedPerRound.append(maxAttempts)
            }
        }
    }

    func retryAfterIncorrect() {
        guard attemptsRemaining > 0 else { return }
        lastSubmissionCorrect = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            gameState = .playerInput
        }
    }

    func continueAfterFailure() {
        withAnimation(.easeInOut(duration: 0.3)) {
            gameState = .roundComplete
        }
    }

    // MARK: - Answer Checking

    private func sequencesMatch(_ a: [EchoItem], _ b: [EchoItem]) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).allSatisfy { EchoItem.matchesContent($0, $1) }
    }

    // MARK: - Scoring

    func calculateRoundScore() -> Int {
        return attemptsRemaining * 100
    }

    /// Number of rounds solved on first attempt
    var perfectRounds: Int {
        zip(roundResults, attemptsUsedPerRound)
            .filter { $0.0 && $0.1 == 0 }
            .count
    }

    /// Total attempts used across all rounds
    var totalAttemptsUsed: Int {
        attemptsUsedPerRound.reduce(0, +)
    }

    /// Number of rounds solved
    var roundsSolved: Int {
        roundResults.filter { $0 }.count
    }
}
