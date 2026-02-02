//
//  EchoRoundGenerator.swift
//  TapInApp
//
//  MARK: - Service Layer (MVVM)
//  Generates random Echo rounds with increasing difficulty.
//  Handles sequence generation, rule selection, and rule application.
//

import Foundation

// MARK: - Round Generator
struct EchoRoundGenerator {

    // MARK: - Difficulty Table

    /// Returns (sequenceLength, ruleCount) for a given round index
    private static func difficulty(for roundIndex: Int) -> (sequenceLength: Int, ruleCount: Int) {
        switch roundIndex {
        case 0: return (3, 1)
        case 1: return (4, 1)
        case 2: return (4, 2)
        case 3: return (5, 2)
        default: return (5, 3)
        }
    }

    // MARK: - Round Generation

    /// Generates a complete round for the given round index
    static func generateRound(roundIndex: Int) -> EchoRound {
        let (sequenceLength, ruleCount) = difficulty(for: roundIndex)

        let originalSequence = generateRandomSequence(length: sequenceLength)
        let rules = selectRules(count: ruleCount, sequenceLength: sequenceLength, originalSequence: originalSequence)
        let correctAnswer = applyAllRules(rules, to: originalSequence)

        return EchoRound(
            originalSequence: originalSequence,
            rules: rules,
            correctAnswer: correctAnswer
        )
    }

    /// Generates all rounds for a full game session
    static func generateAllRounds(count: Int) -> [EchoRound] {
        (0..<count).map { generateRound(roundIndex: $0) }
    }

    // MARK: - Sequence Generation

    /// Creates a random sequence of EchoItems
    private static func generateRandomSequence(length: Int) -> [EchoItem] {
        (0..<length).map { _ in
            EchoItem(
                shape: EchoShape.allCases.randomElement()!,
                color: EchoColor.allCases.randomElement()!
            )
        }
    }

    // MARK: - Rule Selection

    /// Selects unique rules for a round, ensuring removedEverySecond is safe
    private static func selectRules(count: Int, sequenceLength: Int, originalSequence: [EchoItem]) -> [EchoRule] {
        var availableRules = EchoRule.allCases.shuffled()
        var selectedRules: [EchoRule] = []
        var simulatedSequence = originalSequence

        for _ in 0..<count {
            // Try each available rule
            var ruleSelected = false
            for (index, rule) in availableRules.enumerated() {
                // Check if removedEverySecond would leave too few items
                if rule == .removedEverySecond && simulatedSequence.count < 3 {
                    continue
                }

                selectedRules.append(rule)
                simulatedSequence = applyRule(rule, to: simulatedSequence)
                availableRules.remove(at: index)
                ruleSelected = true
                break
            }

            // Fallback: if no rule was valid, pick any non-remove rule
            if !ruleSelected {
                let safeRules: [EchoRule] = [.reversed, .shifted, .colorSwapped]
                let fallback = safeRules.randomElement()!
                selectedRules.append(fallback)
                simulatedSequence = applyRule(fallback, to: simulatedSequence)
            }
        }

        return selectedRules
    }

    // MARK: - Rule Application

    /// Applies a single rule to a sequence and returns the transformed result
    static func applyRule(_ rule: EchoRule, to sequence: [EchoItem]) -> [EchoItem] {
        guard !sequence.isEmpty else { return sequence }

        switch rule {
        case .reversed:
            return sequence.reversed().map { EchoItem(shape: $0.shape, color: $0.color) }

        case .shifted:
            guard let last = sequence.last else { return sequence }
            let shifted = [EchoItem(shape: last.shape, color: last.color)] +
                sequence.dropLast().map { EchoItem(shape: $0.shape, color: $0.color) }
            return shifted

        case .removedEverySecond:
            return sequence.enumerated()
                .filter { $0.offset % 2 == 0 }
                .map { EchoItem(shape: $0.element.shape, color: $0.element.color) }

        case .colorSwapped:
            return sequence.map { item in
                EchoItem(shape: item.shape, color: item.color.nextInCycle)
            }
        }
    }

    /// Applies all rules sequentially to a sequence
    static func applyAllRules(_ rules: [EchoRule], to sequence: [EchoItem]) -> [EchoItem] {
        var result = sequence
        for rule in rules {
            result = applyRule(rule, to: result)
        }
        return result
    }
}
