  # Task: Fix "For You" events showing the same results as "All Events"
                                                                                             
  The "For You" tab in NewsView is supposed to show personalized events based on the user's
  interests, but the events carousel looks identical to the "All Events" tab. The issue is in
   the event scoring logic in ForYouFeedEngine.swift.

  Current behavior: Events in "For You" are ordered almost identically to "All Events"
  because the scoring weights don't differentiate enough when a user has interests selected.

  **What to fix in Services/ForYouFeedEngine.swift:**

  The scoreEvent() method already has two code paths (one when user has interests, one
  without). The problem is that even with the interest-weighted path, events that don't match
   ANY of the user's interests still appear prominently because they get urgency points.

  **To make "For You" events meaningfully different from "All Events":**
  1. Events matching user interests should be strongly boosted
  2. Events matching zero interests should be pushed much further down or filtered out
  entirely when the user has 3+ interests
  3. Consider capping the number of non-matching events shown (e.g., only include
  non-matching events if there aren't enough matching ones to fill the carousel)

  **The relevant files are:**
  - TapInApp/TapInApp/Services/ForYouFeedEngine.swift — scoreEvent() method and buildFeed()
  method
  - The user's interests come from AppState.shared.currentUser?.interests
  - Events are CampusEvent objects with fields: title, eventType, organizerName, tags, date,
  dateUrgency
  - Interest keyword matching is in eventInterestKeywordScore() which checks event text
  against keyword lists in interestKeywords dictionary

  **Acceptance criteria:**
  - A user with interests like ["Sports", "Music & Concerts", "Food & Dining"] should see
  noticeably different events than a user with ["Science & Tech", "Career & Professional"]
  - "For You" events should NOT just be the same list as "All Events" sorted by date
  - If no events match the user's interests at all, it's fine to fall back to showing all
  events
