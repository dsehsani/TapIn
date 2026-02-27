# Prompt: Upgrade to Personalized AI News Summaries

**Role:** You are an expert iOS Developer (SwiftUI, MVVM) and Backend Systems Architect. 

**Objective:** Upgrade our current `DailyBriefingService` and `NewsViewModel` architecture to support **Personalized AI News Summaries**, while maintaining a fallback to global news.

**Current Context:** Currently, our app hits `GET {baseURL}/api/articles/daily-briefing` to fetch a generic summary. It caches the JSON in `UserDefaults` based on a same-day TTL (Pacific time). The UI displays a `DailyBriefingCard` with an expand/collapse animation and tappable bullet points. 

**New Requirements:**

1. **User Preferences Integration:** The iOS app needs to pass the user's selected interests (e.g., "Sports", "Arts", "Tech") from their onboarding/profile data to the backend. 
2. **API Update:** Modify the frontend API call to either use query parameters (`GET .../daily-briefing?interests=sports,tech`) or change to a `POST` request with a JSON body containing the user's data/token. 
3. **Cache Invalidation & Scoping:** Update the `UserDefaults` caching strategy. The cache key must now factor in the **User ID** or a **Hash of their current preferences**. If a user updates their preferences, the cache should invalidate so they get a fresh summary immediately. 
4. **Backend LLM Prompting Strategy (Conceptual):** Provide the system prompt template we need to use on our backend LLM to achieve this specific balance: *Always prioritize massive/notable global news first. Then, fill the remaining summary/bullet points with news highly tailored to the user's specific interests.*

**Tasks Required:**

* Provide the refactored Swift code for `DailyBriefingService.swift` to handle preference parameters and the new caching logic.
* Provide the refactored `NewsViewModel.swift` to pass user preferences into the service during the `fetchDailyBriefing()` call.
* Write the exact System Prompt we should give our backend AI (e.g., OpenAI/Gemini) to perfectly balance "World News" with "Personalized Interests."
* Ensure the response strictly maintains our existing UI state logic (`isBriefingLoading`, `briefingError`) and doesn't break the `DailyBriefingCard` visual components.
