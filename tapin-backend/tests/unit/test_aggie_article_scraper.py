"""
test_aggie_article_scraper.py — Unit tests for services/aggie_article_scraper.py

Internal parsing functions are tested directly with HTML strings.
scrape_article() network calls are mocked via the `responses` library.
"""

import pytest
import requests
import responses as responses_lib
from bs4 import BeautifulSoup

from services.aggie_article_scraper import (
    scrape_article,
    _parse_html,
    _extract_body_paragraphs,
    _extract_text_preserving_bold,
    _extract_byline_from_content,
    _parse_author_line,
    _text,
    _attr,
)

ARTICLE_URL = "https://theaggie.org/2026/02/19/test-article/"

FALLBACK = {
    "title": "Fallback Title",
    "author": "Fallback Author",
    "category": "campus",
    "imageURL": "https://theaggie.org/fallback.jpg",
    "publishDate": "2026-02-19T10:00:00Z",
    "articleURL": ARTICLE_URL,
}


def make_doc(html: str) -> BeautifulSoup:
    return BeautifulSoup(html, "html.parser")


# ---------------------------------------------------------------------------
# MARK: - Title Extraction
# ---------------------------------------------------------------------------

class TestTitleExtraction:

    def test_from_post_title_h1(self):
        html = "<html><body><h1 class='post-title'>My Article</h1><div class='entry-content'><p>Body text that is long enough to pass.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, FALLBACK)
        assert result["title"] == "My Article"

    def test_falls_back_to_article_h1(self):
        html = "<html><body><article><h1>Article H1 Title</h1></article><div class='entry-content'><p>Body text that is long enough to pass.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, FALLBACK)
        assert result["title"] == "Article H1 Title"

    def test_falls_back_to_entry_title(self):
        html = "<html><body><h1 class='entry-title'>Entry Title</h1><div class='entry-content'><p>Body text that is long enough to pass.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, FALLBACK)
        assert result["title"] == "Entry Title"

    def test_falls_back_to_fallback_dict(self):
        html = "<html><body><div class='entry-content'><p>Body text that is long enough to pass.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, FALLBACK)
        assert result["title"] == "Fallback Title"

    def test_empty_fallback_title_returns_empty_string(self):
        html = "<html><body><div class='entry-content'><p>Body text that is long enough to pass.</p></div></body></html>"
        fb = {**FALLBACK, "title": ""}
        result = _parse_html(html, ARTICLE_URL, fb)
        assert result["title"] == ""

    def test_post_title_takes_priority_over_entry_title(self):
        html = "<html><body><h1 class='post-title'>Post Title</h1><h1 class='entry-title'>Entry Title</h1><div class='entry-content'><p>Long enough body paragraph here.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, FALLBACK)
        assert result["title"] == "Post Title"


# ---------------------------------------------------------------------------
# MARK: - Author / Byline Extraction
# ---------------------------------------------------------------------------

