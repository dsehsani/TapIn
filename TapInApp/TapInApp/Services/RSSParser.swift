//
//  RSSParser.swift
//  TapInApp
//
//  Created by Claude on 2/14/26.
//
//  MARK: - RSS Parser
//  Parses RSS 2.0 XML feeds into NewsArticle models.
//

import Foundation

struct RSSParser {

    /// Parses an RSS XML string into an array of NewsArticle objects.
    /// - Parameters:
    ///   - xmlString: The raw RSS XML string
    ///   - defaultCategory: Default category if none found in the feed
    /// - Returns: Array of parsed NewsArticle objects
    static func parse(_ xmlString: String, defaultCategory: String = "News") -> [NewsArticle] {
        let parser = RSSXMLParser(defaultCategory: defaultCategory)
        return parser.parse(xmlString)
    }
}

// MARK: - XML Parser Delegate

private class RSSXMLParser: NSObject, XMLParserDelegate {

    private var articles: [NewsArticle] = []
    private var currentElement: String = ""
    private var currentTitle: String = ""
    private var currentLink: String = ""
    private var currentDescription: String = ""
    private var currentPubDate: String = ""
    private var currentAuthor: String = ""
    private var currentCategories: [String] = []
    private var currentContent: String = ""
    private var isInsideItem: Bool = false

    private let defaultCategory: String

    init(defaultCategory: String) {
        self.defaultCategory = defaultCategory
        super.init()
    }

    func parse(_ xmlString: String) -> [NewsArticle] {
        guard let data = xmlString.data(using: .utf8) else {
            return []
        }

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        return articles
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        if elementName == "item" {
            isInsideItem = true
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
            currentAuthor = ""
            currentCategories = []
            currentContent = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }

        switch currentElement {
        case "title":
            currentTitle += string
        case "link":
            currentLink += string
        case "description":
            currentDescription += string
        case "pubDate":
            currentPubDate += string
        case "dc:creator", "creator":
            currentAuthor += string
        case "category":
            // Only append non-empty strings
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                currentCategories.append(trimmed)
            }
        case "content:encoded", "encoded":
            currentContent += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            isInsideItem = false

            let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let link = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = cleanHTML(currentDescription.trimmingCharacters(in: .whitespacesAndNewlines))
            let author = currentAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
            let category = currentCategories.first ?? defaultCategory
            let pubDate = parseDate(currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines))

            // Extract image URL from content if available
            let imageURL = extractImageURL(from: currentContent)

            // Estimate read time based on content length (roughly 200 words per minute)
            let wordCount = currentContent.split(separator: " ").count
            let readTime = max(1, wordCount / 200)

            // Skip if title is empty
            guard !title.isEmpty else { return }

            let article = NewsArticle(
                title: title,
                excerpt: description,
                imageURL: imageURL,
                category: category,
                timestamp: pubDate,
                author: author.isEmpty ? nil : author,
                readTime: readTime,
                isFeatured: false,
                articleURL: link
            )

            articles.append(article)
        }
    }

    // MARK: - Helpers

    /// Parses RFC 822 date format used in RSS feeds
    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try RFC 822 format (e.g., "Fri, 13 Feb 2026 03:29:25 +0000")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try alternate format without timezone name
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Fallback to current date
        return Date()
    }

    /// Removes HTML tags from a string
    private func cleanHTML(_ html: String) -> String {
        // Remove HTML tags
        var cleaned = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode common HTML entities
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&#039;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "&apos;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "&#8217;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "&#8220;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&#8221;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&#8230;", with: "...")
        cleaned = cleaned.replacingOccurrences(of: "&hellip;", with: "...")

        // Remove extra whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extracts the first image URL from HTML content
    private func extractImageURL(from html: String) -> String {
        // Look for img src attribute
        let pattern = "<img[^>]+src\\s*=\\s*[\"']([^\"']+)[\"']"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return ""
        }

        let range = NSRange(html.startIndex..., in: html)
        if let match = regex.firstMatch(in: html, options: [], range: range) {
            if let urlRange = Range(match.range(at: 1), in: html) {
                return String(html[urlRange])
            }
        }

        return ""
    }
}
