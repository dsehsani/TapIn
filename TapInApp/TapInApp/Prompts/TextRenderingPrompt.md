# ClaudeIDE Prompt: California Aggie News Pipeline

## Context & Goal

I am building a UC Davis student app in SwiftUI using MVVM architecture. We currently display news cards from The California Aggie using RSS, but tapping a card does nothing. I need you to build a complete, in-app news reading pipeline that:

1. Fetches the article list from The Aggie's RSS feed
2. On article tap, fetches and parses the full article content (NO Safari, NO external browser)
3. Renders a clean, native reading view inside the app

The Aggie runs on WordPress. I have confirmed the HTML is fully static (no JavaScript rendering), so SwiftSoup is the correct parsing approach. Do NOT use WKWebView or SFSafariViewController.

---

## Architecture Requirements

Follow strict MVVM. All networking, parsing, and business logic lives in Services and ViewModels. Views are dumb — they only display data passed from ViewModels.

### File Structure to Create

```
Services/
  News/
    AggieFeedService.swift        ← RSS parsing via FeedKit
    AggieArticleParser.swift      ← HTML parsing via SwiftSoup
    NewsService.swift             ← Orchestrates feed + article fetching

Models/
  NewsArticle.swift               ← Article list model (from RSS)
  ArticleContent.swift            ← Full article body model (from HTML parse)

ViewModels/
  NewsViewModel.swift             ← Drives the news feed list
  ArticleDetailViewModel.swift    ← Drives the article reading view

Views/
  News/
    NewsCardView.swift            ← Existing card (wire up tap)
    ArticleDetailView.swift       ← NEW: full in-app reading view
    ArticleDetailLoadingView.swift ← Skeleton/loading state
```

---

## Dependencies to Add via Swift Package Manager

Add these two packages:

1. **FeedKit** — `https://github.com/nmdias/FeedKit` (RSS parsing)
2. **SwiftSoup** — `https://github.com/scinfu/SwiftSoup` (HTML parsing)

---

## Step 1: NewsArticle Model

```swift
// Models/NewsArticle.swift
import Foundation

struct NewsArticle: Identifiable, Hashable {
    let id: String           // Use article URL as stable ID
    let title: String
    let author: String
    let publishDate: Date
    let articleURL: URL
    let thumbnailURL: URL?
    let category: String
    let summary: String      // RSS description snippet (for card preview)
}
```

---

## Step 2: ArticleContent Model

```swift
// Models/ArticleContent.swift
import Foundation

struct ArticleContent {
    let title: String
    let author: String
    let authorEmail: String?
    let publishDate: Date
    let category: String
    let thumbnailURL: URL?
    let bodyParagraphs: [String]   // Clean extracted paragraphs, in order
    let articleURL: URL            // Keep for share sheet
}
```

---

## Step 3: AggieFeedService (RSS)

```swift
// Services/News/AggieFeedService.swift
import Foundation
import FeedKit

protocol AggieFeedServiceProtocol {
    func fetchArticles() async throws -> [NewsArticle]
}

final class AggieFeedService: AggieFeedServiceProtocol {

    private let rssURL = URL(string: "https://theaggie.org/feed/")!

    func fetchArticles() async throws -> [NewsArticle] {
        return try await withCheckedThrowingContinuation { continuation in
            let parser = FeedParser(URL: rssURL)
            parser.parseAsync { result in
                switch result {
                case .success(let feed):
                    guard let rssFeed = feed.rssFeed,
                          let items = rssFeed.items else {
                        continuation.resume(returning: [])
                        return
                    }
                    let articles = items.compactMap { item -> NewsArticle? in
                        guard
                            let title = item.title,
                            let link = item.link,
                            let articleURL = URL(string: link)
                        else { return nil }

                        // Extract thumbnail from media:content or enclosure
                        let thumbnailURL: URL? = {
                            if let mediaURL = item.media?.mediaContents?.first?.attributes?.url {
                                return URL(string: mediaURL)
                            }
                            if let enclosureURL = item.enclosure?.attributes?.url {
                                return URL(string: enclosureURL)
                            }
                            return nil
                        }()

                        return NewsArticle(
                            id: link,
                            title: title,
                            author: item.dublinCore?.dcCreator ?? "The Aggie",
                            publishDate: item.pubDate ?? Date(),
                            articleURL: articleURL,
                            thumbnailURL: thumbnailURL,
                            category: item.categories?.first?.value ?? "News",
                            summary: item.description?.strippingHTML() ?? ""
                        )
                    }
                    continuation.resume(returning: articles)

                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Helper: Strip HTML from RSS description snippets
private extension String {
    func strippingHTML() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return (try? NSAttributedString(data: data, options: options, documentAttributes: nil))?.string ?? self
    }
}
```

