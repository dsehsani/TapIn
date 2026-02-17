# Google Cloud Setup for TapIn Backend

This document covers everything the Google Cloud team member needs to know about deploying and configuring the TapIn backend on Google App Engine.

---

## What the Backend Does

The Flask backend serves two main features:

1. **Leaderboard API** (`/api/leaderboard/...`) - Wordle leaderboard score tracking
2. **Claude AI Proxy** (`/api/claude/...`) - Proxies requests to the Anthropic Claude API so the iOS app never touches the API key directly

---

## Prerequisites

- Google Cloud project with App Engine enabled
- `gcloud` CLI installed and authenticated
- An **Anthropic API key** (ask Darius)

---

## Setting the Claude API Key (IMPORTANT)

The AI features require an environment variable called `CLAUDE_API_KEY`. There are two ways to set this on App Engine:

### Option A: Set it in `app.yaml` (simple but less secure)

The `app.yaml` file already has a placeholder:

```yaml
env_variables:
  ENV: "production"
  CLAUDE_API_KEY: "SET_IN_CLOUD_CONSOLE"
```

Replace `"SET_IN_CLOUD_CONSOLE"` with the actual API key before deploying. **Do NOT commit the real key to git** - only set it locally before running `gcloud app deploy`.

### Option B: Use Google Secret Manager (recommended for production)

1. Store the key in Secret Manager:
   ```bash
   echo -n "sk-ant-your-key-here" | gcloud secrets create CLAUDE_API_KEY --data-file=-
   ```
2. Grant the App Engine service account access:
   ```bash
   gcloud secrets add-iam-policy-binding CLAUDE_API_KEY \
     --member="serviceAccount:YOUR_PROJECT_ID@appspot.gserviceaccount.com" \
     --role="roles/secretmanager.secretAccessor"
   ```
3. The backend code would need a small update to read from Secret Manager instead of `os.environ`. For now, Option A works fine for a class project.

---

## Deploying to App Engine

From the `tapin-backend/` directory:

```bash
gcloud app deploy
```

This uses the `app.yaml` configuration which is already set up with:
- **Runtime:** Python 3.11
- **Entry point:** `gunicorn -b :$PORT app:app`
- **Instance class:** F1 (free tier eligible)
- **Scaling:** 0-2 instances, auto-scaling

---

## After Deployment

Once deployed, the backend will be available at:

```
https://YOUR_PROJECT_ID.appspot.com
```

### Endpoints to verify:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Root - shows available endpoints |
| GET | `/api/claude/health` | Check if Claude API key is configured |
| GET | `/api/leaderboard/health` | Leaderboard health check |
| POST | `/api/claude/summarize` | Summarize an event (AI feature) |
| POST | `/api/claude/chat` | General Claude chat (AI feature) |

### Quick health check after deploy:

```bash
curl https://YOUR_PROJECT_ID.appspot.com/api/claude/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "claude-proxy",
  "api_key_configured": true
}
```

If `api_key_configured` is `false`, the `CLAUDE_API_KEY` environment variable was not set correctly.

---

## What Darius Needs From You

Once deployed, Darius needs the **production URL** (e.g., `https://YOUR_PROJECT_ID.appspot.com`) so he can update the iOS app's `APIConfig.swift` to point to the live server instead of `localhost:8080`.

---

## Rate Limiting

The backend has built-in rate limiting for the Claude endpoints:
- **30 requests per hour** per IP address
- This is handled in the code, no cloud configuration needed

---

## Cost Notes

- **App Engine F1 instances:** Free tier covers ~28 instance-hours/day
- **Anthropic API:** Pay-per-use based on tokens. The summarize endpoint uses `claude-sonnet-4-5-20250929` with a max of 60 tokens per response, so costs should be minimal
- Auto-scaling is set to 0 min instances, so it scales to zero when not in use

---

## Files You Should Know About

| File | Purpose |
|------|---------|
| `app.yaml` | App Engine config (runtime, scaling, env vars) |
| `app.py` | Flask app entry point |
| `requirements.txt` | Python dependencies (installed automatically on deploy) |
| `.gcloudignore` | Files excluded from deployment (venv, .env, etc.) |
| `api/claude.py` | Claude proxy API endpoints |
| `services/claude_service.py` | Claude API logic, rate limiting, caching |
| `api/leaderboard.py` | Leaderboard API endpoints |

---

## Troubleshooting

**"CLAUDE_API_KEY environment variable is not set"**
- The API key wasn't set in `app.yaml` env_variables, or the deploy didn't pick it up. Redeploy with the key set.

**502 / 503 errors**
- Check App Engine logs: `gcloud app logs tail -s default`

**CORS errors from the iOS app**
- CORS is already configured to allow all origins. If issues persist, check that the iOS app is hitting the correct URL (https, not http).
