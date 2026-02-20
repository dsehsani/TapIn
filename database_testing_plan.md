# Database Testing Plan: GCS Backend Infrastructure

## Goals

Verify that the new GCS-backed storage layer behaves correctly across the full
range of normal operation, boundary conditions, and failure modes. Tests should
catch regressions if the GCS client, repositories, scraper, image mirror, or API
endpoints change.

---

## Testing Stack

| Tool | Purpose |
|---|---|
| `pytest` | Test runner |
| `unittest.mock` / `pytest-mock` | Mock GCS client, HTTP calls, Claude API |
| `responses` | Mock `requests` HTTP calls in scraper + image mirror |
| `flask.testing.FlaskClient` | Black-box API endpoint tests |
| `freezegun` | Freeze `datetime.now()` for staleness TTL tests |
| `pytest-cov` | Coverage report (target ≥ 80% on new files) |

**Install test dependencies:**
```bash
pip install pytest pytest-mock responses freezegun pytest-cov
```

**Run all tests:**
```bash
pytest tapin-backend/tests/ -v --cov=tapin-backend --cov-report=term-missing
```

---

## Test Directory Structure

```
tapin-backend/
└── tests/
    ├── conftest.py                      # Shared fixtures: Flask test client, mock GCS bucket
    ├── unit/
    │   ├── test_gcs_client.py
    │   ├── test_article_repository.py
    │   ├── test_event_repository.py
    │   ├── test_article_content_repository.py
    │   ├── test_aggie_article_scraper.py
    │   └── test_image_mirror_service.py
    ├── service/
    │   └── test_event_processor_service.py
    └── api/
        ├── test_articles_api.py
        └── test_events_api.py
```

---

## Shared Fixtures (`conftest.py`)

```python
import pytest
from unittest.mock import MagicMock, patch
from app import create_app

@pytest.fixture
def app():
    app = create_app()
    app.config["TESTING"] = True
    return app

@pytest.fixture
def client(app):
    return app.test_client()

@pytest.fixture
def mock_bucket(monkeypatch):
    """
    Replaces the real GCS bucket with an in-memory dict-backed mock.
    Blobs expose .upload_from_string(), .download_as_text(), .exists(),
    .reload(), .make_public(), .patch(), .public_url, and .updated.
    """
    store = {}  # path → {"data": str, "content_type": str, "updated": datetime}

    class MockBlob:
        def __init__(self, path):
            self.path = path
            self.cache_control = None
            self.public_url = f"https://storage.googleapis.com/tapin-content/{path}"
            self.updated = None

        def exists(self):
            return self.path in store

        def upload_from_string(self, data, content_type="application/json"):
            from datetime import datetime, timezone
            store[self.path] = {"data": data, "content_type": content_type,
                                "updated": datetime.now(tz=timezone.utc)}
            self.updated = store[self.path]["updated"]

        def download_as_text(self):
            if self.path not in store:
                raise Exception("Not found")
            return store[self.path]["data"]

        def reload(self):
            if self.path in store:
                self.updated = store[self.path]["updated"]

        def make_public(self):
            pass

        def patch(self):
            pass

    class MockBucket:
        def blob(self, path):
            b = MockBlob(path)
            if path in store:
                b.updated = store[path]["updated"]
            return b
        def reload(self):
            pass

    mock = MockBucket()
    monkeypatch.setattr("services.gcs_client._bucket", mock)
    monkeypatch.setattr("services.gcs_client._gcs_client", MagicMock())
    return mock, store
```

---

## 1. Unit Tests: `services/gcs_client.py`

### `test_gcs_client.py`

#### write_json / read_json
```
test_write_and_read_json_round_trip
    Write a dict → read it back → assert equal.

test_read_json_nonexistent_path_returns_none
    read_json("does/not/exist.json") → None (no exception raised).

test_write_json_sets_cache_control_header
    After write_json(path, data, cache_control="public, max-age=300"),
    assert blob.cache_control == "public, max-age=300".

test_write_json_handles_non_serializable_values_via_default_str
    Write dict containing a datetime object.
    Assert no TypeError; value is stored as a string.

test_read_json_returns_none_on_download_error
    Force blob.download_as_text() to raise an exception.
    Assert read_json() returns None (no exception propagated).

test_write_json_stores_valid_json
    After write, parse the raw stored string with json.loads().
    Assert it round-trips correctly.
```

