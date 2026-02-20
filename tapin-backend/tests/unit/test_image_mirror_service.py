"""
test_image_mirror_service.py — Unit tests for services/image_mirror_service.py

HTTP calls are mocked via the `responses` library.
GCS upload_image is patched so no real bucket is accessed.
"""

import pytest
import requests
import responses as responses_lib
from unittest.mock import patch

from services.image_mirror_service import (
    mirror_article_image,
    mirror_event_image,
    _mirror,
)

IMAGE_URL = "https://theaggie.org/wp-content/uploads/2026/02/photo.jpg"
GCS_PUBLIC_URL = "https://storage.googleapis.com/tapin-content/images/articles/abc123.jpg"


# ---------------------------------------------------------------------------
# MARK: - mirror_article_image / mirror_event_image routing
# ---------------------------------------------------------------------------

class TestMirrorRouting:

    @responses_lib.activate
    def test_article_image_uses_articles_path(self):
        responses_lib.add(responses_lib.GET, IMAGE_URL, body=b"jpeg-bytes", status=200,
                          headers={"Content-Type": "image/jpeg"})
        paths_uploaded = []

        def fake_upload(path, data, content_type="image/jpeg"):
            paths_uploaded.append(path)
            return f"https://storage.googleapis.com/tapin-content/{path}"

        with patch("services.image_mirror_service.upload_image", fake_upload):
            mirror_article_image("abc123", IMAGE_URL)

        assert paths_uploaded[0].startswith("images/articles/abc123")

    @responses_lib.activate
    def test_event_image_uses_events_path(self):
        responses_lib.add(responses_lib.GET, IMAGE_URL, body=b"jpeg-bytes", status=200,
                          headers={"Content-Type": "image/jpeg"})
        paths_uploaded = []

        def fake_upload(path, data, content_type="image/jpeg"):
            paths_uploaded.append(path)
            return f"https://storage.googleapis.com/tapin-content/{path}"

        with patch("services.image_mirror_service.upload_image", fake_upload):
            mirror_event_image("event-xyz", IMAGE_URL)

        assert paths_uploaded[0].startswith("images/events/event-xyz")

    def test_article_image_none_url_returns_none(self):
        result = mirror_article_image("abc123", None)
        assert result is None

    def test_event_image_none_url_returns_none(self):
        result = mirror_event_image("event-xyz", None)
        assert result is None

    def test_article_image_empty_string_returns_none(self):
        result = mirror_article_image("abc123", "")
        assert result is None

    def test_event_image_empty_string_returns_none(self):
        result = mirror_event_image("event-xyz", "")
        assert result is None


# ---------------------------------------------------------------------------
# MARK: - Successful Mirror
# ---------------------------------------------------------------------------

class TestSuccessfulMirror:

    @responses_lib.activate
    def test_returns_gcs_url_not_original(self):
        responses_lib.add(responses_lib.GET, IMAGE_URL, body=b"image-data", status=200,
                          headers={"Content-Type": "image/jpeg"})

        with patch("services.image_mirror_service.upload_image", return_value=GCS_PUBLIC_URL):
            result = mirror_article_image("abc123", IMAGE_URL)

        assert result == GCS_PUBLIC_URL
        assert result != IMAGE_URL

    @responses_lib.activate
    def test_image_bytes_passed_to_upload(self):
        image_bytes = b"\xff\xd8\xff fake jpeg bytes"
        responses_lib.add(responses_lib.GET, IMAGE_URL, body=image_bytes, status=200,
                          headers={"Content-Type": "image/jpeg"})
        uploaded_data = []

        def fake_upload(path, data, content_type="image/jpeg"):
            uploaded_data.append(data)
            return GCS_PUBLIC_URL

        with patch("services.image_mirror_service.upload_image", fake_upload):
            mirror_article_image("abc123", IMAGE_URL)

        assert uploaded_data[0] == image_bytes


