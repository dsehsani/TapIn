#
#  ical_parser.py
#  TapInApp - Events Backend
#
#  Created by Claude for Darius Ehsani on 3/1/26.
#
#  MARK: - iCal Parser
#  Parses raw .ics text into a list of event dictionaries
#  matching the iOS CampusEvent JSON contract.
#

import re
import uuid
from datetime import datetime, timezone
from typing import Optional

from bs4 import BeautifulSoup
from icalendar import Calendar


OFFICIAL_ORGANIZERS = [
    "center for student involvement",
    "cross cultural center",
    "women's resources and research center",
    "guardian scholars program",
    "asucd",
    "student affairs",
]


def _check_if_official(organizer_name: Optional[str]) -> bool:
    """Determine if an event is from an official UC Davis organization."""
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
# MARK: - HTML Sanitization
# ------------------------------------------------------------------------------

def strip_html(html_text: str) -> str:
    """
    Strip HTML tags from text, converting <br> to newlines
    and preserving readable content.
    """
    if not html_text:
        return ""

    # Convert <br> variants to newlines before stripping
    text = re.sub(r"<br\s*/?>", "\n", html_text, flags=re.IGNORECASE)

    # Use BeautifulSoup to strip remaining HTML
    soup = BeautifulSoup(text, "html.parser")
    clean = soup.get_text(separator="\n")

    # Normalize whitespace: collapse multiple blank lines, strip trailing spaces
    clean = re.sub(r"\n{3,}", "\n\n", clean)
    clean = re.sub(r"[ \t]+\n", "\n", clean)

    return clean.strip()


# ------------------------------------------------------------------------------
# MARK: - AggieLife Footer Stripping
# ------------------------------------------------------------------------------

def strip_aggielife_footer(description: str) -> str:
    """
    Remove the '---\\nEvent Details:' footer that AggieLife appends
    to event descriptions.
    """
    # Match a line of dashes followed by "Event Details:" and everything after
    pattern = r"\n?-{3,}\s*\n\s*Event Details:.*"
    return re.sub(pattern, "", description, flags=re.DOTALL).strip()


# ------------------------------------------------------------------------------
# MARK: - Organizer Extraction
# ------------------------------------------------------------------------------

def extract_organizer(component) -> Optional[str]:
    """
    Extract the organizer name from an iCal VEVENT component.

    Priority:
    1. ORGANIZER CN parameter
    2. "Hosted by:" pattern in DESCRIPTION
    3. None
    """
    # Try ORGANIZER CN param
    organizer = component.get("ORGANIZER")
    if organizer:
        cn = organizer.params.get("CN", "")
        if cn and not cn.startswith("mailto:"):
            return str(cn)

    # Try extracting from description
    description = str(component.get("DESCRIPTION", ""))
    match = re.search(r"Hosted by:\s*(.+)", description, re.IGNORECASE)
    if match:
        return match.group(1).strip()

    return None


# ------------------------------------------------------------------------------
# MARK: - Category / Tag Extraction
# ------------------------------------------------------------------------------

def extract_categories(component) -> list[str]:
    """
    Extract categories from an iCal VEVENT.

    Handles:
    - Standard CATEGORIES property
    - AggieLife's X-CG-CATEGORY with LABEL param
    """
    tags = []

    # Standard CATEGORIES
    categories = component.get("CATEGORIES")
    if categories:
        if isinstance(categories, list):
            for cat_list in categories:
                tags.extend([str(c) for c in cat_list.cats])
        else:
            tags.extend([str(c) for c in categories.cats])

    # AggieLife custom X-CG-CATEGORY
    for key in component.keys():
        if key == "X-CG-CATEGORY":
            val = component[key]
            # Could be a list of vText items
            if isinstance(val, list):
                for v in val:
                    label = v.params.get("LABEL", str(v))
                    tags.append(str(label))
            else:
                label = val.params.get("LABEL", str(val))
                tags.append(str(label))

    # Deduplicate while preserving order
    seen = set()
    unique_tags = []
    for t in tags:
        t_lower = t.lower()
        if t_lower not in seen:
            seen.add(t_lower)
            unique_tags.append(t)

    return unique_tags