#### file_age_seconds
```
test_file_age_seconds_returns_none_for_missing_file
    file_age_seconds("missing.json") → None.

test_file_age_seconds_returns_positive_float_for_existing_file
    Write a file, freeze time 45 seconds later.
    Assert file_age_seconds() ≈ 45 (within 1s tolerance).

test_file_age_seconds_returns_none_on_blob_error
    Force blob.reload() to raise. Assert returns None.
```

#### upload_image
```
test_upload_image_returns_public_url
    Call upload_image("images/articles/abc.jpg", b"...", "image/jpeg").
    Assert return value is a non-empty URL string.

test_upload_image_calls_make_public
    Assert blob.make_public() was called.
```

#### is_gcs_connected
```
test_is_gcs_connected_returns_true_when_bucket_reachable
    bucket.reload() succeeds → True.

test_is_gcs_connected_returns_false_when_bucket_reload_raises
    Force bucket.reload() to raise. → False (no exception).
```

---

## 2. Unit Tests: `repositories/article_repository.py`

### `test_article_repository.py`

#### save_articles / get_articles
```
test_save_and_get_articles_round_trip
    Save 5 article dicts for category "sports".
    get_articles("sports") → same 5 dicts.

test_get_articles_returns_empty_list_when_no_file
    GCS has no file for "column".
    get_articles("column") → [].

test_get_articles_returns_empty_list_on_gcs_error
    Force read_json to raise. → [] (no exception propagated).

test_save_articles_includes_correct_metadata
    Save articles; read raw JSON from mock store.
    Assert "category", "count", "cached_at" fields are present and correct.

test_save_articles_empty_list
    save_articles("all", []) — no exception.
    get_articles("all") → [].
```

#### is_stale
```
test_is_stale_returns_true_when_file_missing
    No GCS file → is_stale("all") is True.

test_is_stale_returns_false_when_file_is_fresh
    Save articles. Immediately check is_stale() with 1800s TTL → False.

test_is_stale_returns_true_when_file_older_than_ttl
    Save articles. Freeze time +31 minutes. is_stale(ttl_seconds=1800) → True.

test_is_stale_returns_false_at_exactly_ttl_boundary
    Save articles. Freeze time at exactly 1800s. → False (< not <=).

test_is_stale_returns_true_on_file_age_error
    Force file_age_seconds to raise. → True (fail-open to force refresh).
```

#### count
```
test_count_returns_correct_number
    Save 7 articles; count("sports") → 7.

test_count_returns_zero_when_file_missing
    count("missing-category") → 0.

test_count_returns_zero_on_error
    Force read_json to raise. → 0.
```

---

## 3. Unit Tests: `repositories/event_repository.py`

### `test_event_repository.py`

#### save_all_events / get_all_events
```
test_save_and_get_events_round_trip
    Save 3 event dicts. get_all_events() → same 3 dicts (any order).

test_get_all_events_returns_empty_list_cold_start
    No GCS file exists. get_all_events() → [].

test_get_all_events_sorts_by_start_date_ascending
    Save events with startDates: "2026-03-10", "2026-03-05", "2026-03-08".
    Assert returned list is ordered oldest → newest.

test_get_all_events_sorts_correctly_with_iso8601_timestamps
    Use full ISO 8601 strings with time components.
    Assert sort is chronologically correct, not lexicographic.

test_save_all_events_writes_correct_metadata
    Save events; read raw JSON.
    Assert "refreshed_at" and "count" fields present and correct.

test_save_all_events_empty_list
    save_all_events([]) — no exception. get_all_events() → [].

test_save_all_events_overwrites_previous_data
    Save 5 events. Save 2 different events. get_all_events() → 2 events only.

test_get_all_events_returns_empty_on_gcs_error
    Force read_json to raise. → [] (no exception propagated).
```

#### count
```
test_count_returns_correct_number
    Save 4 events. count() → 4.

test_count_returns_zero_when_empty
    No file. count() → 0.
```

---

## 4. Unit Tests: `repositories/article_content_repository.py`

### `test_article_content_repository.py`