---

## Step 4: AggieArticleParser (SwiftSoup HTML → ArticleContent)

This is the critical piece. The Aggie uses WordPress. Based on their actual HTML structure, use these exact selectors:

```swift
// Services/News/AggieArticleParser.swift
import Foundation
import SwiftSoup

enum AggieParserError: Error {
    case fetchFailed(URLError)
    case parseFailure(String)
    case contentNotFound
}

protocol AggieArticleParserProtocol {
    func fetchAndParse(url: URL, fallback: NewsArticle) async throws -> ArticleContent
}

final class AggieArticleParser: AggieArticleParserProtocol {

    func fetchAndParse(url: URL, fallback: NewsArticle) async throws -> ArticleContent {
        // 1. Fetch raw HTML
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw AggieParserError.fetchFailed(URLError(.badServerResponse))
        }

        // 2. Parse with SwiftSoup
        return try parseHTML(html, articleURL: url, fallback: fallback)
    }

    // MARK: - Private Parsing Logic

    private func parseHTML(_ html: String, articleURL: URL, fallback: NewsArticle) throws -> ArticleContent {
        let doc = try SwiftSoup.parse(html)

        // --- Title ---
        // WordPress: <h1 class="post-title"> or the first <h1> inside article
        let title = (try? doc.select("h1.post-title").first()?.text())
            ?? (try? doc.select("article h1").first()?.text())
            ?? fallback.title

        // --- Author ---
        // The Aggie pattern: "By FIRSTNAME LASTNAME — email@theaggie.org"
        // This appears in a <p> or <strong> tag near the top of the content
        let authorLine = (try? doc.select(".author-name").first()?.text())
            ?? (try? doc.select("a[href^='mailto:campus'], a[href^='mailto:features'], a[href^='mailto:sports'], a[href^='mailto:science'], a[href^='mailto:arts'], a[href^='mailto:city'], a[href^='mailto:opinion']").first()?.parent()?.text())
            ?? fallback.author

        let (authorName, authorEmail) = parseAuthorLine(authorLine, fallback: fallback.author)

        // --- Category ---
        // WordPress breadcrumb: <span class="cat-links"> or <a rel="category tag">
        let category = (try? doc.select("a[rel='category tag']").first()?.text())
            ?? (try? doc.select(".cat-links a").first()?.text())
            ?? fallback.category

        // --- Thumbnail ---
        // WordPress featured image: first <img> inside .post-thumbnail or .wp-post-image
        let thumbnailURL: URL? = {
            let src = (try? doc.select(".post-thumbnail img").first()?.attr("src"))
                ?? (try? doc.select("img.wp-post-image").first()?.attr("src"))
                ?? (try? doc.select("article img").first()?.attr("src"))
            return src.flatMap { URL(string: $0) } ?? fallback.thumbnailURL
        }()

        // --- Body Paragraphs ---
        // WordPress: article body lives in .entry-content or .post-content
        // We grab all <p> tags, filter out empty ones and nav/footer noise
        let bodyParagraphs = try extractBodyParagraphs(from: doc)

        guard !bodyParagraphs.isEmpty else {
            throw AggieParserError.contentNotFound
        }

        return ArticleContent(
            title: title,
            author: authorName,
            authorEmail: authorEmail,
            publishDate: fallback.publishDate,
            category: category,
            thumbnailURL: thumbnailURL,
            bodyParagraphs: bodyParagraphs,
            articleURL: articleURL
        )
    }

    // MARK: - Body Paragraph Extraction

    private func extractBodyParagraphs(from doc: Document) throws -> [String] {
        // Try specific WordPress content containers first
        let contentSelectors = [
            ".entry-content",
            ".post-content",
            ".article-content",
            "article .content"
        ]

        var contentElement: Element? = nil
        for selector in contentSelectors {
            if let el = try? doc.select(selector).first() {
                contentElement = el
                break
            }
        }

        // Fallback: use the full article element
        let container = contentElement ?? (try doc.select("article").first()) ?? doc.body()!

        // Extract paragraphs, filtering noise
        let paragraphs = try container.select("p")
        let cleaned: [String] = try paragraphs.compactMap { p in
            let text = try p.text().trimmingCharacters(in: .whitespacesAndNewlines)

            // Filter out empty, very short, or navigational paragraphs
            guard text.count > 20 else { return nil }

            // Filter out byline paragraph (starts with "Written by:")
            guard !text.lowercased().hasPrefix("written by") else { return nil }

            // Filter out social share prompts and footer noise
            let noisePatterns = ["follow us on", "subscribe to", "support the aggie", "©"]
            guard !noisePatterns.contains(where: { text.lowercased().contains($0) }) else { return nil }

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
            let email = parts.count > 1
                ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                : nil
            return (name.isEmpty ? fallback : name, email)
        }

        return (cleaned.isEmpty ? fallback : cleaned, nil)
    }
}
```

