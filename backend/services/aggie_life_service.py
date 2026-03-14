#
#  aggie_life_service.py
#  TapInApp - Backend Server
#
#  MARK: - Aggie Life iCal Fetcher & Parser
#  Python port of the iOS ICalParser.swift + AggieLifeService.swift.
#  Fetches the Aggie Life iCal feed and returns a list of event dicts.
#

import os
import re
import logging
import urllib.request
import hashlib
import uuid
from datetime import datetime, timezone, timedelta

import requests
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)


AGGIE_LIFE_URL = "https://aggielife.ucdavis.edu/ical/ucdavis/ical_ucdavis.ics"

OFFICIAL_ORGANIZERS = [
    "center for student involvement",
    "cross cultural center",
    "women's resources and research center",
    "guardian scholars program",
    "asucd",
    "student affairs",
]


# ------------------------------------------------------------------------------
# MARK: - Public API
# ------------------------------------------------------------------------------

def fetch_events() -> list[dict]:
    """
    Fetches and parses events from the Aggie Life iCal feed.
    Returns a list of event dicts, filtered and sorted by start date.
    """
    ics_text = _fetch_ics()
    blocks = _extract_event_blocks(ics_text)
    events = [e for b in blocks if (e := _parse_event(b)) is not None]
    events = _clean_events(events)
    events.sort(key=lambda e: e["startDate"])
    return events


# ------------------------------------------------------------------------------
# MARK: - Fetch
# ------------------------------------------------------------------------------