class TestAuthorExtraction:

    def test_byline_extracted_from_first_paragraph(self):
        html = "<html><body><div class='entry-content'><p>By Jane Doe — campus@theaggie.org</p><p>This is the article body with sufficient length.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, FALLBACK)
        assert result["author"] == "Jane Doe"
        assert result["authorEmail"] == "campus@theaggie.org"

    def test_byline_without_email(self):
        html = "<html><body><div class='entry-content'><p>By John Smith</p><p>This is the article body with sufficient length.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, FALLBACK)
        assert result["author"] == "John Smith"
        assert result["authorEmail"] is None

    def test_byline_scanning_stops_at_paragraph_6(self):
        # Paragraphs 0-5 (6 total), byline at index 6 should NOT be found
        paragraphs = "".join(f"<p>Paragraph {i} has enough words to not be filtered.</p>" for i in range(6))
        byline_at_7 = "<p>By Hidden Author</p>"
        html = f"<html><body><div class='entry-content'>{paragraphs}{byline_at_7}<p>Actual body paragraph with enough words.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_byline_from_content(doc)
        assert result is None  # Byline at index 6 is NOT found (only 0-5 scanned)

    def test_byline_found_in_first_6_paragraphs(self):
        paragraphs = "".join(f"<p>Para {i} with enough words to pass filter.</p>" for i in range(3))
        byline = "<p>By Staff Writer — science@theaggie.org</p>"
        html = f"<html><body>{paragraphs}{byline}<p>Body.</p></body></html>"
        doc = make_doc(html)
        result = _extract_byline_from_content(doc)
        assert result == "By Staff Writer — science@theaggie.org"

    def test_falls_back_to_author_name_class(self):
        html = "<html><body><span class='author-name'>Staff Writer</span><div class='entry-content'><p>Long enough body text here for the test.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, {**FALLBACK, "author": "Default"})
        assert result["author"] == "Staff Writer"

    def test_falls_back_to_entry_author_class(self):
        html = "<html><body><span class='entry-author'>Entry Author Name</span><div class='entry-content'><p>Long enough body text here for testing purposes.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, {**FALLBACK, "author": "Default"})
        assert result["author"] == "Entry Author Name"

    def test_falls_back_to_byline_anchor(self):
        html = "<html><body><div class='byline'><a>Byline Author</a></div><div class='entry-content'><p>Long enough body text here for testing purposes.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, {**FALLBACK, "author": "Default"})
        assert result["author"] == "Byline Author"

    def test_falls_back_to_fallback_dict_author(self):
        html = "<html><body><div class='entry-content'><p>Long enough body text here for testing purposes.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, {**FALLBACK, "author": "The Aggie"})
        assert result["author"] == "The Aggie"

    def test_byline_case_insensitive_by_prefix(self):
        html = "<html><body><div class='entry-content'><p>BY JANE DOE — ops@theaggie.org</p><p>Long enough body text here for testing purposes.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, FALLBACK)
        assert result["author"] == "JANE DOE"
        assert result["authorEmail"] == "ops@theaggie.org"


class TestParseAuthorLine:

    def test_name_only(self):
        name, email = _parse_author_line("By Alice", "Fallback")
        assert name == "Alice"
        assert email is None

    def test_name_and_email(self):
        name, email = _parse_author_line("By Alice — a@theaggie.org", "Fallback")
        assert name == "Alice"
        assert email == "a@theaggie.org"

    def test_raw_without_by_prefix(self):
        name, email = _parse_author_line("Alice Smith", "Fallback")
        assert name == "Alice Smith"
        assert email is None

    def test_empty_string_returns_fallback(self):
        name, email = _parse_author_line("", "The Aggie")
        assert name == "The Aggie"
        assert email is None

    def test_only_by_prefix_returns_fallback(self):
        name, email = _parse_author_line("By ", "The Aggie")
        assert name == "The Aggie"

    def test_em_dash_separates_name_and_email(self):
        name, email = _parse_author_line("By Foo Bar — foo@bar.com", "Fallback")
        assert name == "Foo Bar"
        assert email == "foo@bar.com"

    def test_extra_whitespace_trimmed(self):
        name, email = _parse_author_line("By   Alice   —   alice@theaggie.org   ", "Fallback")
        assert name == "Alice"
        assert email == "alice@theaggie.org"


# ---------------------------------------------------------------------------
# MARK: - Category Extraction
# ---------------------------------------------------------------------------

class TestCategoryExtraction:

    def test_from_category_tag_anchor(self):
        html = "<html><body><a rel='category tag'>Campus</a><div class='entry-content'><p>Long enough body here for test.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, FALLBACK)
        assert result["category"] == "Campus"

    def test_falls_back_to_cat_links(self):
        html = "<html><body><div class='cat-links'><a>Sports</a></div><div class='entry-content'><p>Long enough body here for test.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, {**FALLBACK, "category": "Fallback Cat"})
        assert result["category"] == "Sports"

    def test_falls_back_to_fallback_dict(self):
        html = "<html><body><div class='entry-content'><p>Long enough body here for test.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, {**FALLBACK, "category": "My Category"})
        assert result["category"] == "My Category"


# ---------------------------------------------------------------------------
# MARK: - Thumbnail Extraction
# ---------------------------------------------------------------------------

