//
//  CrosswordPuzzle.swift
//  TapInApp
//
//  MARK: - Model Layer
//  Represents a complete crossword puzzle definition.
//

import Foundation

/// A complete crossword puzzle definition
struct CrosswordPuzzle: Identifiable, Codable {
    let id: UUID
    let title: String
    let author: String
    let dateKey: String
    let gridSize: Int
    let clues: [CrosswordClue]
    let blockedCells: [(row: Int, col: Int)]

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        dateKey: String = "",
        gridSize: Int = 5,
        clues: [CrosswordClue],
        blockedCells: [(row: Int, col: Int)] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.dateKey = dateKey
        self.gridSize = gridSize
        self.clues = clues
        self.blockedCells = blockedCells
    }

    /// All across clues sorted by number
    var acrossClues: [CrosswordClue] {
        clues.filter { $0.direction == .across }.sorted { $0.number < $1.number }
    }

    /// All down clues sorted by number
    var downClues: [CrosswordClue] {
        clues.filter { $0.direction == .down }.sorted { $0.number < $1.number }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, title, author, dateKey, gridSize, clues, blockedCellsData
    }

    struct BlockedCellData: Codable {
        let row: Int
        let col: Int
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        dateKey = try container.decode(String.self, forKey: .dateKey)
        gridSize = try container.decode(Int.self, forKey: .gridSize)
        clues = try container.decode([CrosswordClue].self, forKey: .clues)
        let blockedData = try container.decode([BlockedCellData].self, forKey: .blockedCellsData)
        blockedCells = blockedData.map { ($0.row, $0.col) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(dateKey, forKey: .dateKey)
        try container.encode(gridSize, forKey: .gridSize)
        try container.encode(clues, forKey: .clues)
        let blockedData = blockedCells.map { BlockedCellData(row: $0.row, col: $0.col) }
        try container.encode(blockedData, forKey: .blockedCellsData)
    }
}