```
test_save_and_get_article_content_round_trip
    Save content dict for "abc123".
    get_article_content("abc123") → same dict (plus scrapedAt field).

test_get_article_content_returns_none_when_missing
    get_article_content("unknown-id") → None.

test_save_article_content_injects_scraped_at_timestamp
    Save content without "scrapedAt".
    Read back and assert "scrapedAt" is present and is a valid ISO 8601 string.

test_save_article_content_uses_long_cache_control
    Capture the cache_control passed to write_json.
    Assert it is "public, max-age=86400" (24 hours — immutable article).

test_get_article_content_returns_none_on_gcs_error
    Force read_json to raise. → None (no exception propagated).
```

---

## 5. Unit Tests: `services/aggie_article_scraper.py`

### `test_aggie_article_scraper.py`

All HTML tests pass raw HTML strings directly to `_parse_html()` or `_extract_*`
helpers without making network calls. `scrape_article()` is tested with
`responses` library to mock HTTP.

#### Title extraction
```
test_title_from_post_title_h1
    HTML: <h1 class="post-title">My Title</h1>
    → title == "My Title"

test_title_falls_back_to_article_h1
    No .post-title; HTML: <article><h1>Article Title</h1></article>
    → title == "Article Title"

test_title_falls_back_to_entry_title
    HTML: <h1 class="entry-title">Entry Title</h1>
    → title == "Entry Title"

test_title_falls_back_to_fallback_dict
    No h1 elements in HTML.
    fallback = {"title": "Fallback Title"}
    → title == "Fallback Title"

test_title_empty_string_when_no_fallback_and_no_h1
    No h1, fallback["title"] = "".
    → title == ""
```

#### Author / byline extraction
```
test_author_extracted_from_by_byline_in_first_paragraph
    <p>By Jane Doe — science@theaggie.org</p>
    → author == "Jane Doe", authorEmail == "science@theaggie.org"

test_author_extracted_from_byline_without_email
    <p>By John Smith</p>
    → author == "John Smith", authorEmail == None

test_byline_scanning_stops_at_paragraph_7
    Paragraphs 1–6 have no byline; paragraph 7: "By Hidden Author".
    → byline NOT extracted (only first 6 scanned); falls back to next selector.

test_author_falls_back_to_author_name_class
    No byline paragraph; HTML: <span class="author-name">Staff Writer</span>
    → author == "Staff Writer"

test_author_falls_back_to_entry_author_class
    → author from .entry-author

test_author_falls_back_to_byline_anchor
    → author from .byline a

test_author_falls_back_to_fallback_dict_value
    No selectors match. fallback["author"] = "The Aggie"
    → author == "The Aggie"

test_author_line_case_insensitive_by_prefix
    <p>BY JANE DOE — ops@theaggie.org</p>
    → author == "JANE DOE" (prefix stripped case-insensitively)

test_author_line_with_em_dash_variants
    Test with both "—" (em dash) and " — " (spaced).

test_parse_author_line_name_only
    "By Alice" → ("Alice", None)

test_parse_author_line_name_and_email
    "By Alice — a@theaggie.org" → ("Alice", "a@theaggie.org")

test_parse_author_line_empty_string_returns_fallback
    "" → (fallback, None)
```

#### Category extraction
```
test_category_from_category_tag_anchor
    <a rel="category tag">Campus</a>
    → category == "Campus"

test_category_falls_back_to_cat_links
    <div class="cat-links"><a>Sports</a></div>
    → category == "Sports"

test_category_falls_back_to_fallback_dict
    No selectors match.
    → fallback["category"]
```

#### Thumbnail extraction
```
test_thumbnail_from_post_thumbnail_img
    <div class="post-thumbnail"><img src="https://example.com/img.jpg"></div>
    → thumbnailURL == "https://example.com/img.jpg"

test_thumbnail_falls_back_to_wp_post_image
    img.wp-post-image → thumbnailURL set correctly.

test_thumbnail_falls_back_to_article_img
    <article><img src="..."></article>

test_thumbnail_falls_back_to_fallback_image_url
    No img elements. fallback["imageURL"] = "https://fallback.jpg"
    → thumbnailURL == "https://fallback.jpg"

test_thumbnail_none_when_no_image_anywhere
    No img, no fallback → thumbnailURL == None
```

