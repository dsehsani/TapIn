//
//  EchoItem.swift
//  TapInApp
//
//  MARK: - Model Layer (MVVM)
//  A single element in an Echo sequence: one shape with one color.
//

import Foundation

// MARK: - Echo Item
struct EchoItem: Identifiable, Equatable, Codable {
    let id: UUID
    var shape: EchoShape
    var color: EchoColor

    init(id: UUID = UUID(), shape: EchoShape, color: EchoColor) {
        self.id = id
        self.shape = shape
        self.color = color
    }

    /// Compares shape and color only (ignoring id) for answer checking
    static func matchesContent(_ lhs: EchoItem, _ rhs: EchoItem) -> Bool {
        return lhs.shape == rhs.shape && lhs.color == rhs.color
    }
}