class TestThumbnailExtraction:

    def test_from_post_thumbnail(self):
        html = "<html><body><div class='post-thumbnail'><img src='https://theaggie.org/img.jpg'></div><div class='entry-content'><p>Long enough body here for test.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, {**FALLBACK, "imageURL": ""})
        assert result["thumbnailURL"] == "https://theaggie.org/img.jpg"

    def test_falls_back_to_wp_post_image(self):
        html = "<html><body><img class='wp-post-image' src='https://theaggie.org/wp.jpg'><div class='entry-content'><p>Long enough body here for test.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, {**FALLBACK, "imageURL": ""})
        assert result["thumbnailURL"] == "https://theaggie.org/wp.jpg"

    def test_falls_back_to_article_img(self):
        html = "<html><body><article><img src='https://theaggie.org/art.jpg'></article><div class='entry-content'><p>Long enough body here for test.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, {**FALLBACK, "imageURL": ""})
        assert result["thumbnailURL"] == "https://theaggie.org/art.jpg"

    def test_falls_back_to_fallback_image_url(self):
        html = "<html><body><div class='entry-content'><p>Long enough body here for test.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, {**FALLBACK, "imageURL": "https://fallback.jpg"})
        assert result["thumbnailURL"] == "https://fallback.jpg"

    def test_none_when_no_image_anywhere(self):
        html = "<html><body><div class='entry-content'><p>Long enough body here for test.</p></div></body></html>"
        result = _parse_html(html, ARTICLE_URL, {**FALLBACK, "imageURL": ""})
        # imageURL is "" which is falsy, so fallback.get("imageURL") returns ""
        # _attr returns None for empty string
        # fallback.get("imageURL") returns "" which is falsy — so thumbnailURL is None or ""
        assert not result["thumbnailURL"]  # Either None or ""


# ---------------------------------------------------------------------------
# MARK: - Body Paragraph Extraction
# ---------------------------------------------------------------------------

class TestBodyParagraphExtraction:

    def test_from_entry_content(self):
        html = "<html><body><div class='entry-content'><p>This is a real paragraph with enough characters.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert len(result) == 1
        assert "real paragraph" in result[0]

    def test_from_post_content_fallback(self):
        html = "<html><body><div class='post-content'><p>This paragraph lives in post-content div element.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert len(result) == 1

    def test_from_article_content_fallback(self):
        html = "<html><body><div class='article-content'><p>This paragraph lives in article-content div.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert len(result) == 1

    def test_falls_back_to_article_element(self):
        html = "<html><body><article><p>This is article body paragraph text with enough content here.</p></article></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert len(result) == 1

    def test_falls_back_to_body(self):
        html = "<html><body><p>This is body-level paragraph text with enough content here.</p></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert len(result) == 1

    def test_short_paragraphs_filtered_out(self):
        html = "<html><body><div class='entry-content'><p>Too short</p><p>This is a proper paragraph with enough characters to pass.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert len(result) == 1
        assert "proper paragraph" in result[0]

    def test_exactly_20_chars_filtered(self):
        # 20 chars → <= 20 → filtered
        html = "<html><body><div class='entry-content'><p>12345678901234567890</p><p>This paragraph has enough characters to pass the filter.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert not any("12345" in p for p in result)

    def test_21_chars_not_filtered(self):
        html = "<html><body><div class='entry-content'><p>123456789012345678901</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert len(result) == 1

    def test_byline_paragraph_filtered(self):
        html = "<html><body><div class='entry-content'><p>By Jane Doe — campus@theaggie.org</p><p>This is the real body paragraph with enough text.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert len(result) == 1
        assert "Jane Doe" not in result[0]

    def test_noise_follow_us_filtered(self):
        html = "<html><body><div class='entry-content'><p>Follow us on Instagram for the latest news.</p><p>This is the actual body paragraph with real content here.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert not any("Follow us on" in p for p in result)

    def test_noise_subscribe_filtered(self):
        html = "<html><body><div class='entry-content'><p>Subscribe to our newsletter for updates now.</p><p>Real article body paragraph with enough text.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert not any("Subscribe" in p for p in result)

    def test_noise_support_the_aggie_filtered(self):
        html = "<html><body><div class='entry-content'><p>Support the Aggie by donating today!</p><p>Real article body paragraph with enough text.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert not any("Support the Aggie" in p for p in result)

    def test_noise_written_by_filtered(self):
        html = "<html><body><div class='entry-content'><p>Written by the Editorial Board at The Aggie.</p><p>Real article body paragraph with enough text here.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert not any("Written by" in p for p in result)

    def test_noise_copyright_filtered(self):
        html = "<html><body><div class='entry-content'><p>© 2026 The California Aggie. All rights reserved.</p><p>Real article body paragraph with enough text here.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert not any("©" in p for p in result)

    def test_noise_filter_is_case_insensitive(self):
        html = "<html><body><div class='entry-content'><p>FOLLOW US ON Twitter for more content!</p><p>Real article body paragraph with enough text here.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert not any("FOLLOW US ON" in p for p in result)

    def test_multiple_valid_paragraphs_all_returned_in_order(self):
        html = """<html><body><div class='entry-content'>
            <p>First valid paragraph with plenty of text content here.</p>
            <p>Second valid paragraph with plenty of text content here.</p>
            <p>Third valid paragraph with plenty of text content here.</p>
        </div></body></html>"""
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert len(result) == 3
        assert "First" in result[0]
        assert "Second" in result[1]
        assert "Third" in result[2]

    def test_returns_empty_list_when_all_noise(self):
        html = "<html><body><div class='entry-content'><p>Too short</p><p>By Author</p><p>Follow us on social media!</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert result == []

    def test_noise_contained_anywhere_in_text_filtered(self):
        # "© 2026" appears in middle of paragraph
        html = "<html><body><div class='entry-content'><p>Content here. © 2026 The Aggie. More content.</p><p>Real paragraph with plenty of text content here.</p></div></body></html>"
        doc = make_doc(html)
        result = _extract_body_paragraphs(doc)
        assert not any("©" in p for p in result)