#### Body paragraph extraction
```
test_body_paragraphs_from_entry_content
    <div class="entry-content"><p>Real paragraph text longer than 20.</p></div>
    → bodyParagraphs == ["Real paragraph text longer than 20."]

test_body_paragraphs_from_post_content
    .post-content selector used when .entry-content absent.

test_body_paragraphs_falls_back_to_article_element
    No content selectors; <article><p>Text here that is long enough.</p></article>

test_body_paragraphs_falls_back_to_body
    No article or content selectors; paragraphs from <body>.

test_short_paragraphs_filtered_out
    <p>Too short</p> (≤20 chars) → not included.

test_byline_paragraph_filtered_out
    <p>By Jane Doe — email</p> → excluded (starts with "by ").

test_noise_paragraphs_filtered_out
    "Follow us on Instagram" → excluded.
    "Subscribe to our newsletter" → excluded.
    "Support the Aggie" → excluded.
    "Written by the Editorial Board" → excluded.
    "© 2026 The California Aggie" → excluded.

test_noise_pattern_match_is_case_insensitive
    "FOLLOW US ON Twitter" → excluded.

test_multiple_valid_paragraphs_all_included
    3 valid paragraphs → all 3 returned in order.

test_returns_none_when_no_valid_paragraphs
    All paragraphs are noise or too short.
    scrape_article() returns None (not an empty-paragraph dict).
```

#### Bold preservation
```
test_strong_tags_wrapped_in_double_asterisks
    <p>Normal <strong>Bold</strong> text</p>
    → "Normal **Bold** text"

test_b_tags_wrapped_in_double_asterisks
    <p>Normal <b>Bold</b> text</p>
    → "Normal **Bold** text"

test_bold_markers_tightened_no_extra_spaces
    <p><strong> Bold with spaces </strong></p>
    → "**Bold with spaces**" (no "** Bold **")

test_nested_strong_tags_handled
    <p><strong>A</strong> and <strong>B</strong></p>
    → "**A** and **B**"
```

#### HTML entity decoding
```
test_entities_decoded_in_paragraphs
    "Fish &amp; Chips" → "Fish & Chips"
    "A &lt; B" → "A < B"
    "Say &quot;hello&quot;" → 'Say "hello"'
    "non&#8209;breaking" → "non‑breaking" (numeric entity)
    "&nbsp;" → " "
    "&#8220;quote&#8221;" → "\u201Cquote\u201D"
    "&#8216;quote&#8217;" → "\u2018quote\u2019"
    "it&#8230;" → "it…"
```

#### Network errors (via `responses` mock)
```
test_scrape_article_returns_none_on_connection_error
    requests.get raises ConnectionError → None returned.

test_scrape_article_returns_none_on_timeout
    requests.get raises Timeout → None returned.

test_scrape_article_returns_none_on_404
    Mock returns HTTP 404 → None returned.

test_scrape_article_returns_none_on_500
    Mock returns HTTP 500 → None returned.

test_scrape_article_returns_none_on_non_utf8_body
    Response has undecodable bytes → None returned gracefully.
```

---

## 6. Unit Tests: `services/image_mirror_service.py`

### `test_image_mirror_service.py`

```
test_mirror_article_image_success
    Mock HTTP GET returns 200 with JPEG bytes.
    Mock GCS upload returns public URL.
    → returns GCS public URL, not original URL.

test_mirror_event_image_success
    Same as above for event path prefix "images/events/".

test_mirror_returns_none_for_none_source_url
    mirror_article_image("id", None) → None.

test_mirror_returns_none_for_empty_string_source_url
    mirror_article_image("id", "") → None.

test_mirror_falls_back_to_original_url_on_http_404
    HTTP 404 → returns original source_url unchanged.

test_mirror_falls_back_to_original_url_on_connection_error
    requests.get raises ConnectionError → returns source_url.

test_mirror_falls_back_to_original_url_on_timeout
    requests.get raises Timeout → returns source_url.

test_mirror_falls_back_to_original_url_on_gcs_upload_failure
    HTTP 200, but upload_image raises → returns source_url.

test_content_type_jpeg_uses_jpg_extension
    Content-Type: image/jpeg → GCS path ends in ".jpg".

test_content_type_png_uses_png_extension
    Content-Type: image/png → GCS path ends in ".png".

test_content_type_webp_uses_webp_extension
    Content-Type: image/webp → GCS path ends in ".webp".

test_content_type_unknown_defaults_to_jpg
    Content-Type: application/octet-stream → defaults to ".jpg".

test_content_type_with_charset_parameter_parsed_correctly
    Content-Type: image/jpeg; charset=utf-8 → ".jpg" (semicolon stripped).

test_gcs_path_uses_article_id
    mirror_article_image("article-abc123", url).
    Captured GCS path contains "article-abc123".

test_gcs_path_uses_event_id
    mirror_event_image("event-xyz789", url).
    Captured GCS path contains "event-xyz789".
```