---

## Step 5: NewsService (Orchestrator)

```swift
// Services/News/NewsService.swift
import Foundation

protocol NewsServiceProtocol {
    func fetchArticleList() async throws -> [NewsArticle]
    func fetchArticleContent(for article: NewsArticle) async throws -> ArticleContent
}

final class NewsService: NewsServiceProtocol {

    private let feedService: AggieFeedServiceProtocol
    private let parser: AggieArticleParserProtocol

    // Simple in-memory cache to avoid re-fetching already opened articles
    private var contentCache: [String: ArticleContent] = [:]

    init(
        feedService: AggieFeedServiceProtocol = AggieFeedService(),
        parser: AggieArticleParserProtocol = AggieArticleParser()
    ) {
        self.feedService = feedService
        self.parser = parser
    }

    func fetchArticleList() async throws -> [NewsArticle] {
        try await feedService.fetchArticles()
    }

    func fetchArticleContent(for article: NewsArticle) async throws -> ArticleContent {
        // Return cached content if available
        if let cached = contentCache[article.id] {
            return cached
        }
        let content = try await parser.fetchAndParse(url: article.articleURL, fallback: article)
        contentCache[article.id] = content
        return content
    }
}
```

---

## Step 6: NewsViewModel (update existing)

```swift
// ViewModels/NewsViewModel.swift
import Foundation

@MainActor
final class NewsViewModel: ObservableObject {
    @Published var articles: [NewsArticle] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let newsService: NewsServiceProtocol

    init(newsService: NewsServiceProtocol = NewsService()) {
        self.newsService = newsService
    }

    func loadArticles() async {
        isLoading = true
        errorMessage = nil
        do {
            articles = try await newsService.fetchArticleList()
        } catch {
            errorMessage = "Could not load news. Please try again."
            print("NewsViewModel error: \(error)")
        }
        isLoading = false
    }
}
```

---

## Step 7: ArticleDetailViewModel (NEW)

```swift
// ViewModels/ArticleDetailViewModel.swift
import Foundation

enum ArticleLoadState {
    case idle
    case loading
    case loaded(ArticleContent)
    case failed(String)
}

@MainActor
final class ArticleDetailViewModel: ObservableObject {
    @Published var loadState: ArticleLoadState = .idle

    private let newsService: NewsServiceProtocol

    init(newsService: NewsServiceProtocol = NewsService()) {
        self.newsService = newsService
    }

    func load(article: NewsArticle) async {
        loadState = .loading
        do {
            let content = try await newsService.fetchArticleContent(for: article)
            loadState = .loaded(content)
        } catch AggieParserError.contentNotFound {
            loadState = .failed("Article content could not be found.")
        } catch {
            loadState = .failed("Failed to load article. Check your connection.")
        }
    }
}
```

---

## Step 8: ArticleDetailView (NEW — the in-app reading view)

Design this as a clean reading view. Style it to match the app's existing design language. Requirements:

