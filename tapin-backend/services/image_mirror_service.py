#
#  image_mirror_service.py
#  TapInApp - Backend Server
#
#  MARK: - Image Mirror Service
#  Downloads images from external URLs (The Aggie, Aggie Life) and re-uploads
#  them to our GCS bucket so the iOS app always loads from a stable, owned URL.
#
#  If mirroring fails for any reason, the original URL is returned unchanged
#  so the app degrades gracefully rather than breaking.
#
#  Bucket paths:
#    images/articles/{article_id}.jpg
#    images/events/{event_id}.jpg
#

import logging
import requests
from typing import Optional

from services.gcs_client import upload_image

logger = logging.getLogger(__name__)

REQUEST_TIMEOUT = 8

# Map of content-type → file extension for the GCS object name
_CONTENT_TYPE_EXT = {
    "image/jpeg": "jpg",
    "image/jpg":  "jpg",
    "image/png":  "png",
    "image/webp": "webp",
    "image/gif":  "gif",
}


# ------------------------------------------------------------------------------
# MARK: - Public API
# ------------------------------------------------------------------------------

def mirror_article_image(article_id: str, source_url: Optional[str]) -> Optional[str]:
    """
    Downloads `source_url` and uploads it to images/articles/{article_id}.{ext}.
    Returns the GCS public URL on success, or the original `source_url` on failure.
    Returns None if source_url is None or empty.
    """
    return _mirror(source_url, f"images/articles/{article_id}")


def mirror_event_image(event_id: str, source_url: Optional[str]) -> Optional[str]:
    """
    Downloads `source_url` and uploads it to images/events/{event_id}.{ext}.
    Returns the GCS public URL on success, or the original `source_url` on failure.
    Returns None if source_url is None or empty.
    """
    return _mirror(source_url, f"images/events/{event_id}")


# ------------------------------------------------------------------------------
# MARK: - Internal
# ------------------------------------------------------------------------------

def _mirror(source_url: Optional[str], gcs_path_prefix: str) -> Optional[str]:
    """
    Downloads an image from `source_url` and uploads it to GCS at
    `{gcs_path_prefix}.{ext}`. Returns the GCS public URL or falls back
    to the original URL on any error.
    """
    if not source_url:
        return None

    try:
        resp = requests.get(source_url, timeout=REQUEST_TIMEOUT, headers={
            "User-Agent": "TapIn/1.0 (iOS; UC Davis)"
        })
        resp.raise_for_status()

        content_type = resp.headers.get("Content-Type", "image/jpeg").split(";")[0].strip()
        ext = _CONTENT_TYPE_EXT.get(content_type, "jpg")
        gcs_path = f"{gcs_path_prefix}.{ext}"

        public_url = upload_image(gcs_path, resp.content, content_type=content_type)
        logger.info(f"Mirrored image: {source_url} → {public_url}")
        return public_url

    except Exception as e:
        logger.warning(f"Image mirror failed for '{source_url}': {e} — using original URL")
        return source_url