---

## 7. Service Tests: `services/event_processor_service.py`

### `test_event_processor_service.py`

All tests mock `aggie_life_service.fetch_events`, `claude_service`, and
`event_repository` to avoid network calls.

#### Idempotency / AI content reuse
```
test_existing_event_ai_content_reused
    existing_map has event with id "e1", aiSummary="summary", aiBulletPoints=["•"].
    Fresh fetch returns same event id "e1".
    Assert claude_service.summarize_event_internal NOT called.
    Assert result["skipped"] == 1.

test_new_event_gets_ai_generated_content
    No existing events. Fresh fetch returns event "e2".
    Assert claude_service.summarize_event_internal called once.
    Assert result["processed"] == 1.

test_event_without_ai_summary_not_treated_as_existing
    existing_map has event "e3" but aiSummary is None / missing.
    Fresh fetch returns "e3" again.
    Assert claude_service called (re-processes because AI content incomplete).
```

#### Past event filtering
```
test_past_events_not_included_in_output
    Fresh event has startDate 1 hour ago.
    Assert event NOT in saved list.

test_future_events_included
    Fresh event has startDate 24 hours from now.
    Assert event IS in saved list.

test_event_at_exact_now_is_excluded
    startDate == datetime.now() — slightly in the past after comparison.

test_unparseable_start_date_event_is_kept
    startDate = "not-a-date" → event kept defensively.
```

#### removed_past count
```
test_removed_past_counts_events_absent_from_fresh_feed
    5 events in GCS, fresh feed returns 3 of them.
    result["removed_past"] == 2.

test_removed_past_is_zero_when_all_events_still_active
    All 4 events in GCS are also in fresh feed.
    result["removed_past"] == 0.
```

#### Concurrency / lock
```
test_concurrent_refresh_second_call_returns_skip
    Start refresh in thread 1 (hold lock artificially).
    Call refresh_events() from thread 2.
    → returns {"skipped_reason": "refresh_in_progress"}.

test_is_refreshing_true_during_refresh
    During a long-running refresh, is_refreshing() returns True.

test_is_refreshing_false_after_refresh_completes
    After refresh finishes, is_refreshing() returns False.
```

#### Error handling
```
test_aggie_life_fetch_failure_returns_error_dict
    aggie_life_service.fetch_events raises.
    → refresh_events() returns dict with "error" key, no exception raised.

test_claude_api_failure_event_still_saved_without_ai
    Claude raises for one event.
    Assert event is still included in final_events (without aiSummary).
    result["errors"] == 1.

test_gcs_save_failure_propagates
    event_repository.save_all_events raises.
    → refresh_events() propagates the exception (data not silently lost).

test_empty_aggie_life_feed_saves_empty_list
    fetch_events returns [].
    save_all_events called with [].
    result == {processed:0, skipped:0, removed_past:N, errors:0, total_fetched:0}
```

#### Image mirroring
```
test_new_event_image_is_mirrored
    New event has imageURL "https://original.jpg".
    Assert mirror_event_image called; event["imageURL"] updated to GCS URL.

test_mirror_failure_event_still_saved_with_original_url
    mirror_event_image returns original URL (fallback behavior).
    Assert event saved with original URL, no exception.

test_existing_event_image_not_re-mirrored
    Skipped (reused) events skip the mirror call.
```

#### Output format
```
test_result_dict_contains_all_expected_keys
    result has: processed, skipped, removed_past, errors, total_fetched, completed_at.

test_completed_at_is_valid_iso8601_string
    Parse result["completed_at"] with datetime.fromisoformat() — no error.
```

---

## 8. API Tests: `api/articles.py`

### `test_articles_api.py`

All tests use `FlaskClient` and mock GCS/RSS/scraper at the service layer.

