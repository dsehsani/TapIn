#
#  aggie_life_service.py
#  TapInApp - Backend Server
#
#  MARK: - Aggie Life iCal Fetcher & Parser
#  Python port of the iOS ICalParser.swift + AggieLifeService.swift.
#  Fetches the Aggie Life iCal feed and returns a list of event dicts.
#

import re
import urllib.request
import hashlib
import uuid
from datetime import datetime, timezone, timedelta


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
    req = urllib.request.Request(
        AGGIE_LIFE_URL,
        headers={"User-Agent": "TapIn-Backend/1.0"}
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read().decode("utf-8", errors="replace")


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
    return trimmed if trimmed else "TBD"


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
    if organizer_url and "/admin/" in organizer_url:
        return True
    if organizer_name:
        name_lower = organizer_name.lower()
        return any(o in name_lower for o in OFFICIAL_ORGANIZERS)
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
    cutoff = now + timedelta(days=7)

    return [
        e for e in events
        if "meeting" not in e["title"].lower()
        and e["startDate"] >= now
        and e["startDate"] <= cutoff
    ]
