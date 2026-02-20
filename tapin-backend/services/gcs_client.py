#
#  gcs_client.py
#  TapInApp - Backend Server
#
#  MARK: - Google Cloud Storage Client
#  Singleton GCS client. Replaces Firestore for article and event storage.
#  Supports local dev (ADC / service account) and Cloud Run (default credentials).
#
#  Bucket layout:
#    articles/{category}.json          — article list per category
#    article-content/{article_id}.json — full scraped article body
#    events/current.json               — all current-week events (atomic)
#    images/articles/{id}.jpg          — mirrored article thumbnails
#    images/events/{id}.jpg            — mirrored event images
#

import os
import json
import logging
from datetime import datetime, timezone
from typing import Optional

logger = logging.getLogger(__name__)

# Initialized lazily on first call to _get_bucket().
# Keeping these as plain Any avoids importing google.cloud.storage at module
# level, which pulls in a protobuf C extension incompatible with Python 3.14.
_gcs_client = None
_bucket = None


# ------------------------------------------------------------------------------
# MARK: - Client / Bucket Initialization
# ------------------------------------------------------------------------------

def _get_bucket():
    """Returns a singleton GCS bucket handle, initializing the client on first call."""
    global _gcs_client, _bucket

    if _bucket is not None:
        return _bucket

    try:
        from google.cloud import storage  # lazy — only imported on real GCS usage
        _gcs_client = storage.Client()
        bucket_name = os.environ.get("GCS_BUCKET_NAME", "tapin-content")
        _bucket = _gcs_client.bucket(bucket_name)
        logger.info(f"GCS client initialized — bucket: {bucket_name}")
        return _bucket
    except Exception as e:
        logger.error(f"Failed to initialize GCS client: {e}")
        raise


# ------------------------------------------------------------------------------
# MARK: - JSON Read / Write
# ------------------------------------------------------------------------------

def write_json(path: str, data: dict, cache_control: str = "public, max-age=1800") -> None:
    """
    Serializes `data` to JSON and uploads it to `path` in the bucket.
    Sets Cache-Control header so GCS / CDN can cache the response.
    """
    bucket = _get_bucket()
    blob = bucket.blob(path)
    blob.upload_from_string(
        json.dumps(data, default=str),
        content_type="application/json",
    )
    # Patch the Cache-Control metadata after upload
    blob.cache_control = cache_control
    blob.patch()
    logger.info(f"GCS write: {path}")


def read_json(path: str) -> Optional[dict]:
    """
    Downloads and deserializes a JSON file from `path` in the bucket.
    Returns None if the file does not exist or on any read error.
    """
    try:
        bucket = _get_bucket()
        blob = bucket.blob(path)
        if not blob.exists():
            return None
        return json.loads(blob.download_as_text())
    except Exception as e:
        logger.error(f"GCS read failed for '{path}': {e}")
        return None


# ------------------------------------------------------------------------------
# MARK: - File Age
# ------------------------------------------------------------------------------

def file_age_seconds(path: str) -> Optional[float]:
    """
    Returns how many seconds ago the file at `path` was last written.
    Returns None if the file does not exist or on error.
    """
    try:
        bucket = _get_bucket()
        blob = bucket.blob(path)
        if not blob.exists():
            return None
        blob.reload()  # Fetch metadata
        if blob.updated is None:
            return None
        updated = blob.updated
        if updated.tzinfo is None:
            updated = updated.replace(tzinfo=timezone.utc)
        age = datetime.now(tz=timezone.utc) - updated
        return age.total_seconds()
    except Exception as e:
        logger.error(f"GCS age check failed for '{path}': {e}")
        return None


# ------------------------------------------------------------------------------
# MARK: - Image Upload
# ------------------------------------------------------------------------------

def upload_image(path: str, image_bytes: bytes, content_type: str = "image/jpeg") -> str:
    """
    Uploads raw image bytes to `path` in the bucket and makes it publicly readable.
    Returns the public URL (https://storage.googleapis.com/...).
    """
    bucket = _get_bucket()
    blob = bucket.blob(path)
    blob.upload_from_string(image_bytes, content_type=content_type)
    blob.make_public()
    return blob.public_url


# ------------------------------------------------------------------------------
# MARK: - Health Check
# ------------------------------------------------------------------------------

def is_gcs_connected() -> bool:
    """Lightweight connectivity check — verifies the bucket is accessible."""
    try:
        bucket = _get_bucket()
        bucket.reload()  # Fetches bucket metadata; raises if unreachable
        return True
    except Exception as e:
        logger.error(f"GCS connectivity check failed: {e}")
        return False
