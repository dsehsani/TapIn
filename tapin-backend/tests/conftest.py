"""
conftest.py — Shared pytest fixtures for all TapIn backend tests.
"""

import json
import pytest
from datetime import datetime, timezone
from unittest.mock import MagicMock


# ---------------------------------------------------------------------------
# MARK: - Flask App / Client
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def app():
    """Create the Flask app once per test session."""
    from app import create_app
    application = create_app()
    application.config["TESTING"] = True
    return application


@pytest.fixture
def client(app):
    """Fresh Flask test client for each test."""
    return app.test_client()


# ---------------------------------------------------------------------------
# MARK: - GCS Mock Bucket
# ---------------------------------------------------------------------------

@pytest.fixture
def mock_bucket(monkeypatch):
    """
    Replaces the real GCS bucket singleton with an in-memory store.

    Blobs expose: upload_from_string, download_as_text, exists, reload,
    make_public, patch(), cache_control, updated, public_url.

    Returns (mock_bucket_instance, store_dict) so individual tests can
    inspect or pre-populate the store directly.
    """
    store: dict = {}  # path → {"data": str, "content_type": str, "updated": datetime}

    class MockBlob:
        def __init__(self, path: str):
            self.path = path
            self.cache_control = None
            self.public_url = f"https://storage.googleapis.com/tapin-content/{path}"
            # Pre-populate updated from store if the blob already exists
            self.updated = store.get(path, {}).get("updated")

        def exists(self) -> bool:
            return self.path in store

        def upload_from_string(self, data, content_type: str = "application/json"):
            now = datetime.now(tz=timezone.utc)
            store[self.path] = {
                "data": data,  # keep as str or bytes — avoid decoding binary content (e.g. JPEG)
                "content_type": content_type,
                "updated": now,
            }
            self.updated = now

        def download_as_text(self) -> str:
            if self.path not in store:
                raise FileNotFoundError(f"GCS object not found: {self.path}")
            return store[self.path]["data"]

        def reload(self):
            if self.path in store:
                self.updated = store[self.path]["updated"]

        def make_public(self):
            pass

        def patch(self):
            pass

    class MockBucketObj:
        def blob(self, path: str) -> MockBlob:
            return MockBlob(path)

        def reload(self):
            pass  # Connectivity check succeeds by default

    mock = MockBucketObj()
    monkeypatch.setattr("services.gcs_client._bucket", mock)
    monkeypatch.setattr("services.gcs_client._gcs_client", MagicMock())
    return mock, store


# ---------------------------------------------------------------------------
# MARK: - Shared Sample Data
# ---------------------------------------------------------------------------

SAMPLE_ARTICLE = {
    "id": "a" * 32,
    "title": "Test Article",
    "excerpt": "This is a test article excerpt for the test suite.",
    "imageURL": "https://theaggie.org/img.jpg",
    "category": "campus",
    "publishDate": "2026-02-19T10:00:00Z",
    "author": "Jane Doe",
    "readTime": 3,
    "articleURL": "https://theaggie.org/2026/02/19/test-article/",
}

SAMPLE_EVENT = {
    "id": "b" * 36,
    "title": "Test Event",
    "description": "A test campus event with enough content.",
    "startDate": "2099-12-31T18:00:00Z",
    "endDate": "2099-12-31T20:00:00Z",
    "location": "ARC",
    "isOfficial": True,
    "imageURL": None,
    "organizerName": "Campus Rec",
    "clubAcronym": None,
    "eventType": None,
    "tags": [],
    "eventURL": None,
    "aiSummary": "A fun test event at the ARC tonight.",
    "aiBulletPoints": ["🏀 Basketball", "🎉 Fun", "📍 ARC"],
    "processedAt": "2026-02-19T12:00:00Z",
}

SAMPLE_CONTENT = {
    "id": "c" * 32,
    "title": "Full Article",
    "author": "John Doe",
    "authorEmail": "jdoe@ucdavis.edu",
    "publishDate": "2026-02-18T09:00:00Z",
    "category": "sports",
    "thumbnailURL": "https://theaggie.org/thumb.jpg",
    "bodyParagraphs": [
        "First paragraph of the full article body with plenty of words.",
        "Second paragraph with **bold text** inside it for formatting.",
    ],
    "articleURL": "https://theaggie.org/2026/02/18/full-article/",
}

MINIMAL_AGGIE_HTML = """
<html>
<body>
  <h1 class="post-title">Test Article Title</h1>
  <a rel="category tag">Campus</a>
  <div class="post-thumbnail"><img src="https://theaggie.org/thumb.jpg"></div>
  <div class="entry-content">
    <p>By Jane Doe — campus@theaggie.org</p>
    <p>This is the first paragraph of the article body with enough content here.</p>
    <p>This is the second paragraph of the article body with enough content here.</p>
    <p>Follow us on Instagram for more updates.</p>
  </div>
</body>
</html>
"""