# ---------------------------------------------------------------------------
# MARK: - Bold Preservation
# ---------------------------------------------------------------------------

class TestBoldPreservation:

    def _p(self, inner_html: str):
        return make_doc(f"<p>{inner_html}</p>").find("p")

    def test_strong_wrapped_in_asterisks(self):
        tag = self._p("Normal <strong>Bold</strong> text")
        result = _extract_text_preserving_bold(tag)
        assert "**Bold**" in result

    def test_b_tag_wrapped_in_asterisks(self):
        tag = self._p("Normal <b>Bold</b> text")
        result = _extract_text_preserving_bold(tag)
        assert "**Bold**" in result

    def test_multiple_bold_segments(self):
        tag = self._p("<strong>A</strong> and <strong>B</strong>")
        result = _extract_text_preserving_bold(tag)
        assert "**A**" in result
        assert "**B**" in result

    def test_no_extra_spaces_in_bold_markers(self):
        tag = self._p("<strong> Bold with spaces </strong>")
        result = _extract_text_preserving_bold(tag)
        # Should NOT contain "** Bold" or "spaces **"
        assert "** " not in result
        assert " **" not in result

    def test_non_bold_html_stripped(self):
        tag = self._p("Text with <em>italic</em> not preserved")
        result = _extract_text_preserving_bold(tag)
        assert "<em>" not in result
        assert "italic" in result  # text content kept, tags stripped

    def test_nested_tags_stripped(self):
        tag = self._p("<a href='#'>Link text</a> after link")
        result = _extract_text_preserving_bold(tag)
        assert "<a" not in result
        assert "Link text" in result


# ---------------------------------------------------------------------------
# MARK: - HTML Entity Decoding
# ---------------------------------------------------------------------------

class TestHtmlEntityDecoding:

    def _p(self, inner_html: str):
        return make_doc(f"<p>{inner_html}</p>").find("p")

    def test_amp_entity(self):
        tag = self._p("Fish &amp; Chips")
        assert "Fish & Chips" in _extract_text_preserving_bold(tag)

    def test_lt_gt_entities(self):
        tag = self._p("A &lt; B &gt; C")
        result = _extract_text_preserving_bold(tag)
        assert "A < B > C" in result

    def test_quot_entity(self):
        tag = self._p('Say &quot;hello&quot;')
        result = _extract_text_preserving_bold(tag)
        assert 'Say "hello"' in result

    def test_nbsp_entity(self):
        tag = self._p("word&nbsp;word")
        result = _extract_text_preserving_bold(tag)
        assert "word word" in result

    def test_numeric_nbsp(self):
        tag = self._p("word&#160;word")
        result = _extract_text_preserving_bold(tag)
        assert "word word" in result

    def test_left_double_quote(self):
        tag = self._p("&#8220;quoted&#8221;")
        result = _extract_text_preserving_bold(tag)
        assert "\u201C" in result
        assert "\u201D" in result

    def test_left_single_quote(self):
        tag = self._p("&#8216;it&#8217;s")
        result = _extract_text_preserving_bold(tag)
        assert "\u2018" in result
        assert "\u2019" in result

    def test_ellipsis_entity(self):
        tag = self._p("Wait&#8230;")
        result = _extract_text_preserving_bold(tag)
        assert "\u2026" in result

    def test_numeric_amp_entity(self):
        tag = self._p("Me &#38; You")
        result = _extract_text_preserving_bold(tag)
        assert "Me & You" in result