#### GET /api/articles
```
test_get_articles_cache_hit_returns_200
    article_repository.is_stale returns False.
    article_repository.get_articles returns 3 articles.
    Response: 200, success=True, count=3, cached=True.

test_get_articles_cache_miss_fetches_from_rss
    is_stale returns True.
    fetch_articles mocked to return 5 articles.
    save_articles called once.
    Response: 200, success=True, count=5, cached=False.

test_get_articles_invalid_category_defaults_to_all
    GET /api/articles?category=notreal
    Assert is_stale("all") was called, not is_stale("notreal").

test_get_articles_missing_category_param_defaults_to_all
    GET /api/articles (no query param)
    Assert category "all" used.

test_get_articles_case_insensitive_category
    GET /api/articles?category=SPORTS
    Assert is_stale("sports") called.

test_get_articles_rss_fetch_failure_returns_500
    is_stale True, fetch_articles raises.
    Response: 500, success=False, error present.

test_get_articles_images_mirrored_on_cache_miss
    Cache miss. fetch_articles returns articles with imageURL.
    Assert mirror_article_image called for each article.

test_get_articles_images_not_mirrored_on_cache_hit
    Cache hit. Assert mirror_article_image NOT called.

test_get_articles_all_valid_categories_accepted
    For each slug in CATEGORY_FEEDS, assert 200 returned (not defaulted).
```

#### GET /api/articles/<id>/content
```
test_get_content_cache_hit_returns_200_with_cached_true
    article_content_repository.get_article_content returns a dict.
    Response: 200, cached=True, content present.
    Assert scrape_article NOT called.

test_get_content_cache_miss_with_url_triggers_scrape
    get_article_content returns None.
    scrape_article mocked to return content dict.
    save_article_content called.
    Response: 200, cached=False, content present.

test_get_content_cache_miss_without_url_returns_400
    get_article_content returns None.
    GET /api/articles/abc123/content  (no ?url param)
    Response: 400, error message mentions "url".

test_get_content_scrape_failure_returns_422
    get_article_content returns None.
    scrape_article returns None.
    Response: 422, success=False.

test_get_content_gcs_save_failure_still_returns_scraped_content
    Scrape succeeds. save_article_content raises.
    Response: 200, content returned (not a 500).

test_get_content_article_id_too_long_returns_400
    GET /api/articles/{"a"*129}/content
    Response: 400.

test_get_content_empty_article_id_returns_404
    GET /api/articles//content → Flask 404.

test_get_content_url_with_query_params_passed_to_scraper
    ?url=https://theaggie.org/article?foo=bar
    Assert scrape_article receives the full URL including query params.
```

#### POST /api/articles/refresh
```
test_refresh_no_secret_set_allows_unauthenticated
    REFRESH_SECRET env not set. POST with no header → 200.

test_refresh_valid_secret_succeeds
    REFRESH_SECRET="abc". Header X-Refresh-Secret: abc → 200.

test_refresh_wrong_secret_returns_401
    REFRESH_SECRET="abc". Header X-Refresh-Secret: wrong → 401.

test_refresh_missing_secret_header_returns_401
    REFRESH_SECRET="abc". No header → 401.

test_refresh_all_categories_when_no_body
    No JSON body. Assert fetch_articles called once per valid category.

test_refresh_specific_category_in_body
    Body: {"category": "sports"}.
    Assert fetch_articles called only with "sports".

test_refresh_invalid_category_in_body_refreshes_all
    Body: {"category": "invalid"}.
    Assert all categories refreshed.

test_refresh_one_category_failure_others_succeed
    fetch_articles raises for "campus" but succeeds for others.
    Response: 200. Result dict has "campus": "error: ...", others have counts.

test_refresh_images_mirrored_during_refresh
    Assert mirror_article_image called for each article returned by fetch_articles.
```

#### GET /api/articles/health
```
test_health_gcs_connected_returns_healthy
    is_gcs_connected returns True.
    Response: 200, status="healthy", gcs="connected", storage="gcs".

test_health_gcs_disconnected_still_returns_200
    is_gcs_connected returns False.
    Response: 200, gcs="disconnected", status still "healthy" or "degraded".

test_health_includes_cached_counts_for_all_campus_sports
    is_gcs_connected True.
    Response includes cached_counts with keys "all", "campus", "sports".

test_health_exception_returns_degraded
    is_gcs_connected raises.
    Response: 200, status="degraded", error present.
```

---

## 9. API Tests: `api/events.py`

### `test_events_api.py`