# ---------------------------------------------------------------------------
# MARK: - Content-Type → Extension Mapping
# ---------------------------------------------------------------------------

class TestContentTypeExtensionMapping:

    def _run(self, content_type: str) -> str:
        png_url = "https://theaggie.org/image.png"
        with responses_lib.RequestsMock() as rsps:
            rsps.add(responses_lib.GET, png_url, body=b"data", status=200,
                     headers={"Content-Type": content_type})
            paths = []

            def fake_upload(path, data, content_type="image/jpeg"):
                paths.append(path)
                return f"https://storage.googleapis.com/{path}"

            with patch("services.image_mirror_service.upload_image", fake_upload):
                _mirror(png_url, "images/articles/id")

        return paths[0] if paths else ""

    def test_jpeg_uses_jpg_extension(self):
        assert self._run("image/jpeg").endswith(".jpg")

    def test_jpg_uses_jpg_extension(self):
        assert self._run("image/jpg").endswith(".jpg")

    def test_png_uses_png_extension(self):
        assert self._run("image/png").endswith(".png")

    def test_webp_uses_webp_extension(self):
        assert self._run("image/webp").endswith(".webp")

    def test_gif_uses_gif_extension(self):
        assert self._run("image/gif").endswith(".gif")

    def test_unknown_content_type_defaults_to_jpg(self):
        assert self._run("application/octet-stream").endswith(".jpg")

    @responses_lib.activate
    def test_content_type_with_charset_parameter_parsed_correctly(self):
        url = "https://theaggie.org/image.jpg"
        responses_lib.add(responses_lib.GET, url, body=b"data", status=200,
                          headers={"Content-Type": "image/jpeg; charset=utf-8"})
        paths = []

        def fake_upload(path, data, content_type="image/jpeg"):
            paths.append(path)
            return GCS_PUBLIC_URL

        with patch("services.image_mirror_service.upload_image", fake_upload):
            _mirror(url, "images/articles/id")

        assert paths[0].endswith(".jpg")


# ---------------------------------------------------------------------------
# MARK: - Error / Fallback Behavior
# ---------------------------------------------------------------------------

class TestErrorFallback:

    @responses_lib.activate
    def test_returns_original_url_on_404(self):
        responses_lib.add(responses_lib.GET, IMAGE_URL, status=404)
        result = mirror_article_image("abc123", IMAGE_URL)
        assert result == IMAGE_URL

    @responses_lib.activate
    def test_returns_original_url_on_500(self):
        responses_lib.add(responses_lib.GET, IMAGE_URL, status=500)
        result = mirror_article_image("abc123", IMAGE_URL)
        assert result == IMAGE_URL

    @responses_lib.activate
    def test_returns_original_url_on_connection_error(self):
        responses_lib.add(responses_lib.GET, IMAGE_URL,
                          body=requests.exceptions.ConnectionError())
        result = mirror_article_image("abc123", IMAGE_URL)
        assert result == IMAGE_URL

    @responses_lib.activate
    def test_returns_original_url_on_timeout(self):
        responses_lib.add(responses_lib.GET, IMAGE_URL,
                          body=requests.exceptions.Timeout())
        result = mirror_article_image("abc123", IMAGE_URL)
        assert result == IMAGE_URL

    @responses_lib.activate
    def test_returns_original_url_on_gcs_upload_failure(self):
        responses_lib.add(responses_lib.GET, IMAGE_URL, body=b"data", status=200,
                          headers={"Content-Type": "image/jpeg"})
        with patch("services.image_mirror_service.upload_image",
                   side_effect=Exception("GCS write failed")):
            result = mirror_article_image("abc123", IMAGE_URL)
        assert result == IMAGE_URL

    @responses_lib.activate
    def test_fallback_does_not_raise(self):
        responses_lib.add(responses_lib.GET, IMAGE_URL,
                          body=requests.exceptions.ConnectionError())
        # Must not raise
        result = mirror_article_image("abc123", IMAGE_URL)
        assert result == IMAGE_URL
