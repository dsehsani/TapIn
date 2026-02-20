# Database Upgrade Plan: Firestore → Cloud Storage (GCS)

## Current Architecture

### What Firestore Stores Today

| Collection | Document ID | Contents | TTL |
|---|---|---|---|
| `cached_articles` | Category slug (e.g. `"all"`, `"sports"`) | Full array of articles for that category | 30 min (manual check) |
| `processed_events` | Deterministic UUID (hash of title + date) | One document per event, AI-enriched | Deleted when past |

### Data Flow (Current)
```
RSS / iCal
  → Backend (Cloud Run)
    → Parse + AI enrich (Claude)
      → Firestore (one doc per category / one doc per event)
        → iOS app via backend API endpoints
          → iOS disk cache (Library/Caches/TapIn/)
```

### Problems with the Current Setup

1. **Firestore document size cap (1 MB):** Articles are stored as one document per
   category containing a full array. As article count grows, this will hit the limit.

2. **No shared full-article caching:** Full article body (scraped HTML) is cached
   per-device only. Every new device re-scrapes The Aggie. No benefit from other
   users having already fetched the same article.

3. **Firestore pricing model is a poor fit:** Firestore charges per read/write
   operation. Article lists are read on every app launch. GCS charges by storage
   size + bandwidth, which is far cheaper for read-heavy, infrequently-updated blobs.

4. **No CDN integration:** Every request goes Cloud Run → Firestore → response.
   There is no edge caching; each user pays full latency.

5. **Event re-processing redundancy:** Events are stored individually in Firestore.
   Each query reads N documents (one per event). A single JSON file is simpler
   and cheaper to read atomically.

6. **Article images are not owned:** Image URLs point to The Aggie's servers.
   If they change, go down, or block hotlinking, images break app-wide.

---

## Proposed Architecture: Cloud Storage (GCS)

Replace Firestore with a GCS bucket as the primary data store for articles and
events. The backend is the only writer. The iOS app continues to hit the existing
backend endpoints (no client-side bucket access needed).

### Bucket Layout

```
gs://tapin-content/
├── articles/
│   ├── all.json           ← Full article list for "All" tab
│   ├── campus.json
│   ├── sports.json
│   ├── opinion.json
│   ├── features.json
│   ├── arts-culture.json
│   ├── science-tech.json
│   ├── editorial.json
│   └── column.json
│
├── article-content/
│   └── {article-id}.json  ← Full scraped body per article (SHA256 of URL)
│
├── events/
│   └── current.json       ← All current week's events in one file
│
└── images/
    ├── articles/
    │   └── {article-id}.jpg   ← Mirrored article thumbnails
    └── events/
        └── {event-id}.jpg     ← Mirrored event images
```

### File Schemas

**`articles/{category}.json`**
```json
{
  "category": "sports",
  "cached_at": "2026-02-19T12:00:00Z",
  "count": 25,
  "articles": [
    {
      "id": "abc123",
      "title": "...",
      "excerpt": "...",
      "imageURL": "https://storage.googleapis.com/tapin-content/images/articles/abc123.jpg",
      "category": "sports",
      "publishDate": "2026-02-18T09:00:00Z",
      "author": "Jane Doe",
      "readTime": 4,
      "articleURL": "https://theaggie.org/..."
    }
  ]
}
```

**`article-content/{id}.json`**
```json
{
  "id": "abc123",
  "title": "...",
  "author": "Jane Doe",
  "authorEmail": "jdoe@ucdavis.edu",
  "publishDate": "2026-02-18T09:00:00Z",
  "category": "sports",
  "thumbnailURL": "https://storage.googleapis.com/tapin-content/images/articles/abc123.jpg",
  "bodyParagraphs": ["Paragraph one...", "Paragraph two..."],
  "articleURL": "https://theaggie.org/...",
  "scrapedAt": "2026-02-19T11:30:00Z"
}
```

**`events/current.json`**
```json
{
  "refreshed_at": "2026-02-19T12:00:00Z",
  "count": 40,
  "events": [
    {
      "id": "uuid",
      "title": "...",
      "description": "...",
      "startDate": "2026-02-20T18:00:00Z",
      "endDate": "2026-02-20T20:00:00Z",
      "location": "...",
      "isOfficial": true,
      "imageURL": "https://storage.googleapis.com/tapin-content/images/events/uuid.jpg",
      "organizerName": "...",
      "clubAcronym": null,
      "eventType": null,
      "tags": [],
      "eventURL": null,
      "aiSummary": "Single-sentence summary (max 80 chars)",
      "aiBulletPoints": ["🎉 Point one", "📅 Point two", "📍 Point three"]
    }
  ]
}
```

---

## Backend Changes

### New: `services/gcs_client.py`
Replaces `services/firestore_client.py`.

```python
from google.cloud import storage

class GCSClient:
    def __init__(self):
        self.client = storage.Client()
        self.bucket = self.client.bucket(os.environ["GCS_BUCKET_NAME"])

    def write_json(self, path: str, data: dict, cache_control: str = "public, max-age=1800"):
        blob = self.bucket.blob(path)
        blob.upload_from_string(
            json.dumps(data),
            content_type="application/json",
            retry=DEFAULT_RETRY
        )
        blob.cache_control = cache_control
        blob.patch()

    def read_json(self, path: str) -> dict | None:
        blob = self.bucket.blob(path)
        if not blob.exists():
            return None
        return json.loads(blob.download_as_text())

    def upload_image(self, path: str, image_bytes: bytes, content_type: str = "image/jpeg"):
        blob = self.bucket.blob(path)
        blob.upload_from_string(image_bytes, content_type=content_type)
        blob.make_public()
        return blob.public_url

    def file_age_seconds(self, path: str) -> float | None:
        blob = self.bucket.blob(path)
        if not blob.exists():
            return None
        blob.reload()
        age = datetime.utcnow() - blob.updated.replace(tzinfo=None)
        return age.total_seconds()
```