#### GET /api/events
```
test_get_events_returns_events_from_gcs
    get_events() returns 3 events.
    Response: 200, success=True, count=3, refreshing=False.

test_get_events_cold_start_triggers_background_refresh
    get_events() returns [].
    is_refreshing returns False before, True after.
    Response: 200, events=[], refreshing=True.
    Assert refresh_events_background was called.

test_get_events_cold_start_does_not_double_refresh
    get_events() returns []. is_refreshing already True.
    Assert refresh_events_background NOT called again.

test_get_events_gcs_failure_returns_500
    get_events() raises.
    Response: 500, success=False.

test_get_events_response_contains_all_fields
    Response includes: success, events, count, refreshing.
```

#### POST /api/events/refresh
```
test_events_refresh_no_secret_succeeds
    REFRESH_SECRET not set. POST /api/events/refresh → 200.

test_events_refresh_valid_secret_succeeds
    Correct header → 200, result dict present.

test_events_refresh_wrong_secret_returns_401
    Wrong header → 401.

test_events_refresh_result_has_all_summary_keys
    Response result contains: processed, skipped, removed_past, errors,
    total_fetched, completed_at.

test_events_refresh_exception_returns_500
    refresh_events() raises.
    Response: 500, success=False.
```

#### GET /api/events/health
```
test_events_health_gcs_connected
    Response: 200, status="healthy", gcs="connected", storage="gcs",
    event_count present, refreshing=False.

test_events_health_gcs_disconnected
    is_gcs_connected False.
    event_count == 0 (count not fetched when disconnected).
    Response: 200, gcs="disconnected".

test_events_health_exception_returns_degraded
    is_gcs_connected raises.
    Response: 200, status="degraded".
```

---

## 10. Integration Tests (No Mocks)

These tests run against a real GCS bucket in a dedicated test project.
Gate them behind a pytest mark: `@pytest.mark.integration`.
Run only in CI with a service account that has `roles/storage.objectAdmin`.

```bash
pytest -m integration --gcs-bucket=tapin-test-bucket
```

```
test_integration_article_list_round_trip
    Write articles JSON to real GCS bucket.
    Read it back via article_repository.
    Assert data integrity.
    Clean up object after test.

test_integration_events_round_trip
    Write events JSON. Read back. Assert sorted order preserved.
    Clean up.

test_integration_article_content_round_trip
    Write content JSON. Read back. Assert scrapedAt field injected.
    Clean up.

test_integration_file_age_seconds_accuracy
    Write file. Sleep 2 seconds. Assert file_age_seconds() ≥ 2.0.

test_integration_is_gcs_connected_true
    Real bucket accessible. → True.

test_integration_scrape_real_aggie_article
    Fetch and parse a known stable Aggie article URL.
    Assert bodyParagraphs is non-empty list of non-empty strings.
    Assert title is non-empty.
    (Skipped if no network access in CI.)
```

---

## 11. Edge Cases Reference

### Data integrity
| Scenario | Expected |
|---|---|
| Articles saved with `count` field wrong | `get_articles()` still returns the `articles` array (count from array, not metadata) |
| `events/current.json` has `events` key missing | `get_all_events()` returns `[]` |
| Article ID contains `/` or special chars | `_path()` builds valid GCS path; GCS accepts it |
| `startDate` field missing from event | Sort key defaults to `""`, event floats to top |
| `startDate` in wrong timezone | `datetime.fromisoformat` with `replace("Z", "+00:00")` handles UTC |
| `cached_at` field missing from article JSON | `is_stale()` uses file mod time, not `cached_at`; no regression |
| GCS bucket does not exist | `_get_bucket()` raises; caught and logged in all callers |

### Concurrency
| Scenario | Expected |
|---|---|
| Two simultaneous `POST /api/events/refresh` requests | Second returns `{skipped_reason: refresh_in_progress}` |
| Two simultaneous `GET /api/articles` on stale cache | Both may trigger fetch; second write wins but no data loss |
| `refresh_events_background()` called while foreground refresh running | `_refresh_lock.acquire(blocking=False)` rejects; no double-write |

### Category handling
| Input | Expected behavior |
|---|---|
| `category=ALL` | Normalized to `"all"` |
| `category=arts-culture` | Valid; uses hyphenated slug correctly |
| `category=` (empty string) | Defaults to `"all"` |
| `category=<script>` | Stripped/lowercased; falls through to `"all"` |
| Unknown slug | Falls back to `"all"` |

