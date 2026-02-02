//
//  EchoRound.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  Represents one complete round of the Echo game, containing the
//  original sequence, the rules to apply, and the pre-computed correct answer.
//

import Foundation

// MARK: - Echo Round
struct EchoRound {
    let originalSequence: [EchoItem]
    let rules: [EchoRule]
    let correctAnswer: [EchoItem]
}
