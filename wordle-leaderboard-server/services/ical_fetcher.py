#
#  ical_fetcher.py
#  TapInApp - Events Backend
#
#  Created by Claude for Darius Ehsani on 3/1/26.
#
#  MARK: - iCal Feed Fetcher
#  Fetches raw .ics content from configured feed URLs.
#  Skips failed feeds gracefully so one bad source doesn't break everything.
#

import requests

from .ical_parser import parse_ical


# ------------------------------------------------------------------------------
# MARK: - Feed Sources
# ------------------------------------------------------------------------------

FEED_SOURCES = [
    {
        "name": "AggieLife",
        "url": "https://aggielife.ucdavis.edu/ical/ucdavis/ical_ucdavis.ics",
    },
    {
        "name": "UC Davis Library Events",
        "url": "https://events.library.ucdavis.edu/calendar.ics",
    },
]

# Request timeout in seconds
FETCH_TIMEOUT = 15


# ------------------------------------------------------------------------------
# MARK: - Fetcher
# ------------------------------------------------------------------------------

def fetch_and_parse_all_feeds() -> list[dict]:
    """
    Fetch all configured iCal feeds and parse them into event dicts.

    Returns:
        Combined list of event dicts from all feeds.
        Failed feeds are skipped with a warning log.
    """
    all_events = []

    for source in FEED_SOURCES:
        name = source["name"]
        url = source["url"]

        try:
            print(f"[ICalFetcher] Fetching {name} from {url}...")
            response = requests.get(url, timeout=FETCH_TIMEOUT)
            response.raise_for_status()

            ical_text = response.text
            events = parse_ical(ical_text, source_name=name)
            print(f"[ICalFetcher] Parsed {len(events)} events from {name}")
            all_events.extend(events)

        except requests.exceptions.Timeout:
            print(f"[ICalFetcher] Timeout fetching {name} ({url})")
        except requests.exceptions.RequestException as e:
            print(f"[ICalFetcher] Failed to fetch {name}: {e}")
        except Exception as e:
            print(f"[ICalFetcher] Unexpected error processing {name}: {e}")

    return all_events