### Article content endpoint
| Scenario | Expected |
|---|---|
| `article_id` is 128 chars | Accepted |
| `article_id` is 129 chars | 400 response |
| `url` param points to non-Aggie domain | Scraper fetches it anyway; caller responsible for valid URL |
| `url` is malformed (no scheme) | `requests.get` raises; scraper returns None → 422 |
| Article has no body paragraphs | 422 response |
| Article content cached; `url` param present | GCS hit returned; scraper not called |

### Image mirroring
| Scenario | Expected |
|---|---|
| Source image is already a GCS URL | Re-mirrors unnecessarily but harmlessly |
| Source URL redirects (301/302) | `requests` follows redirect; upload succeeds |
| Image larger than 32 MB | Upload succeeds (GCS supports up to 5 TB); no size limit in code |
| `Content-Type` header absent | Defaults to `image/jpeg` / `.jpg` extension |

---

## 12. Test Data / Fixtures

### Minimal valid article dict
```python
SAMPLE_ARTICLE = {
    "id": "a" * 32,
    "title": "Test Article",
    "excerpt": "This is a test article excerpt.",
    "imageURL": "https://theaggie.org/img.jpg",
    "category": "campus",
    "publishDate": "2026-02-19T10:00:00Z",
    "author": "Jane Doe",
    "readTime": 3,
    "articleURL": "https://theaggie.org/2026/02/19/test-article/",
}
```

### Minimal valid event dict
```python
SAMPLE_EVENT = {
    "id": "b" * 36,  # UUID-shaped
    "title": "Test Event",
    "description": "A test campus event.",
    "startDate": "2026-02-25T18:00:00Z",
    "endDate": "2026-02-25T20:00:00Z",
    "location": "ARC",
    "isOfficial": True,
    "imageURL": None,
    "organizerName": "Campus Rec",
    "clubAcronym": None,
    "eventType": None,
    "tags": [],
    "eventURL": None,
    "aiSummary": "A fun test event at the ARC.",
    "aiBulletPoints": ["🏀 Basketball", "🎉 Fun", "📍 ARC"],
    "processedAt": "2026-02-19T12:00:00Z",
}
```

### Minimal valid article content dict
```python
SAMPLE_CONTENT = {
    "id": "c" * 32,
    "title": "Full Article",
    "author": "John Doe",
    "authorEmail": "jdoe@ucdavis.edu",
    "publishDate": "2026-02-18T09:00:00Z",
    "category": "sports",
    "thumbnailURL": "https://theaggie.org/thumb.jpg",
    "bodyParagraphs": [
        "First paragraph of the full article body.",
        "Second paragraph with **bold text** inside it.",
    ],
    "articleURL": "https://theaggie.org/2026/02/18/full-article/",
}
```

### Minimal WordPress HTML fixture
```python
SAMPLE_AGGIE_HTML = """
<html>
<body>
  <h1 class="post-title">Test Article Title</h1>
  <a rel="category tag">Campus</a>
  <div class="post-thumbnail"><img src="https://theaggie.org/thumb.jpg"></div>
  <div class="entry-content">
    <p>By Jane Doe — campus@theaggie.org</p>
    <p>This is the first paragraph of the article body with enough content.</p>
    <p>This is the second paragraph of the article body with enough content.</p>
    <p>Follow us on Instagram for more updates.</p>
  </div>
</body>
</html>
"""
```

---

## 13. Coverage Targets

| Module | Target |
|---|---|
| `services/gcs_client.py` | 90% |
| `repositories/article_repository.py` | 95% |
| `repositories/event_repository.py` | 95% |
| `repositories/article_content_repository.py` | 95% |
| `services/aggie_article_scraper.py` | 85% |
| `services/image_mirror_service.py` | 90% |
| `services/event_processor_service.py` | 85% |
| `api/articles.py` | 90% |
| `api/events.py` | 90% |

---

## 14. CI Integration

Add to the CI pipeline (GitHub Actions or Cloud Build):

```yaml
- name: Run unit tests
  run: |
    pip install -r requirements.txt pytest pytest-mock responses freezegun pytest-cov
    pytest tests/ -v -m "not integration" \
      --cov=. \
      --cov-report=term-missing \
      --cov-fail-under=85

- name: Run integration tests
  if: github.ref == 'refs/heads/main'
  env:
    GCS_BUCKET_NAME: tapin-test-bucket
    GOOGLE_APPLICATION_CREDENTIALS: ${{ secrets.GCP_SA_KEY_PATH }}
  run: |
    pytest tests/ -v -m integration
```