def classify_event_type(tags: list[str], title: str) -> str:
    """
    Derive a high-level event type from tags and title.
    Falls back to 'General' if nothing matches.
    """
    keyword_map = {
        "career": "Career",
        "academic": "Academic",
        "cultural": "Cultural",
        "social": "Social",
        "sports": "Sports",
        "athletic": "Sports",
        "recreation": "Sports",
        "workshop": "Workshop",
        "seminar": "Academic",
        "lecture": "Academic",
        "meeting": "Meeting",
        "fundraiser": "Fundraiser",
        "volunteer": "Volunteer",
        "arts": "Arts",
        "music": "Arts",
        "performance": "Arts",
        "health": "Health",
        "wellness": "Health",
        "food": "Food",
        "networking": "Career",
    }

    # Check tags first
    for tag in tags:
        for keyword, event_type in keyword_map.items():
            if keyword in tag.lower():
                return event_type

    # Check title
    title_lower = title.lower()
    for keyword, event_type in keyword_map.items():
        if keyword in title_lower:
            return event_type

    return "General"


# ------------------------------------------------------------------------------
# MARK: - Date Helpers
# ------------------------------------------------------------------------------

def to_utc_iso(dt) -> Optional[str]:
    """
    Convert an icalendar date/datetime to a UTC ISO 8601 string.
    Handles date objects (all-day events) and datetime objects.
    """
    if dt is None:
        return None

    # Get the actual value from vDDDTypes wrapper
    if hasattr(dt, "dt"):
        dt = dt.dt

    # If it's a date (not datetime), treat as midnight UTC
    if not isinstance(dt, datetime):
        return datetime(dt.year, dt.month, dt.day, tzinfo=timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )

    # If timezone-aware, convert to UTC
    if dt.tzinfo is not None:
        dt = dt.astimezone(timezone.utc)
    else:
        # Assume UTC if no timezone info
        dt = dt.replace(tzinfo=timezone.utc)

    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


# ------------------------------------------------------------------------------
# MARK: - Location Cleanup
# ------------------------------------------------------------------------------

def clean_location(location: Optional[str]) -> str:
    """
    Clean up the location string.
    Replaces 'Sign in to download' with 'TBD'.
    """
    if not location:
        return "TBD"

    loc = str(location).strip()
    if not loc or "sign in" in loc.lower():
        return "TBD"

    return loc


# ------------------------------------------------------------------------------
# MARK: - Main Parser
# ------------------------------------------------------------------------------

def parse_ical(ical_text: str, source_name: str = "Unknown") -> list[dict]:
    """
    Parse raw .ics text into a list of event dictionaries
    matching the iOS CampusEvent JSON contract.

    Args:
        ical_text: Raw .ics file content
        source_name: Name of the feed source (for logging/debugging)

    Returns:
        List of event dicts ready for JSON serialization
    """
    events = []

    try:
        cal = Calendar.from_ical(ical_text)
    except Exception as e:
        print(f"[ICalParser] Failed to parse calendar from {source_name}: {e}")
        return events

    for component in cal.walk():
        if component.name != "VEVENT":
            continue

        try:
            title = str(component.get("SUMMARY", "Untitled Event"))

            # Parse description: strip HTML, then strip AggieLife footer
            raw_desc = str(component.get("DESCRIPTION", ""))
            description = strip_html(raw_desc)
            description = strip_aggielife_footer(description)

            # Dates
            start_date = to_utc_iso(component.get("DTSTART"))
            end_date = to_utc_iso(component.get("DTEND"))

            if not start_date:
                continue  # Skip events with no start date

            # Location
            location = clean_location(component.get("LOCATION"))

            # Organizer
            organizer_name = extract_organizer(component)

            # Categories / Tags
            tags = extract_categories(component)
            event_type = classify_event_type(tags, title)

            # URLs
            event_url = str(component.get("URL", "")) or None
            organizer_url = None

            # Generate a stable ID from UID or title+date
            uid = str(component.get("UID", ""))
            event_id = uid if uid else str(uuid.uuid5(uuid.NAMESPACE_URL, f"{title}-{start_date}"))

            # Build club acronym from organizer name
            club_acronym = None
            if organizer_name:
                words = organizer_name.split()
                if len(words) >= 2:
                    club_acronym = "".join(w[0].upper() for w in words if w[0].isalpha())

            is_official = _check_if_official(organizer_name)

            event_dict = {
                "id": event_id,
                "title": title,
                "description": description,
                "startDate": start_date,
                "endDate": end_date,
                "location": location,
                "isOfficial": is_official,
                "organizerName": organizer_name,
                "clubAcronym": club_acronym,
                "eventType": event_type,
                "tags": [t.lower() for t in tags],
                "eventURL": event_url,
                "organizerURL": organizer_url,
                "aiSummary": None,
                "aiBulletPoints": [],
            }

            events.append(event_dict)

        except Exception as e:
            summary = component.get("SUMMARY", "unknown")
            print(f"[ICalParser] Skipping event '{summary}' from {source_name}: {e}")
            continue

    return events