### Updated: `repositories/article_repository.py`
- `get_articles(category)` → `gcs.read_json(f"articles/{category}.json")`
- `save_articles(category, articles)` → `gcs.write_json(f"articles/{category}.json", data)`
- Staleness check: use `gcs.file_age_seconds()` instead of comparing `cached_at` timestamp
- Remove all Firestore document read/write calls

### Updated: `repositories/event_repository.py`
- `get_events()` → `gcs.read_json("events/current.json")` (returns full list)
- `save_events(events)` → atomic `gcs.write_json("events/current.json", data)`
- `delete_past_events()` → no longer needed; write replaces the whole file each refresh
- Remove all per-document Firestore operations

### New: `repositories/article_content_repository.py`
- `get_article_content(article_id)` → `gcs.read_json(f"article-content/{article_id}.json")`
- `save_article_content(article_id, content)` → `gcs.write_json(...)`
- Backend now serves full article content; iOS disk cache becomes a true L1 cache

### New: `services/image_mirror_service.py`
- On article/event refresh, download the source image and re-upload to GCS
- Return the GCS public URL instead of the original URL
- Prevents broken images if The Aggie changes URLs or blocks hotlinking

### Updated: `api/articles.py`
- Add endpoint: `GET /api/articles/<article_id>/content`
  - Checks GCS for cached content first
  - If missing, triggers scrape + saves to GCS + returns result
  - Shared across all users (first scrape benefits everyone)

### Updated: `app.yaml` / environment variables
- Add `GCS_BUCKET_NAME` environment variable
- Remove Firestore-specific environment variables if Firestore is fully replaced
- Add `google-cloud-storage` to `requirements.txt`

---

## iOS Changes

### `NewsService.swift`
- Add call to `GET /api/articles/{id}/content` for full article content
- Disk cache (ArticleCacheService) remains as L1 cache on top of backend GCS
- If backend returns cached content, iOS disk cache still saves it locally for offline

### `APIConfig.swift`
- Add `articleContent(id: String)` endpoint constant:
  ```swift
  static func articleContent(_ id: String) -> String {
      return "\(baseURL)api/articles/\(id)/content"
  }
  ```

### No structural changes needed for events or article list fetching.

---

## Migration Steps

### Phase 1: Infrastructure Setup
- [ ] Create GCS bucket `tapin-content` in the same GCP project
- [ ] Set bucket-level IAM: Cloud Run service account gets `roles/storage.objectAdmin`
- [ ] Enable uniform bucket-level access (no per-object ACLs)
- [ ] Set default object CORS policy for public JSON reads (if ever needed client-side)
- [ ] Add `google-cloud-storage` to `requirements.txt`

### Phase 2: Backend — Parallel Write
- [ ] Implement `gcs_client.py`
- [ ] Update `article_repository.py` to write to GCS in addition to Firestore (dual-write)
- [ ] Update `event_repository.py` to write to GCS in addition to Firestore (dual-write)
- [ ] Deploy and verify GCS files appear correctly
- [ ] Verify staleness logic works using file modification time

### Phase 3: Backend — Read from GCS
- [ ] Switch `article_repository.py` reads to GCS (stop reading from Firestore)
- [ ] Switch `event_repository.py` reads to GCS (stop reading from Firestore)
- [ ] Add `article_content_repository.py` and `/api/articles/<id>/content` endpoint
- [ ] Add `image_mirror_service.py` and wire into article/event refresh

### Phase 4: iOS Updates
- [ ] Add `articleContent` endpoint to `APIConfig.swift`
- [ ] Update `NewsService.fetchArticleContent()` to call backend first, fall back to scraping
- [ ] Test offline behavior (disk cache should still work as before)

### Phase 5: Cleanup
- [ ] Remove all Firestore reads/writes from repositories
- [ ] Delete `firestore_client.py` (or archive)
- [ ] If no other Firestore usage exists, remove `google-cloud-firestore` from `requirements.txt`
- [ ] Monitor GCS costs and Firestore usage in Cloud Console to confirm full cutover

---

## Cost & Performance Comparison

| Dimension | Firestore (Current) | GCS (Proposed) |
|---|---|---|
| **Article list reads** | ~$0.06 / 100K reads | ~$0.004 / GB bandwidth |
| **Event reads** | N reads (one per event) | 1 file read per request |
| **Full article content** | Not stored (per-device only) | Shared across all users |
| **Image reliability** | External URLs (fragile) | Owned URLs (durable) |
| **Doc size limit** | 1 MB hard cap | 5 TB per object |
| **Query support** | Full (not needed here) | None (not needed) |
| **Cold start latency** | Firestore connection init | GCS HTTP read (fast) |
| **CDN compatibility** | No native CDN | Cloud CDN ready |

For this workload (read-heavy, infrequently-updated blobs, no complex queries), GCS is
strictly better on cost and simpler to reason about. Firestore's strengths (real-time
listeners, complex queries, transactions) are not used here.

---

## What Stays the Same

- All existing iOS API endpoints (`/api/articles`, `/api/events`, `/api/claude/*`) keep
  the same request/response shape. No iOS API contract changes for existing endpoints.
- Cloud Run deployment and `app.yaml` structure unchanged.
- Claude AI enrichment pipeline for events is unchanged.
- iOS caching layers (disk + in-memory) remain but become more powerful since backend
  now also serves full article content.
- Deterministic ID generation (SHA256-based) is unchanged.
