//
//  EchoRule.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  The four transformation rules that can be applied to a sequence.
//  Each rule has a display name and description for the UI.
//

import Foundation

// MARK: - Echo Rule
enum EchoRule: String, CaseIterable, Codable {
    case reversed
    case shifted
    case removedEverySecond
    case colorSwapped

    /// Short name shown on rule cards and reminder pills
    var displayName: String {
        switch self {
        case .reversed: return "Reverse"
        case .shifted: return "Shift Right"
        case .removedEverySecond: return "Remove Every 2nd"
        case .colorSwapped: return "Color Swap"
        }
    }

    /// Longer description shown on rule cards during reveal
    var ruleDescription: String {
        switch self {
        case .reversed: return "Reverse the order of the sequence"
        case .shifted: return "Move the last item to the front"
        case .removedEverySecond: return "Remove every second item (2nd, 4th, ...)"
        case .colorSwapped: return "Advance each color one step in the cycle"
        }
    }

    /// SF Symbol for the rule card icon
    var iconName: String {
        switch self {
        case .reversed: return "arrow.left.arrow.right"
        case .shifted: return "arrow.right.to.line"
        case .removedEverySecond: return "scissors"
        case .colorSwapped: return "paintpalette"
        }
    }
}
