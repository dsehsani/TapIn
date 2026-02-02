# Flask Wordle Leaderboard Server - Requirements

Create a Flask-based Python server for a Wordle leaderboard system with the following requirements:

## IMPORTANT CONSTRAINTS

- The user has an EXISTING iOS Wordle app in Xcode with a working dashboard, games, and calendar system
- You can suggest UI changes and small code modifications to existing files, but do NOT do a complete rewrite or restructure the app
- Keep changes minimal and focused on integrating the leaderboard feature
- For ALL iOS/Swift/Xcode code (new or modified):
  * Provide the code as text/snippets
  * Instruct the user to manually add/modify it in Xcode (don't create files directly - it causes Xcode bugs)
  * Ask to see relevant existing code if needed for compatibility

## TECHNICAL REQUIREMENTS

- Python 3.10-3.13
- Flask web service with Blueprint for API handling
- File structure must include: api/, services/, models.py organization
- Designed to eventually deploy to Google App Engine with app.yaml and .gcloudignore (but run locally for now)
- In-memory storage for Milestone 0 (will migrate to Firestore Datastore later)
- Include requirements.txt with necessary dependencies

## LEADERBOARD FUNCTIONALITY

- Daily leaderboards specific to each date's Wordle puzzle
- Store scores with:
  * Auto-generated username (Adjective+Noun format like "SwiftFalcon", "BraveOtter")
  * Number of guesses (1-6)
  * Time taken in seconds
  * Date of the puzzle
- Leaderboard returns top 5 players for a specific day
- Display format: Username, number of tries (represented with green block emoji 🟩), rank
- Daily leaderboard that conceptually resets each day

## API ENDPOINTS NEEDED

- POST endpoint to submit a score
- GET endpoint to retrieve leaderboard for a specific date

## DELIVERABLES

1. Complete Flask server code with proper structure (api/, services/, models.py)
2. app.yaml and .gcloudignore files for future Google App Engine deployment
3. requirements.txt
4. Instructions for running the server locally
5. Swift code snippets for iOS integration (provided as text for manual addition)
6. Clear documentation on how to integrate with the existing Xcode project
