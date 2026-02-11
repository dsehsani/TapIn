//
//  EchoShape.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  Enum representing the four geometric shapes used in the Echo game.
//  Each shape maps to an SF Symbol for rendering.
//

import SwiftUI

// MARK: - Echo Shape
enum EchoShape: String, CaseIterable, Codable {
    case circle
    case triangle
    case square
    case pentagon

    /// SF Symbol name for rendering this shape
    var symbolName: String {
        switch self {
        case .circle: return "circle.fill"
        case .triangle: return "triangle.fill"
        case .square: return "square.fill"
        case .pentagon: return "pentagon.fill"
        }
    }

    /// Display name shown in the shape picker
    var displayName: String {
        switch self {
        case .circle: return "Circle"
        case .triangle: return "Triangle"
        case .square: return "Square"
        case .pentagon: return "Pentagon"
        }
    }
}
