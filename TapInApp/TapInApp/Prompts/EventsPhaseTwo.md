# Role and Context
You are an expert backend developer. I am building a campus event aggregator app for UC Davis and am currently entering Phase 2 of development. 

My goal is to fetch, parse, and normalize event data from multiple campus `.iCal` (ICS) feeds (specifically from CampusGroups/AggieLife and the UC Davis Master Calendar) into a clean, unified JSON structure that my frontend can easily consume.

# Task
Write a robust script (using Node.js with a library like `node-ical`, or Python with `icalendar`) that fetches one or more `.iCal` URLs, parses the events, and maps them to my required JSON schema. 

# Required JSON Schema per Event
Please ensure the final output maps exactly to these keys:
- `title` (String)
- `host` (String)
- `date` (String, YYYY-MM-DD format)
- `startTime` (String, formatted like "3:00 PM" or ISO format)
- `endTime` (String, formatted like "4:30 PM" or ISO format)
- `location` (String)
- `description` (String)
- `type` (String - e.g., "Cultural", "Academic")
- `tags` (Array of Strings - optional)

# Edge Cases & Gotchas to Handle
When writing the parser, please account for the following quirks typical of university iCal feeds:
1. **Host Extraction:** The `ORGANIZER` field might just be a system email. Write logic that checks if the host's name is at the top/bottom of the `DESCRIPTION` (e.g., "Hosted by: [Club Name]") and extracts it. Fall back to the `ORGANIZER` name if available.
2. **HTML Sanitization:** The `DESCRIPTION` field will likely contain embedded HTML tags (like `<br>`, `<strong>`, or `<a>`). Please strip or sanitize these so the output is clean text, while preserving line breaks.
3. **Categories Splitting:** Feed `CATEGORIES` usually lump event types and tags together. Write logic to map these to the `type` and `tags` arrays in my schema. 
4. **Timezones:** Ensure the dates and times are correctly converted/handled for Pacific Time (PT), as this is for UC Davis.

Please provide the complete script, along with instructions on any dependencies I need to install. Keep the code modular so I can easily add new feed URLs in the future.