# ---------------------------------------------------------------------------
# MARK: - Network / scrape_article
# ---------------------------------------------------------------------------

class TestScrapeArticle:

    GOOD_HTML = """<html><body>
        <h1 class='post-title'>Article Title</h1>
        <div class='entry-content'>
            <p>By Jane Doe — campus@theaggie.org</p>
            <p>This is the first real paragraph with enough content here.</p>
            <p>This is the second real paragraph with enough content here.</p>
        </div>
    </body></html>"""

    @responses_lib.activate
    def test_successful_scrape_returns_dict(self):
        responses_lib.add(responses_lib.GET, ARTICLE_URL, body=self.GOOD_HTML, status=200,
                          content_type="text/html; charset=utf-8")
        result = scrape_article(ARTICLE_URL, FALLBACK)
        assert result is not None
        assert result["title"] == "Article Title"
        assert result["author"] == "Jane Doe"
        assert result["authorEmail"] == "campus@theaggie.org"
        assert len(result["bodyParagraphs"]) == 2
        assert result["articleURL"] == ARTICLE_URL

    @responses_lib.activate
    def test_returns_none_on_404(self):
        responses_lib.add(responses_lib.GET, ARTICLE_URL, status=404)
        result = scrape_article(ARTICLE_URL, FALLBACK)
        assert result is None

    @responses_lib.activate
    def test_returns_none_on_500(self):
        responses_lib.add(responses_lib.GET, ARTICLE_URL, status=500)
        result = scrape_article(ARTICLE_URL, FALLBACK)
        assert result is None

    @responses_lib.activate
    def test_returns_none_on_connection_error(self):
        responses_lib.add(responses_lib.GET, ARTICLE_URL,
                          body=requests.exceptions.ConnectionError())
        result = scrape_article(ARTICLE_URL, FALLBACK)
        assert result is None

    @responses_lib.activate
    def test_returns_none_on_timeout(self):
        responses_lib.add(responses_lib.GET, ARTICLE_URL,
                          body=requests.exceptions.Timeout())
        result = scrape_article(ARTICLE_URL, FALLBACK)
        assert result is None

    @responses_lib.activate
    def test_returns_none_when_no_body_paragraphs(self):
        html = "<html><body><h1 class='post-title'>Title</h1><div class='entry-content'><p>Short</p></div></body></html>"
        responses_lib.add(responses_lib.GET, ARTICLE_URL, body=html, status=200,
                          content_type="text/html")
        result = scrape_article(ARTICLE_URL, FALLBACK)
        assert result is None

    @responses_lib.activate
    def test_uses_custom_user_agent_header(self):
        responses_lib.add(responses_lib.GET, ARTICLE_URL, body=self.GOOD_HTML, status=200,
                          content_type="text/html")
        scrape_article(ARTICLE_URL, FALLBACK)
        assert responses_lib.calls[0].request.headers["User-Agent"] == "TapIn/1.0 (iOS; UC Davis)"

    @responses_lib.activate
    def test_returns_article_url_in_result(self):
        responses_lib.add(responses_lib.GET, ARTICLE_URL, body=self.GOOD_HTML, status=200,
                          content_type="text/html")
        result = scrape_article(ARTICLE_URL, FALLBACK)
        assert result["articleURL"] == ARTICLE_URL

    @responses_lib.activate
    def test_publish_date_comes_from_fallback(self):
        responses_lib.add(responses_lib.GET, ARTICLE_URL, body=self.GOOD_HTML, status=200,
                          content_type="text/html")
        result = scrape_article(ARTICLE_URL, {**FALLBACK, "publishDate": "2026-02-01T00:00:00Z"})
        assert result["publishDate"] == "2026-02-01T00:00:00Z"
