#  Lessons

## 2026-03-11: SECRET_KEY was empty on Cloud Run — all auth crashed

**Pattern:** Environment variables stored in Secret Manager can be empty or placeholder values.
The code's safety check (`_secret_key()` in auth_service.py) correctly caught this in production,
but the 500 error was swallowed by the iOS client's generic error handling — making it look like
"likes don't work between users" rather than "all auth is broken."

**Rule:** After every Cloud Run deploy, verify critical env vars are set and non-default:
```bash
# Quick health check for auth
curl -s <url>/api/social/like-status?content_type=article&content_id=test \
  -H 'Authorization: Bearer fake' -w "\nHTTP: %{http_code}\n"
# Should return 401, not 500
```

**Rule:** When a feature "doesn't work between users," first check Cloud Run logs for 500 errors
before assuming iOS-side bugs. Use `gcloud logging read` with severity>=ERROR.

**Rule:** Never trust Secret Manager values without verification. The permission model allows
writing empty secrets. Always verify after setting:
```bash
gcloud secrets versions access latest --secret=KEY_NAME 2>/dev/null | wc -c
```
