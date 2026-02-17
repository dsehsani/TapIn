#
#  claude.py
#  TapInApp - Wordle Leaderboard Server
#
#  MARK: - Claude API Proxy Endpoints
#  Proxies requests from the iOS app to the Anthropic Claude API.
#  Keeps the API key server-side so it never ships in the app bundle.
#
#  Endpoints:
#  - POST /api/claude/summarize  - Summarize an event description
#  - POST /api/claude/chat       - General-purpose Claude chat
#  - GET  /api/claude/health     - Health check
#

import os
from flask import Blueprint, request, jsonify
import anthropic


# ------------------------------------------------------------------------------
# MARK: - Blueprint Setup
# ------------------------------------------------------------------------------

claude_bp = Blueprint("claude", __name__, url_prefix="/api/claude")

# Claude model to use for all requests
CLAUDE_MODEL = "claude-sonnet-4-5-20250929"

# System prompt for event summaries
SUMMARY_SYSTEM_PROMPT = (
    "You are a helpful assistant for UC Davis students. "
    "Summarize the following campus event description in 1-2 concise sentences. "
    "Focus on what the event is, who it's for, and why a student might attend. "
    "Keep it under 120 characters if possible. Do not use emojis."
)


def _get_client() -> anthropic.Anthropic | None:
    """Returns an Anthropic client if the API key is configured."""
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return None
    return anthropic.Anthropic(api_key=api_key)


# ------------------------------------------------------------------------------
# MARK: - POST /api/claude/summarize
# ------------------------------------------------------------------------------

@claude_bp.route("/summarize", methods=["POST"])
def summarize():
    """
    Summarize an event description using Claude.

    Request Body (JSON):
        {
            "description": str   # The full event description text
        }

    Response (200 OK):
        {
            "success": true,
            "summary": "A concise 1-2 sentence summary..."
        }

    Error Response (400/500/503):
        {
            "success": false,
            "error": "Error message"
        }
    """
    data = request.get_json()
    if not data or "description" not in data:
        return jsonify({
            "success": False,
            "error": "Missing required field: description"
        }), 400

    description = data["description"].strip()
    if not description:
        return jsonify({
            "success": False,
            "error": "description must not be empty"
        }), 400

    client = _get_client()
    if client is None:
        return jsonify({
            "success": False,
            "error": "ANTHROPIC_API_KEY is not configured on the server"
        }), 503

    try:
        message = client.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=200,
            system=SUMMARY_SYSTEM_PROMPT,
            messages=[
                {"role": "user", "content": description}
            ]
        )

        summary = message.content[0].text.strip()

        return jsonify({
            "success": True,
            "summary": summary
        }), 200

    except anthropic.AuthenticationError:
        return jsonify({
            "success": False,
            "error": "Invalid API key"
        }), 503

    except anthropic.RateLimitError:
        return jsonify({
            "success": False,
            "error": "Rate limit exceeded, try again later"
        }), 429

    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Claude API error: {str(e)}"
        }), 500


# ------------------------------------------------------------------------------
# MARK: - POST /api/claude/chat
# ------------------------------------------------------------------------------

@claude_bp.route("/chat", methods=["POST"])
def chat():
    """
    General-purpose Claude chat endpoint for future features.

    Request Body (JSON):
        {
            "message": str,              # User message (required)
            "system_prompt": str,        # Optional system prompt override
            "max_tokens": int            # Optional, default 300, max 1000
        }

    Response (200 OK):
        {
            "success": true,
            "response": "Claude's response text..."
        }
    """
    data = request.get_json()
    if not data or "message" not in data:
        return jsonify({
            "success": False,
            "error": "Missing required field: message"
        }), 400

    user_message = data["message"].strip()
    if not user_message:
        return jsonify({
            "success": False,
            "error": "message must not be empty"
        }), 400

    system_prompt = data.get("system_prompt", "You are a helpful assistant for UC Davis students.")
    max_tokens = min(data.get("max_tokens", 300), 1000)

    client = _get_client()
    if client is None:
        return jsonify({
            "success": False,
            "error": "ANTHROPIC_API_KEY is not configured on the server"
        }), 503

    try:
        message = client.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=max_tokens,
            system=system_prompt,
            messages=[
                {"role": "user", "content": user_message}
            ]
        )

        response_text = message.content[0].text.strip()

        return jsonify({
            "success": True,
            "response": response_text
        }), 200

    except anthropic.AuthenticationError:
        return jsonify({
            "success": False,
            "error": "Invalid API key"
        }), 503

    except anthropic.RateLimitError:
        return jsonify({
            "success": False,
            "error": "Rate limit exceeded, try again later"
        }), 429

    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Claude API error: {str(e)}"
        }), 500


# ------------------------------------------------------------------------------
# MARK: - GET /api/claude/health
# ------------------------------------------------------------------------------

@claude_bp.route("/health", methods=["GET"])
def health():
    """
    Health check for the Claude proxy.

    Response (200 OK):
        {
            "status": "healthy",
            "service": "claude-proxy",
            "api_key_configured": true/false
        }
    """
    api_key = os.environ.get("ANTHROPIC_API_KEY")

    return jsonify({
        "status": "healthy",
        "service": "claude-proxy",
        "api_key_configured": bool(api_key)
    }), 200
