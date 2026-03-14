# TapIn — Article TLDR Bullets

## Overview

Add a short AI-generated TLDR to each article — 3 to 5 bullets, each a **short bold label** + **one short sentence** of explanation. Displayed at the top of the article reading view, before the body, so users can decide in two seconds whether the article is worth reading.

**Cost strategy:** Generate once on the backend at scrape time using Haiku. Feed it only the first 4 paragraphs (not the full article). Cache permanently in Firestore alongside the existing content. Zero per-user API calls — ever.

---

## What Changes

**Backend:**
- `backend/services/claude_service.py` — add `generate_article_tldr()`
- `backend/api/articles.py` — call it on cache miss in `GET /api/articles/content`
- `backend/repositories/article_content_repository.py` — store + return `tldrBullets`

**iOS:**
- `TapInApp/Models/ArticleContent.swift` — add `tldrBullets: [String]`
- `TapInApp/Services/NewsService.swift` — decode `tldrBullets` from response
- `TapInApp/Views/ArticleDetailView.swift` — render `ArticleTLDRCard` above the body

---

## Backend Changes

### 1. `claude_service.py` — Add `generate_article_tldr()`

Add alongside the other internal pipeline methods. Uses Haiku + only the first 4 paragraphs to keep token cost minimal.

```python
def generate_article_tldr(self, title: str, paragraphs: list[str]) -> list[str]:
    """
    Generates 3–5 TLDR bullet points for a news article.
    Each bullet: short bold label + one short explanation sentence.
    Uses only the first 4 paragraphs to minimize token cost.
    Called once at scrape time — result cached in Firestore permanently.

    Returns a list of strings like:
        ["**What happened:** UC Davis announced X.", "**Why it matters:** ..."]
    Returns an empty list on failure.
    """
    if not paragraphs:
        return []

    cache_key = f"tldr_{title}"
    cached = self._tldr_cache.get(cache_key)
    if cached is not None:
        import json
        try:
            return json.loads(cached)
        except Exception:
            return []

    # Use only the first 4 paragraphs — plenty for a TLDR, keeps cost low
    excerpt = "\n\n".join(paragraphs[:4])

    system_prompt = (
        "You are a concise news summarizer for a UC Davis campus app. "
        "Given a news article, produce exactly 3 to 5 TLDR bullet points. "
        "Each bullet must follow this exact format: **Label:** One short sentence. "
        "The label should be 1–3 words (e.g. 'What happened', 'Why it matters', 'Key detail', 'Who's involved', 'What's next'). "
        "The sentence must be under 15 words. "
        "Return ONLY the bullet points, one per line, starting with **. No intro, no extra text."
    )

    user_prompt = f"Article: {title}\n\n{excerpt}"

    try:
        client = self._get_client()
        message = client.messages.create(
            model="claude-haiku-4-5-20251001",   # cheapest — simple extraction task
            max_tokens=180,                        # 5 bullets × ~36 tokens max
            system=system_prompt,
            messages=[{"role": "user", "content": user_prompt}]
        )

        raw = message.content[0].text.strip()
        lines = [l.strip() for l in raw.splitlines() if l.strip() and l.strip().startswith("**")]

        if not lines:
            return []

        import json
        self._tldr_cache.set(cache_key, json.dumps(lines))
        return lines

    except Exception:
        return []
```

**Add the cache** at the bottom of `claude_service.py` where the singleton is set up:

```python
claude_service = ClaudeService()
claude_service._bullet_cache = SummaryCache(max_size=500)
claude_service._location_cache = SummaryCache(max_size=500)
claude_service._web_location_cache = SummaryCache(max_size=500)
claude_service._tldr_cache = SummaryCache(max_size=1000)   # ← add this
```

---

### 2. `api/articles.py` — Generate TLDR on Cache Miss

In `get_article_content()`, after `scrape_article()` succeeds and before `article_content_repository.save_content()`, generate and attach the TLDR:

```python
# Cache miss — scrape the article
content = scrape_article(url)
if content is None:
    return jsonify({"success": False, "error": "Failed to scrape article content"}), 422

# ── Generate TLDR bullets (once, at scrape time) ──────────────────────────────
tldr = claude_service.generate_article_tldr(
    title=content.get("title", ""),
    paragraphs=content.get("bodyParagraphs", [])
)
content["tldrBullets"] = tldr   # empty list [] if generation failed — that's fine
# ─────────────────────────────────────────────────────────────────────────────

article_content_repository.save_content(content)
```

The TLDR is now stored in Firestore as part of the article document. Future requests hit the cache and get it for free.

Also make sure the cached response path returns `tldrBullets`. In the cache-hit branch, `cached_content` already has all stored fields, so it will be returned automatically — no change needed there.

---

### 3. `article_content_repository.py` — No Schema Change Needed

`tldrBullets` is just another field in the Firestore document dict. Since `save_content()` stores the whole dict and `get_content()` returns the whole dict, it flows through automatically. No code changes required.

