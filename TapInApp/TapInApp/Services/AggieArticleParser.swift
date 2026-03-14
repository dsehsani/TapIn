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
        // Scan body paragraphs for "By NAME" first — most reliable for The Aggie.
        // Fall back to meta element selectors, then RSS fallback.
        var authorLine: String = fallback.author ?? "The Aggie"
        if let v = extractBylineFromContent(doc)                                           { authorLine = v }
        else if let v = try? doc.select(".author-name").first()?.text(), !v.isEmpty        { authorLine = v }
        else if let v = try? doc.select(".entry-author").first()?.text(), !v.isEmpty       { authorLine = v }
        else if let v = try? doc.select(".author.vcard a").first()?.text(), !v.isEmpty     { authorLine = v }
        else if let v = try? doc.select(".byline a").first()?.text(), !v.isEmpty           { authorLine = v }
        else if let v = try? doc.select(".entry-meta .author").first()?.text(), !v.isEmpty { authorLine = v }

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
            articleURL: articleURL,
            tldrBullets: []
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

        let cleaned: [String] = paragraphs.compactMap { p in
            // Use inner HTML to preserve bold/strong markup
            let text = extractTextPreservingBold(from: p)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard text.count > 20 else { return nil }

            let lower = text.lowercased()

            // Filter out the byline paragraph ("By NAME — email")
            guard !lower.hasPrefix("by ") else { return nil }

            guard !noisePatterns.contains(where: { lower.hasPrefix($0) || lower.contains($0) }) else { return nil }

            return text
        }

        return cleaned
    }

    /// Converts inner HTML of a <p> to plain text, wrapping <strong>/<b> content with **markdown**.
    private func extractTextPreservingBold(from element: Element) -> String {
        guard var html = try? element.html() else {
            return (try? element.text()) ?? ""
        }

        // Replace <strong> and <b> tags with markdown bold markers
        let boldOpen  = try? NSRegularExpression(pattern: "<(strong|b)[^>]*>", options: .caseInsensitive)
        let boldClose = try? NSRegularExpression(pattern: "</(strong|b)>",     options: .caseInsensitive)
        let range = NSRange(html.startIndex..., in: html)
        html = boldOpen?.stringByReplacingMatches(in: html, range: range, withTemplate: "**") ?? html
        let range2 = NSRange(html.startIndex..., in: html)
        html = boldClose?.stringByReplacingMatches(in: html, range: range2, withTemplate: "**") ?? html

        // Strip all remaining HTML tags
        let tagPattern = try? NSRegularExpression(pattern: "<[^>]+>", options: [])
        let range3 = NSRange(html.startIndex..., in: html)
        html = tagPattern?.stringByReplacingMatches(in: html, range: range3, withTemplate: "") ?? html

        // Tighten up ** markers — "** text **" → "**text**" so markdown parses correctly
        let spaceAfter  = try? NSRegularExpression(pattern: #"\*\*\s+"#, options: [])
        let spaceBefore = try? NSRegularExpression(pattern: #"\s+\*\*"#, options: [])
        let r4 = NSRange(html.startIndex..., in: html)
        html = spaceAfter?.stringByReplacingMatches(in: html, range: r4, withTemplate: "**") ?? html
        let r5 = NSRange(html.startIndex..., in: html)
        html = spaceBefore?.stringByReplacingMatches(in: html, range: r5, withTemplate: "**") ?? html

        // Decode common HTML entities
        return html
            .replacingOccurrences(of: "&amp;",   with: "&")
            .replacingOccurrences(of: "&lt;",    with: "<")
            .replacingOccurrences(of: "&gt;",    with: ">")
            .replacingOccurrences(of: "&quot;",  with: "\"")
            .replacingOccurrences(of: "&nbsp;",  with: " ")
            .replacingOccurrences(of: "&#160;",  with: " ")
            .replacingOccurrences(of: "&#8220;", with: "\u{201C}")
            .replacingOccurrences(of: "&#8221;", with: "\u{201D}")
            .replacingOccurrences(of: "&#8216;", with: "\u{2018}")
            .replacingOccurrences(of: "&#8217;", with: "\u{2019}")
            .replacingOccurrences(of: "&#8230;", with: "…")
            .replacingOccurrences(of: "&#38;",   with: "&")
    }

    /// Scans the first 6 paragraphs for a line starting with "By " — The Aggie's byline format.
    private func extractBylineFromContent(_ doc: Document) -> String? {
        guard let paragraphs = try? doc.select("p") else { return nil }
        for (i, p) in paragraphs.enumerated() {
            if i > 6 { break }
            let text = (try? p.text())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.lowercased().hasPrefix("by ") {
                return text
            }
        }
        return nil
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
