//
//  ArticleContent.swift
//  TapInApp
//
//  Full article body model, populated by AggieArticleParser from HTML scraping.
//

import Foundation

struct ArticleContent {
    let title: String
    let author: String
    let authorEmail: String?
    let publishDate: Date
    let category: String
    let thumbnailURL: URL?
    let bodyParagraphs: [String]   // Clean extracted paragraphs, in order
    let articleURL: URL            // Kept for the share sheet
}