However, verify that `get_content()` doesn't whitelist fields explicitly. If it does, add `"tldrBullets"` to the returned fields.

---

## iOS Changes

### 4. `ArticleContent.swift` — Add `tldrBullets`

```swift
struct ArticleContent {
    let title: String
    let author: String
    let authorEmail: String?
    let publishDate: Date
    let category: String
    let thumbnailURL: URL?
    let bodyParagraphs: [String]
    let articleURL: URL
    let tldrBullets: [String]       // ← add this; empty array = no TLDR shown
}
```

---

### 5. `NewsService.swift` — Decode `tldrBullets`

Find where `ArticleContent` is constructed from the API response JSON. Add `tldrBullets` decoding:

```swift
let tldrBullets = json["tldrBullets"] as? [String] ?? []

return ArticleContent(
    title: ...,
    // ... existing fields ...
    tldrBullets: tldrBullets
)
```

---

### 6. `ArticleDetailView.swift` — Render the TLDR Card

#### New `ArticleTLDRCard` view

Add this as a private struct inside `ArticleDetailView.swift`:

```swift
private struct ArticleTLDRCard: View {
    let bullets: [String]
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                Text("TLDR")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
            }

            // Bullets
            VStack(alignment: .leading, spacing: 7) {
                ForEach(bullets, id: \.self) { bullet in
                    ArticleTLDRBullet(raw: bullet, colorScheme: colorScheme)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark
                    ? Color(hex: "#1a2033")
                    : Color(hex: "#f8fafc"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            colorScheme == .dark
                                ? Color.ucdGold.opacity(0.2)
                                : Color.ucdBlue.opacity(0.15),
                            lineWidth: 1
                        )
                )
        )
    }
}
```

#### New `ArticleTLDRBullet` view

Each bullet from Claude looks like `**What happened:** UC Davis announced X.`
Parse the bold label and body inline:

```swift
private struct ArticleTLDRBullet: View {
    let raw: String
    let colorScheme: ColorScheme

    /// Splits "**Label:** Body" into (label, body). Falls back to (nil, raw).
    private var parsed: (label: String?, body: String) {
        // Match **...**: pattern
        guard raw.hasPrefix("**"),
              let closeRange = raw.range(of: ":**"),
              let openEnd = raw.range(of: "**")
        else {
            return (nil, raw)
        }
        let label = String(raw[raw.index(raw.startIndex, offsetBy: 2)..<closeRange.lowerBound])
        let body  = String(raw[closeRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        return (label, body)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Bullet dot
            Circle()
                .fill(colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                .frame(width: 5, height: 5)
                .padding(.top, 6)

            // Text
            Group {
                if let label = parsed.label {
                    Text(label).fontWeight(.semibold)
                    + Text(": ").fontWeight(.semibold)
                    + Text(parsed.body)
                } else {
                    Text(parsed.body)
                }
            }
            .font(.system(size: 13))
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.88) : Color(hex: "#1e293b"))
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
```

#### Wire it into `ArticleReadingView`

In `ArticleReadingView`, insert `ArticleTLDRCard` **below the title/byline block and above the first body paragraph**. Only show it when there are bullets:

```swift
// Below author / date line, above body paragraphs:
if !content.tldrBullets.isEmpty {
    ArticleTLDRCard(bullets: content.tldrBullets, colorScheme: colorScheme)
        .padding(.top, 12)
        .padding(.bottom, 4)
}
```

---

## Acceptance Criteria

- [ ] Articles that have been scraped before the update do **not** show a TLDR (no `tldrBullets` in their Firestore doc) — the card is simply absent, no crash.
- [ ] The first time an article is scraped after the update, `tldrBullets` is generated and stored in Firestore.
- [ ] Subsequent opens of the same article serve TLDR from the Firestore cache — no Claude call.
- [ ] The TLDR card shows 3–5 bullets with a bold label and short sentence each.
- [ ] If `generate_article_tldr()` fails (network error, Claude timeout, etc.), `tldrBullets` is stored as `[]` and the card is simply not shown — no error state.
- [ ] The card renders correctly in both light and dark mode.
- [ ] The TLDR appears above the article body, below the title/byline.
- [ ] `claude-haiku-4-5-20251001` is used — not Sonnet.
- [ ] Only the first 4 paragraphs are sent to Claude, not the full body.

---

## Notes for the Implementer

- `max_tokens=180` is tight but intentional — 5 bullets at ~36 tokens each. If Claude occasionally truncates the last bullet, that's acceptable. Raising to 220 is fine if truncation is a real problem.
- The `tldrBullets` field on legacy Firestore documents will simply be absent. `json["tldrBullets"] as? [String] ?? []` handles this cleanly — the card just doesn't render.
- Don't trigger a re-scrape of old articles to backfill TLDRs. New opens will naturally populate the cache over time as users read articles.
- The `ArticleTLDRBullet` parser handles the `**Label:** Body` format. If Claude ever returns a plain bullet without a label (just a sentence), `parsed.label` is `nil` and it renders gracefully as a plain bullet.