- Full-screen sheet or NavigationLink destination (your choice based on existing nav pattern)
- Top: Featured image (AsyncImage, full width, aspect ratio 16:9)
- Below image: Category tag, Title (large bold), Author name, Date
- Body: Scrollable paragraphs with comfortable line spacing and readable font size
- Top navigation: Back button (dismiss), Share button (ShareLink using articleURL)
- Show `ArticleDetailLoadingView` skeleton while loading
- Show error state with retry button if load fails

```swift
// Views/News/ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: NewsArticle
    @StateObject private var viewModel = ArticleDetailViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                ArticleDetailLoadingView()
            case .loaded(let content):
                ArticleReadingView(content: content, onDismiss: { dismiss() })
            case .failed(let message):
                ArticleErrorView(message: message, onRetry: {
                    Task { await viewModel.load(article: article) }
                })
            }
        }
        .task {
            await viewModel.load(article: article)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Reading View (content rendered here)
private struct ArticleReadingView: View {
    let content: ArticleContent
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // --- Featured Image ---
                if let imageURL = content.thumbnailURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        default:
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.2))
                                .aspectRatio(16/9, contentMode: .fit)
                        }
                    }
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 16) {

                    // --- Category ---
                    Text(content.category.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .padding(.top, 20)

                    // --- Title ---
                    Text(content.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)

                    // --- Byline ---
                    HStack(spacing: 4) {
                        Text(content.author)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(content.publishDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // --- Body ---
                    ForEach(Array(content.bodyParagraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.body)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 8)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .overlay(alignment: .topLeading) {
            // Floating nav bar over the image
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                }
                Spacer()
                ShareLink(item: content.articleURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 52)
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Loading Skeleton
struct ArticleDetailLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Rectangle()
                .foregroundColor(.gray.opacity(0.2))
                .aspectRatio(16/9, contentMode: .fit)
                .padding(.bottom, 8)

            Group {
                RoundedRectangle(cornerRadius: 4).frame(width: 80, height: 12)
                RoundedRectangle(cornerRadius: 4).frame(height: 24)
                RoundedRectangle(cornerRadius: 4).frame(width: 200, height: 14)
                Divider()
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4).frame(height: 14)
                }
            }
            .foregroundColor(.gray.opacity(0.25))
            .padding(.horizontal, 20)

            Spacer()
        }
        .redacted(reason: .placeholder)
    }
}

// MARK: - Error State
private struct ArticleErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again", action: onRetry)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}
```

---

## Step 9: Wire Up the Tap in NewsCardView

In the existing `NewsCardView` or wherever news cards are listed, wrap each card in a `NavigationLink`:

```swift
NavigationLink(destination: ArticleDetailView(article: article)) {
    NewsCardView(article: article)
}
.buttonStyle(.plain) // Prevents NavigationLink's default blue tint on the card
```

Make sure the parent list view is inside a `NavigationStack` or `NavigationView`.

---

## Design Patterns & Adaptability Notes for ClaudeIDE

- **Protocol-driven services**: `AggieFeedServiceProtocol`, `AggieArticleParserProtocol`, and `NewsServiceProtocol` all use protocols so they can be swapped for mock implementations in tests or previews without changing any View or ViewModel code.

- **Cache in NewsService**: The in-memory `contentCache` avoids re-fetching articles the user has already opened. This can be upgraded to disk cache (e.g., `URLCache` or `FileManager`) later without touching the ViewModel.

- **Selector fallback chain**: The HTML parser uses multiple fallback selectors (e.g., `.entry-content` → `.post-content` → `article`). If The Aggie updates their WordPress theme, only the selector list in `AggieArticleParser` needs updating — nothing else changes.

- **`ArticleLoadState` enum**: Using a state enum instead of multiple `@Published` booleans makes it impossible to have invalid states (e.g., `isLoading: true` and `content != nil` at the same time). Add new states here as needed.

- **Noise filter list**: The paragraph filter in `extractBodyParagraphs` uses an array of noise patterns. Extend this array if new footer/boilerplate text appears without touching the rest of the logic.

- **Future: AI Summarizer hook**: `ArticleContent.bodyParagraphs` is a clean `[String]` array. When Suhani's AI summarizer is ready, she can pass `content.bodyParagraphs.joined(separator: "\n\n")` directly to the summarizer endpoint — no additional parsing needed.Yes
