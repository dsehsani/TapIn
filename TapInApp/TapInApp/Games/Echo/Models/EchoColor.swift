//
//  EchoColor.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  Enum representing the four possible colors for shapes in the Echo game.
//  Supports a cyclic color swap rule.
//

import SwiftUI

// MARK: - Echo Color
enum EchoColor: String, CaseIterable, Codable {
    case blue
    case red
    case yellow
    case green

    /// SwiftUI Color for rendering
    var swiftUIColor: Color {
        switch self {
        case .blue: return .blue
        case .red: return .red
        case .yellow: return .yellow
        case .green: return .green
        }
    }

    /// The next color in the cycle: blue -> red -> yellow -> green -> blue
    var nextInCycle: EchoColor {
        switch self {
        case .blue: return .red
        case .red: return .yellow
        case .yellow: return .green
        case .green: return .blue
        }
    }
}
