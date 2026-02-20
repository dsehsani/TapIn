# Test Results — GCS Backend Infrastructure

**Date:** 2026-02-19
**Environment:** Python 3.14.2 / pytest 9.0.2 / Windows 11
**Suite:** `tests/` (unit + service + API layers, integration tests excluded)
**Final result:** ✅ 251 / 251 passed

---

## Summary

| Layer | File | Tests | Result |
|-------|------|-------|--------|
| API | `test_articles_api.py` | 36 | ✅ All passed |
| API | `test_events_api.py` | 24 | ✅ All passed |
| Service | `test_event_processor_service.py` | 30 | ✅ All passed |
| Unit | `test_aggie_article_scraper.py` | 59 | ✅ All passed |
| Unit | `test_article_content_repository.py` | 10 | ✅ All passed |
| Unit | `test_article_repository.py` | 23 | ✅ All passed |
| Unit | `test_event_repository.py` | 17 | ✅ All passed |
| Unit | `test_gcs_client.py` | 18 | ✅ All passed |
| Unit | `test_image_mirror_service.py` | 20 | ✅ All passed |
| **Total** | | **251** | **✅ 251 passed, 0 failed** |

---

## Issues Found and Fixed

Four bugs were caught during the initial run (first clean pass without `python-dotenv` installed had the API tests blocked entirely; after that was fixed, 4/251 failed). All 4 were fixed before the final green run.

### 1. `conftest.py` — MockBlob crashes on binary image data
**Test:** `TestUploadImage::test_returns_public_url_string`
**Root cause:** `MockBlob.upload_from_string` unconditionally called `.decode("utf-8")` on the stored data, which fails for binary content (e.g. JPEG magic bytes `\xff\xd8\xff`). JSON files happen to be valid UTF-8, so this was masked until the image upload test ran.
**Fix:** Store the data as-is (str or bytes) without forcing a decode.
**File:** `tests/conftest.py`

### 2. `test_articles_api.py` — `&` in URL param not percent-encoded
**Test:** `TestGetArticleContent::test_url_with_query_params_passed_to_scraper`
**Root cause:** The test built the request URL as `?url=https://theaggie.org/article?foo=bar&baz=qux` without encoding the value. Flask's test client (and any HTTP parser) treats the raw `&` as a query-string separator, so `baz=qux` was parsed as a second parameter rather than part of the `url` value.
**Fix:** Wrapped the URL value with `urllib.parse.quote(url_with_params, safe='')` before inserting it into the query string.
**File:** `tests/api/test_articles_api.py`

### 3. `aggie_article_scraper.py` — `&nbsp;` decoded by BeautifulSoup before entity replacement
**Tests:** `TestHtmlEntityDecoding::test_nbsp_entity`, `TestHtmlEntityDecoding::test_numeric_nbsp`
**Root cause:** `_extract_text_preserving_bold` replaces the literal strings `"&nbsp;"` and `"&#160;"`. However, BeautifulSoup's HTML parser has already decoded those entities to the Unicode non-breaking space character `\xa0` by the time `decode_contents()` is called. The replacement strings were therefore never found in the output.
**Fix:** Added `"\xa0": " "` to the entity replacement dict so the already-decoded form is also normalized to a regular space.
**File:** `services/aggie_article_scraper.py`

### 4. `test_aggie_article_scraper.py` — HTTP response missing charset causes encoding mismatch
**Test:** `TestScrapeArticle::test_successful_scrape_returns_dict`
**Root cause:** `responses_lib.add(..., content_type="text/html")` did not declare a charset. Per RFC 2616, `requests` defaults to ISO-8859-1 for `text/*` responses with no charset. The test HTML contained the em dash `—` (U+2014) encoded as UTF-8 bytes `\xe2\x80\x94`; decoding those bytes as ISO-8859-1 produced three Latin-1 characters instead of the single em dash, so `_parse_author_line`'s `"—" in cleaned` check never matched and the author was returned unstripped.
**Fix:** Changed `content_type="text/html"` to `content_type="text/html; charset=utf-8"` in the test, matching what real web servers send.
**File:** `tests/unit/test_aggie_article_scraper.py`

---

## Coverage Notes

Tests exercise the following behaviors across the GCS infrastructure:

**`gcs_client.py`**
- Round-trip JSON write/read with correct deserialization
- `Cache-Control` header set on every write
- `file_age_seconds` returns `None` for missing paths and on error
- `upload_image` stores binary data and calls `make_public`
- `is_gcs_connected` returns false (not raise) on bucket error

**`article_repository.py`**
- GCS path uses `articles/{category}.json`
- Staleness: fresh at 1799s, stale at exactly TTL (1800s) and beyond
- Falls back to empty list on missing file or read error

**`event_repository.py`**
- Atomic write to `events/current.json`
- Events sorted chronologically (not lexicographically) by `startDate`
- Overwrite replaces entire list (no append behavior)

**`article_content_repository.py`**
- `scrapedAt` timestamp injected automatically at write time
- Uses `max-age=86400` cache control (immutable article body)

**`aggie_article_scraper.py`**
- All 4 selector fallback chains (title, author, category, thumbnail)
- Byline scan limited to first 6 `<p>` elements
- All 5 noise phrase filters (case-insensitive, prefix and contains)
- Bold preservation (`<strong>`/`<b>` → `**markdown**`) with whitespace tightening
- All HTML entity decodings including `\xa0` (BS4-decoded `&nbsp;`)
- Network errors (404, 500, timeout, connection refused) → return `None`
- Returns original URL on any GCS failure (never raises)

**`image_mirror_service.py`**
- `mirror_article_image` → `images/articles/{id}.{ext}`
- `mirror_event_image` → `images/events/{id}.{ext}`
- `None`/empty URL short-circuits before any HTTP call
- Content-Type → extension mapping (jpeg, jpg, png, webp, gif, unknown)
- Charset suffix in Content-Type header stripped before lookup
- Returns original URL on HTTP errors, connection errors, GCS failures

**`event_processor_service.py`**
- Existing events with AI content reused (no Claude call)
- Events missing `aiSummary` or `aiBulletPoints` are reprocessed
- Past events filtered out; unparseable dates kept defensively
- `removed_past` count reflects events absent from the fresh feed
- Claude failure: event still saved, just without AI fields
- Thread-safety: concurrent `refresh_events()` call returns `{"skipped_reason": "refresh_in_progress"}`
- `is_refreshing` flag raised for the duration and cleared in `finally`

**API — `api/articles.py`**
- Cache hit returns 200 with `cached: true`, skips scraper and mirroring
- Cache miss with URL param → scrape → save → return
- Cache miss without URL param → 400
- Scrape failure → 422
- GCS save failure → still returns scraped content (200)
- `article_id` > 128 chars → 400
- Image mirroring on cache miss and refresh; skipped on cache hit
- `REFRESH_SECRET` auth guards the refresh endpoint

**API — `api/events.py`**
- Cold-start (empty GCS) triggers background refresh exactly once
- Already-refreshing flag blocks duplicate background jobs
- Health endpoint reports `storage: "gcs"` and live event count
- GCS disconnected: `event_count: 0`, `gcs: "disconnected"`, status 200

---

## Environment Notes

- **`google-cloud-storage`** is imported lazily inside `_get_bucket()` to avoid a `google.protobuf` C-extension crash under Python 3.14. Tests bypass this entirely by patching `services.gcs_client._bucket` directly via the `mock_bucket` fixture.
- All tests run in `~2.4 seconds` with no network or GCS access.
- Integration tests (requiring a real GCS bucket) are tagged `@pytest.mark.integration` and excluded from this run with `-m "not integration"`.