def _fetch_ics() -> str:
    """
    Fetches the Aggie Life iCal feed. If UC Davis credentials are configured
    (UCDAVIS_LOGIN_ID + UCDAVIS_PASSWORD), authenticates via CAS first so
    that hidden event locations are included in the feed.
    Falls back to an unauthenticated fetch if credentials are missing or login fails.
    """
    login_id = os.environ.get("UCDAVIS_LOGIN_ID", "").strip()
    password = os.environ.get("UCDAVIS_PASSWORD", "").strip()

    if login_id and password:
        try:
            return _fetch_ics_authenticated(login_id, password)
        except Exception as e:
            logger.warning(f"Authenticated iCal fetch failed, falling back to public: {e}")

    # Fallback: unauthenticated fetch
    req = urllib.request.Request(
        AGGIE_LIFE_URL,
        headers={"User-Agent": "TapIn-Backend/1.0"}
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read().decode("utf-8", errors="replace")


def _fetch_ics_authenticated(login_id: str, password: str) -> str:
    """
    Authenticates with UC Davis CAS and fetches the iCal feed with session cookies.
    CAS flow: GET login page → extract form fields → POST credentials → follow redirect.
    """
    session = requests.Session()
    session.headers.update({"User-Agent": "TapIn-Backend/1.0"})

    # Step 1: GET the CAS login page (with service= pointing to Aggie Life)
    cas_url = "https://cas.ucdavis.edu/cas/login"
    login_page = session.get(cas_url, params={"service": AGGIE_LIFE_URL}, timeout=15)
    login_page.raise_for_status()

    # Step 2: Extract hidden form fields (lt, execution, _eventId, etc.)
    soup = BeautifulSoup(login_page.text, "html.parser")
    form = soup.find("form")
    if not form:
        raise ValueError("Could not find CAS login form")

    form_data = {}
    for inp in form.find_all("input"):
        name = inp.get("name")
        if name:
            form_data[name] = inp.get("value", "")

    # Fill in credentials
    form_data["username"] = login_id
    form_data["password"] = password

    # Step 3: POST credentials to CAS
    form_action = form.get("action", "")
    if form_action.startswith("/"):
        post_url = f"https://cas.ucdavis.edu{form_action}"
    elif form_action.startswith("http"):
        post_url = form_action
    else:
        post_url = f"https://cas.ucdavis.edu/cas/login"

    login_resp = session.post(post_url, data=form_data, timeout=15)
    login_resp.raise_for_status()

    # Step 4: Fetch the iCal feed with authenticated session
    ics_resp = session.get(AGGIE_LIFE_URL, timeout=15)
    ics_resp.raise_for_status()

    ics_text = ics_resp.text
    # Verify we got actual iCal data and not a login page
    if "BEGIN:VCALENDAR" not in ics_text:
        raise ValueError("Authenticated fetch did not return valid iCal data — login may have failed")

    logger.info("Successfully fetched iCal feed with authentication")
    return ics_text


# ------------------------------------------------------------------------------
# MARK: - Block Extraction
# ------------------------------------------------------------------------------

def _extract_event_blocks(ics_text: str) -> list[str]:
    blocks = []
    lines = ics_text.splitlines()
    current: list[str] = []
    inside = False

    for line in lines:
        stripped = line.strip()
        if stripped == "BEGIN:VEVENT":
            inside = True
            current = []
        elif stripped == "END:VEVENT":
            inside = False
            blocks.append("\n".join(current))
        elif inside:
            current.append(stripped)

    return blocks


# ------------------------------------------------------------------------------
# MARK: - Event Parsing
# ------------------------------------------------------------------------------

def _parse_event(block: str) -> dict | None:
    fields = _extract_fields(block)

    title = (fields.get("SUMMARY") or "").strip()
    if not title:
        return None

    start_date = _parse_date(fields.get("DTSTART", ""))
    if start_date is None:
        return None

    end_date = _parse_date(fields.get("DTEND", ""))

    description = _clean_description(fields.get("DESCRIPTION", ""))
    location = _clean_location(fields.get("LOCATION", ""))
    organizer_name = _extract_organizer_name(block)
    organizer_url = _extract_organizer_url(block)
    club_acronym = _extract_category("club_acronym", block)
    event_type = (_extract_category("event_type", block) or "").strip() or None
    tags = _extract_tags(block)
    event_url = fields.get("URL")
    is_official = _check_if_official(organizer_url, organizer_name)

    # Stable document ID: deterministic UUID from title + start date
    stable_hash = hashlib.sha256(
        f"{title}{start_date.isoformat()}".encode("utf-8")
    ).hexdigest()
    doc_id = str(uuid.UUID(stable_hash[:32]))

    return {
        "id": doc_id,
        "title": title,
        "description": description,
        "startDate": start_date,
        "endDate": end_date,
        "location": location,
        "isOfficial": is_official,
        "imageURL": None,
        "organizerName": organizer_name,
        "clubAcronym": club_acronym,
        "eventType": event_type,
        "tags": tags,
        "eventURL": event_url,
        "organizerURL": organizer_url,
        "aiSummary": None,
        "aiBulletPoints": [],
    }


# ------------------------------------------------------------------------------
# MARK: - Field Extraction
# ------------------------------------------------------------------------------

def _extract_fields(block: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in block.splitlines():
        if ":" not in line:
            continue
        colon_idx = line.index(":")
        raw_key = line[:colon_idx]
        value = line[colon_idx + 1:]
        # Strip parameters: "SUMMARY;ENCODING=..." -> "SUMMARY"
        key = raw_key.split(";")[0]
        if key not in fields:
            fields[key] = value
    return fields


# ------------------------------------------------------------------------------
# MARK: - Date Parsing
# ------------------------------------------------------------------------------

def _parse_date(date_string: str) -> datetime | None:
    s = date_string.strip()
    if not s:
        return None

    # UTC datetime: 20251113T010000Z
    try:
        return datetime.strptime(s, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        pass

    # Local datetime: 20251113T010000
    try:
        return datetime.strptime(s, "%Y%m%dT%H%M%S").replace(tzinfo=timezone.utc)
    except ValueError:
        pass

    # Date only: 20251113
    try:
        return datetime.strptime(s, "%Y%m%d").replace(tzinfo=timezone.utc)
    except ValueError:
        pass

    return None


# ------------------------------------------------------------------------------
# MARK: - Content Cleaning
# ------------------------------------------------------------------------------

def _clean_description(raw: str) -> str:
    cleaned = raw.replace("\\n", "\n")
    # Strip Aggie Life footer: "---\nEvent Details: <url>"
    if "\n---\n" in cleaned:
        cleaned = cleaned[:cleaned.index("\n---\n")]
    return cleaned.strip()


def _clean_location(raw: str) -> str:
    trimmed = raw.strip()
    if "sign in to download" in trimmed.lower():
        return "TBD"
    if "private location" in trimmed.lower():
        return "TBD"
    return trimmed if trimmed else "TBD"


# ------------------------------------------------------------------------------
# MARK: - Authenticated Location Scraping
# ------------------------------------------------------------------------------

def scrape_event_location(event_url: str) -> str | None:
    """
    Scrapes a single Aggie Life event page using the stored session cookie
    to extract a private location from the JSON-LD structured data.

    Returns the location name string, or None if not found / cookie expired.
    """
    session_cookie = os.environ.get("AGGIELIFE_SESSION", "").strip()
    if not session_cookie:
        return None

    try:
        resp = requests.get(
            event_url,
            headers={"User-Agent": "Mozilla/5.0"},
            cookies={"CG.SessionID": session_cookie},
            timeout=15,
            allow_redirects=True,
        )
        resp.raise_for_status()

        # Extract location from JSON-LD structured data
        import json
        match = re.search(
            r'<script type="application/ld\+json">(.*?)</script>',
            resp.text,
            re.DOTALL,
        )
        if not match:
            return None

        data = json.loads(match.group(1))
        location = data.get("location", {})
        name = location.get("name", "") if isinstance(location, dict) else ""

        # Reject placeholder values
        if not name or "sign in" in name.lower() or "private location" in name.lower():
            return None

        return name.strip()

    except Exception as e:
        logger.warning(f"Failed to scrape location from {event_url}: {e}")
        return None


# ------------------------------------------------------------------------------
# MARK: - Organizer Extraction
# ------------------------------------------------------------------------------

def _extract_organizer_name(block: str) -> str | None:
    for line in block.splitlines():
        if not line.startswith("ORGANIZER"):
            continue
        match = re.search(r'CN="([^"]+)"', line)
        if match:
            return match.group(1)
    return None


def _extract_organizer_url(block: str) -> str | None:
    for line in block.splitlines():
        if not line.startswith("ORGANIZER"):
            continue
        match = re.search(r'(https://\S+)', line)
        if match:
            return match.group(1)
    return None


def _check_if_official(organizer_url: str | None, organizer_name: str | None) -> bool:
    # No organizer → posted directly by UC Davis (official)
    if not organizer_name:
        return True
    # Check if organizer is a known official campus entity
    name_lower = organizer_name.lower()
    if any(o in name_lower for o in OFFICIAL_ORGANIZERS):
        return True
    # Has a specific organizer that isn't on the whitelist → club event
    return False


# ------------------------------------------------------------------------------
# MARK: - Category / Tag Extraction
# ------------------------------------------------------------------------------

def _extract_category(name: str, block: str) -> str | None:
    prefix = f"CATEGORIES;X-CG-CATEGORY={name}:"
    for line in block.splitlines():
        if line.startswith(prefix):
            return line[len(prefix):]
    return None


def _extract_tags(block: str) -> list[str]:
    raw = _extract_category("event_tags", block)
    if not raw:
        return []
    return [t.strip() for t in raw.split(",") if t.strip()]


# ------------------------------------------------------------------------------
# MARK: - Event Cleaning (mirror of CampusViewModel.cleanEvents)
# ------------------------------------------------------------------------------

def _clean_events(events: list[dict]) -> list[dict]:
    now = datetime.now(tz=timezone.utc)

    # Only filter out past events; let the client control the time window
    return [
        e for e in events
        if e["startDate"] >= now
    ]
