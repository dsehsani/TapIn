//
//  AggieArticleParser.swift
//  TapInApp
//
//  Fetches a full Aggie article page and parses it into an ArticleContent model
//  using SwiftSoup to extract paragraphs from The Aggie's WordPress HTML structure.
//

import Foundation
import SwiftSoup

enum AggieParserError: Error {
    case invalidURL
    case fetchFailed(URLError)
    case contentNotFound
}

final class AggieArticleParser {

    func fetchAndParse(articleURL: URL, fallback: NewsArticle) async throws -> ArticleContent {
        // 1. Fetch raw HTML
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: articleURL)
        } catch let urlError as URLError {
            throw AggieParserError.fetchFailed(urlError)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw AggieParserError.fetchFailed(URLError(.badServerResponse))
        }

        // 2. Parse with SwiftSoup
        return try parseHTML(html, articleURL: articleURL, fallback: fallback)
    }

    // MARK: - Private Parsing Logic

    private func parseHTML(_ html: String, articleURL: URL, fallback: NewsArticle) throws -> ArticleContent {
        let doc = try SwiftSoup.parse(html)

        // --- Title ---
        // WordPress: <h1 class="post-title"> or first <h1> inside article
        let title = (try? doc.select("h1.post-title").first()?.text())
            ?? (try? doc.select("article h1").first()?.text())
            ?? (try? doc.select("h1.entry-title").first()?.text())
            ?? fallback.title

        // --- Author ---
        // The Aggie pattern: "By FIRSTNAME LASTNAME — email@theaggie.org"
        let authorLine = (try? doc.select(".author-name").first()?.text())
            ?? (try? doc.select("a[rel='author']").first()?.text())
            ?? (try? doc.select(".entry-author").first()?.text())
            ?? fallback.author
            ?? "The Aggie"

        let (authorName, authorEmail) = parseAuthorLine(authorLine, fallback: fallback.author ?? "The Aggie")

        // --- Category ---
        let category = (try? doc.select("a[rel='category tag']").first()?.text())
            ?? (try? doc.select(".cat-links a").first()?.text())
            ?? fallback.category

        // --- Thumbnail ---
        let thumbnailURL: URL? = {
            let src = (try? doc.select(".post-thumbnail img").first()?.attr("src"))
                ?? (try? doc.select("img.wp-post-image").first()?.attr("src"))
                ?? (try? doc.select("article img").first()?.attr("src"))
            if let src = src { return URL(string: src) }
            return fallback.imageURL.isEmpty ? nil : URL(string: fallback.imageURL)
        }()

        // --- Body Paragraphs ---
        let bodyParagraphs = try extractBodyParagraphs(from: doc)

        guard !bodyParagraphs.isEmpty else {
            throw AggieParserError.contentNotFound
        }

        return ArticleContent(
            title: title,
            author: authorName,
            authorEmail: authorEmail,
            publishDate: fallback.timestamp,
            category: category,
            thumbnailURL: thumbnailURL,
            bodyParagraphs: bodyParagraphs,
            articleURL: articleURL
        )
    }

    // MARK: - Body Paragraph Extraction

    private func extractBodyParagraphs(from doc: Document) throws -> [String] {
        // Try WordPress content containers in priority order
        let contentSelectors = [
            ".entry-content",
            ".post-content",
            ".article-content",
            "article .content"
        ]

        var container: Element? = nil
        for selector in contentSelectors {
            if let el = try? doc.select(selector).first() {
                container = el
                break
            }
        }

        // Fallback to full <article> or <body>
        let root = container
            ?? (try? doc.select("article").first())
            ?? doc.body()!

        let paragraphs = try root.select("p")
        let noisePatterns = ["follow us on", "subscribe to", "support the aggie", "©", "written by"]

        let cleaned: [String] = try paragraphs.compactMap { p in
            let text = try p.text().trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip very short or navigational paragraphs
            guard text.count > 20 else { return nil }

            // Skip noise
            let lower = text.lowercased()
            guard !noisePatterns.contains(where: { lower.hasPrefix($0) || lower.contains($0) }) else { return nil }

            return text
        }

        return cleaned
    }

    // MARK: - Author Line Parser

    private func parseAuthorLine(_ raw: String, fallback: String) -> (name: String, email: String?) {
        // Pattern: "By AALIYAH ESPAÑOL-RIVAS — campus@theaggie.org"
        let cleaned = raw
            .replacingOccurrences(of: "By ", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.contains("—") {
            let parts = cleaned.components(separatedBy: "—")
            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let email = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            return (name.isEmpty ? fallback : name, email)
        }

        return (cleaned.isEmpty ? fallback : cleaned, nil)
    }
}
