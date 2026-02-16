# Backend Upgrade Plan: Firestore Integration (Milestone 1)

This document contains step-by-step instructions for upgrading the TapIn backend from in-memory storage to Google Cloud Firestore.

---

## Part 1: Google Cloud Setup (Your Responsibility)

Complete these steps before asking Claude to implement the code changes.

### 1.1 Create or Select a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the project dropdown at the top → "New Project"
3. Name it something like `tapin-app` or `tapin-production`
4. Note your **Project ID** (e.g., `tapin-app-12345`) — you'll need this later

### 1.2 Enable Required APIs

In the Cloud Console, navigate to **APIs & Services → Library** and enable:

1. **Cloud Firestore API**
2. **App Engine Admin API** (if not already enabled)

Or run these gcloud commands:
```bash
gcloud services enable firestore.googleapis.com
gcloud services enable appengine.googleapis.com
```

### 1.3 Create Firestore Database

1. Go to **Firestore** in the Cloud Console sidebar
2. Click "Create Database"
3. Choose **Native mode** (not Datastore mode) — Native mode is required for real-time features and better querying
4. Select a region close to your users (e.g., `us-west1` for California)
5. Choose "Start in production mode" (we'll set up security rules)

### 1.4 Set Up Authentication for Local Development

For your local Flask server to connect to Firestore, you need credentials:

1. Go to **IAM & Admin → Service Accounts**
2. Click "Create Service Account"
3. Name: `tapin-backend-dev`
4. Description: "Local development access for TapIn backend"
5. Click "Create and Continue"
6. Grant role: **Cloud Datastore User** (this covers Firestore)
7. Click "Done"
8. Click on the newly created service account
9. Go to **Keys** tab → "Add Key" → "Create new key"
10. Choose **JSON** format
11. Save the downloaded file as `service-account.json` in the `wordle-leaderboard-server/` directory

**IMPORTANT:** Add `service-account.json` to `.gitignore` immediately:
```bash
echo "service-account.json" >> wordle-leaderboard-server/.gitignore
```

### 1.5 Set Environment Variable for Local Development

Set this environment variable before running the local server:

**macOS/Linux:**
```bash
export GOOGLE_APPLICATION_CREDENTIALS="./service-account.json"
```

**Windows (PowerShell):**
```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS=".\service-account.json"
```

**Windows (CMD):**
```cmd
set GOOGLE_APPLICATION_CREDENTIALS=.\service-account.json
```

### 1.6 Install Google Cloud SDK (Windows)

The `gcloud` CLI is required to deploy to App Engine and manage your project.

#### Option A: Download Installer (Recommended)

1. Open Chrome and go to: https://cloud.google.com/sdk/docs/install#windows
2. Click **"Google Cloud CLI installer"** to download `GoogleCloudSDKInstaller.exe`
3. Run the installer:
   - Check "Install Bundled Python" (unless you have Python 3.8+ already)
   - Check "Add gcloud CLI to PATH"
   - Complete the installation
4. The installer will open a Command Prompt window automatically to complete setup

#### Option B: Download via Command Prompt

```cmd
:: Download the installer (run in any directory)
curl -o GoogleCloudSDKInstaller.exe https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe

:: Run the installer
GoogleCloudSDKInstaller.exe
```

### 1.7 Initialize gcloud CLI and Authenticate

After installation, open a **new Command Prompt window** (to pick up PATH changes):

```cmd
:: Verify installation
gcloud --version

:: Initialize gcloud (this opens a browser for authentication)
gcloud init
```

When prompted:
1. **"Log in to your Google account"** → Press `Y`, then sign in via Chrome
2. **"Pick a project"** → Select your project `tapin-app-487603`
3. **"Configure default region"** → Choose a region (e.g., `us-west1` for California)

Verify your configuration:
```cmd
gcloud config list
```

You should see:
```
[core]
account = your-email@gmail.com
project = tapin-app-487603
```

### 1.8 Create App Engine Application

App Engine must be initialized once per project. Run in Command Prompt:

```cmd
gcloud app create --project=tapin-app-487603
```

When prompted, select a region. **Important:** Choose the **same region** as your Firestore database (e.g., `us-west1`). This cannot be changed later.

You should see:
```
Creating App Engine application in project [tapin-app-487603] and region [us-west1]....done.
Success! The app is now created.
```

### 1.9 Verify App Engine Service Account (For Production)

When deployed to App Engine, the app automatically uses the App Engine default service account. Ensure it has Firestore access:

1. Go to **IAM & Admin → IAM** in Cloud Console (Chrome)
2. Look for `tapin-app-487603@appspot.gserviceaccount.com`
3. This should now exist after running `gcloud app create`
4. Verify it has **Cloud Datastore User** role
   - If missing: Click the pencil icon → "Add Another Role" → search "Cloud Datastore User" → Save

### 1.10 Update app.yaml with Project Configuration

Add your project ID to `app.yaml`:
```yaml
env_variables:
  ENV: "production"
  GCP_PROJECT: "tapin-app-487603"  # Your actual project ID
```

### 1.11 Firestore Security Rules (Optional but Recommended)

In **Firestore → Rules**, set basic rules:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only allow server-side access (no client-side)
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

This blocks all client-side access since your Flask backend handles all Firestore operations.

### 1.12 Verify Complete Setup

Open Command Prompt and run these commands to verify everything is configured:

```cmd
:: Check gcloud is working and authenticated
gcloud auth list

:: Verify project is set
gcloud config get-value project

:: Verify App Engine exists
gcloud app describe

:: Verify Firestore database exists
gcloud firestore databases list
```

**Expected output:**
- `gcloud auth list` → Shows your email with `ACTIVE` status
- `gcloud config get-value project` → Shows `tapin-app-487603`
- `gcloud app describe` → Shows your App Engine details including region
- `gcloud firestore databases list` → Shows `(default)` database

If all commands succeed, your Google Cloud setup is complete.

---

## Part 2: Code Implementation Instructions (For Claude)

The following sections contain specific implementation instructions. Execute these in order.

---

### Step 1: Update Dependencies

**File:** `wordle-leaderboard-server/requirements.txt`

**Action:** Add the Firestore client library

**Changes:**
- Add `google-cloud-firestore==2.14.0` to requirements.txt

---

### Step 2: Create Firestore Client Module

**File:** `wordle-leaderboard-server/services/firestore_client.py` (NEW FILE)

**Action:** Create a new module that initializes and provides the Firestore client

**Requirements:**
- Create a function `get_firestore_client()` that returns a Firestore client instance
- Support both local development (using service account JSON) and App Engine (using default credentials)
- Use environment variable `GCP_PROJECT` to specify project ID
- Handle initialization errors gracefully with logging
- Make the client a singleton to avoid creating multiple connections

**Structure:**
```
- Import google.cloud.firestore
- Import os for environment variables
- Create get_firestore_client() function
- Detect environment (local vs App Engine) using ENV variable
- Initialize client with appropriate credentials
- Return cached client instance
```

---

### Step 3: Create Firestore Repository Layer

**File:** `wordle-leaderboard-server/repositories/__init__.py` (NEW FILE)
**File:** `wordle-leaderboard-server/repositories/score_repository.py` (NEW FILE)

**Action:** Create a repository that abstracts Firestore operations for scores

**Requirements:**
- Create `ScoreRepository` class with methods:
  - `save_score(score: Score) -> Score` — saves a score document to Firestore
  - `get_scores_by_date(puzzle_date: str, limit: int = 100) -> List[Score]` — retrieves scores for a date
  - `delete_scores_by_date(puzzle_date: str) -> int` — deletes all scores for a date (for testing)

**Firestore Collection Design:**
```
Collection: "scores"
Document ID: Auto-generated or use Score.id (UUID)
Fields:
  - username: string
  - guesses: number
  - time_seconds: number
  - puzzle_date: string
  - created_at: timestamp (add this field)
```

**Indexing Considerations:**
- Create composite index on (puzzle_date, guesses, time_seconds) for efficient leaderboard queries
- Add `created_at` timestamp field for future features

**Query for Leaderboard:**
```python
scores_ref.where("puzzle_date", "==", date)
          .order_by("guesses")
          .order_by("time_seconds")
          .limit(limit)
```

---

### Step 4: Update Models

**File:** `wordle-leaderboard-server/models.py`

**Action:** Add Firestore serialization support and timestamp field

**Changes:**
- Add `created_at: datetime` field to `Score` dataclass (with default factory)
- Add `from_firestore(doc)` class method to create Score from Firestore document
- Update `to_dict()` to include `created_at` in ISO format
- Ensure all fields are Firestore-compatible types

---

### Step 5: Update Leaderboard Service

**File:** `wordle-leaderboard-server/services/leaderboard_service.py`

**Action:** Replace in-memory storage with Firestore repository

**Changes:**
- Remove `self._scores: Dict[str, List[Score]]` in-memory storage
- Import and use `ScoreRepository`
- Update `submit_score()` to call `repository.save_score()`
- Update `get_leaderboard()` to call `repository.get_scores_by_date()`
- Update `clear_scores()` to call `repository.delete_scores_by_date()`
- Keep `generate_username()` unchanged
- Keep `_format_guesses_emoji()` unchanged
- Remove `get_all_dates()` or update to query Firestore (optional)

**Important:** Maintain the same public interface so API endpoints don't need changes.

---

### Step 6: Add Environment Configuration

**File:** `wordle-leaderboard-server/config.py` (NEW FILE)

**Action:** Create centralized configuration management

**Requirements:**
- Create `Config` class with:
  - `ENV`: "development" or "production"
  - `GCP_PROJECT`: Google Cloud project ID
  - `USE_EMULATOR`: Boolean for local Firestore emulator (optional)
- Load values from environment variables with sensible defaults
- Add validation for required production settings

---

### Step 7: Update .gitignore

**File:** `wordle-leaderboard-server/.gitignore` (NEW FILE if doesn't exist)

**Action:** Ensure sensitive files are excluded

**Add these entries:**
```
# Service account credentials (NEVER commit)
service-account.json
*.json.backup

# Environment files
.env
.env.local

# Python
__pycache__/
*.py[cod]
venv/
```

---

### Step 8: Update .gcloudignore

**File:** `wordle-leaderboard-server/.gcloudignore`

**Action:** Exclude service account file from deployment

**Add:**
```
service-account.json
```

---

### Step 9: Add Health Check for Firestore

**File:** `wordle-leaderboard-server/api/leaderboard.py`

**Action:** Enhance health check to verify Firestore connectivity

**Changes:**
- Update `/health` endpoint to ping Firestore
- Return `"firestore": "connected"` or `"firestore": "disconnected"` in response
- Keep endpoint fast (use a simple operation like listing collections)

---

### Step 10: Create Firestore Index Configuration

**File:** `wordle-leaderboard-server/firestore.indexes.json` (NEW FILE)

**Action:** Define required composite indexes for efficient queries

**Content:**
```json
{
  "indexes": [
    {
      "collectionGroup": "scores",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "puzzle_date", "order": "ASCENDING" },
        { "fieldPath": "guesses", "order": "ASCENDING" },
        { "fieldPath": "time_seconds", "order": "ASCENDING" }
      ]
    }
  ]
}
```

**Deployment:** Run `gcloud firestore indexes create --project=YOUR_PROJECT` or indexes are auto-created on first query (with a delay).

---

### Step 11: Update Documentation

**File:** `wordle-leaderboard-server/README.md` (create if needed) or update `server_architecture.md`

**Action:** Document the new Firestore setup

**Include:**
- How to set up local development credentials
- Environment variables required
- How to deploy indexes
- Collection/document structure
- How to view data in Firebase Console

---

### Step 12: Local Testing Instructions

After implementation, test locally:

1. Ensure `GOOGLE_APPLICATION_CREDENTIALS` is set
2. Run `pip install -r requirements.txt`
3. Run `python app.py`
4. Test score submission:
   ```bash
   curl -X POST http://localhost:8080/api/leaderboard/score \
     -H "Content-Type: application/json" \
     -d '{"guesses": 4, "time_seconds": 120, "puzzle_date": "2026-02-15"}'
   ```
5. Test leaderboard fetch:
   ```bash
   curl http://localhost:8080/api/leaderboard/2026-02-15
   ```
6. Verify data appears in Firebase Console under Firestore

---

## Summary of Files Changed

| File | Action |
|------|--------|
| `requirements.txt` | Add google-cloud-firestore |
| `services/firestore_client.py` | NEW - Firestore client singleton |
| `repositories/__init__.py` | NEW - Package init |
| `repositories/score_repository.py` | NEW - Firestore CRUD operations |
| `models.py` | Add created_at, Firestore methods |
| `services/leaderboard_service.py` | Replace in-memory with repository |
| `config.py` | NEW - Environment configuration |
| `.gitignore` | Add service account exclusions |
| `.gcloudignore` | Add service account exclusion |
| `api/leaderboard.py` | Enhance health check |
| `firestore.indexes.json` | NEW - Index definitions |

---

## Architecture After Upgrade

```
┌─────────────────────────────────────────────────────────────┐
│                      iOS Client                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Google App Engine                           │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                  Flask Application                    │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │              API Layer (api/)                   │  │  │
│  │  │         leaderboard.py endpoints                │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                         │                             │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │           Service Layer (services/)             │  │  │
│  │  │  leaderboard_service.py (business logic)        │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                         │                             │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │        Repository Layer (repositories/)         │  │  │
│  │  │  score_repository.py (data access)              │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                         │                             │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │          Firestore Client (services/)           │  │  │
│  │  │  firestore_client.py (connection management)    │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ gRPC
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Google Cloud Firestore                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Collection: "scores"                                 │  │
│  │  ├── Document: {uuid}                                 │  │
│  │  │   ├── username: "SwiftFalcon"                      │  │
│  │  │   ├── guesses: 4                                   │  │
│  │  │   ├── time_seconds: 120                            │  │
│  │  │   ├── puzzle_date: "2026-02-15"                    │  │
│  │  │   └── created_at: Timestamp                        │  │
│  │  └── ...                                              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Rollback Plan

If issues occur after deployment:

1. The API endpoints remain unchanged, so the iOS app continues working
2. Revert code changes and redeploy with in-memory storage
3. Data in Firestore remains safe and can be migrated later

---

## Future Considerations (Not Part of This Upgrade)

- **User Authentication:** Link scores to authenticated users instead of random usernames
- **Rate Limiting:** Prevent score spam using Firestore transactions or Cloud Functions
- **Real-time Updates:** Use Firestore's real-time listeners for live leaderboard updates
- **Data Retention:** Implement automatic cleanup of old scores (Cloud Scheduler + Functions)
- **Analytics:** Track daily active users, popular puzzle dates, etc.
