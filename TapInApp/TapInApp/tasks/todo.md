#  To-Do: Like Feature Debugging (Backend-Only)

## Diagnosis Steps

- [x] Add `/api/social/debug/likes` endpoint — inspect raw Firestore state for any item
- [x] Add `/api/social/debug/test-like` endpoint — end-to-end like/read/unlike smoke test
- [x] Deploy backend to Cloud Run
- [x] Run smoke test — `all_passed: true`
- [x] Diagnose root cause via Cloud Run logs

## Root Cause Found

**`SECRET_KEY` was empty in Cloud Run.** The value in Secret Manager was an empty string, which
matched the insecure defaults list in `auth_service.py:_secret_key()`. On Cloud Run, `K_SERVICE`
env var is set, so the code detected production and raised `RuntimeError` — crashing every
authenticated endpoint (`/api/social/like`, `/api/social/like-status`, `/api/social/like-status/batch`)
with 500 errors.

**Result:** Every like, like-status, and batch call from the iOS app was failing silently.
The iOS code caught the errors and fell back to default values (`liked: false, likeCount: 0`).

## Fix Applied

- [x] Generated a strong 86-char `SECRET_KEY` via `secrets.token_urlsafe(64)`
- [x] Set as env var on Cloud Run (revision `tapin-backend-00090-nlw`)
- [x] Verified: fake token → 401, missing auth → 401, smoke test → all_passed
- [x] No key values displayed or logged during the process

## Important Side Effect

**All existing user JWTs are now invalid** — the old tokens were signed with an empty key,
the new tokens are signed with the real key. Users will be prompted to re-authenticate.
The iOS app's `restoreSession()` will get 401 from `/api/users/me`, triggering the sign-in flow.

## Remaining: Remove Debug Endpoints Before Production

- [ ] Remove `/api/social/debug/likes` and `/api/social/debug/test-like` once verified
