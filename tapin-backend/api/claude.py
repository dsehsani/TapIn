#
#  claude.py
#  TapInApp - Backend Server
#
#  Created by Darius Ehsani on 2/12/26.
#
#  MARK: - Claude API Proxy Endpoints
#  These endpoints proxy requests to the Anthropic Claude API so the
#  API key never leaves the server. The iOS app calls these endpoints.
#
#  Endpoints:
#  - POST /api/claude/summarize   - Summarize an event description
#  - POST /api/claude/chat        - General-purpose Claude chat (for future features)
#  - GET  /api/claude/health      - Health check
#

from flask import Blueprint, request, jsonify
from middleware.auth_middleware import require_auth
from services.claude_service import claude_service


# ------------------------------------------------------------------------------
# MARK: - Blueprint Setup
# ------------------------------------------------------------------------------

claude_bp = Blueprint("claude", __name__, url_prefix="/api/claude")


# ------------------------------------------------------------------------------
# MARK: - POST /api/claude/summarize
# ------------------------------------------------------------------------------

@claude_bp.route("/summarize", methods=["POST"])
def summarize_event():
    """
    Summarize a campus event description using Claude.

    Request Body (JSON):
        {
            "description": str   # The event description text (required, max 5000 chars)
        }

    Response (200 OK):
        {
            "success": true,
            "summary": "A concise 1-2 sentence summary...",
            "cached": false,
            "remaining": 28
        }

    Error Response (429 Too Many Requests):
        {
            "success": false,
            "error": "Rate limit exceeded. Try again later.",
            "remaining": 0
        }

    Example curl:
        curl -X POST http://localhost:8080/api/claude/summarize \
             -H "Content-Type: application/json" \
             -d '{"description": "Join us for the annual Spring Career Fair..."}'
    """
    try:
        data = request.get_json()

        if not data:
            return jsonify({
                "success": False,
                "error": "Request body must be JSON"
            }), 400

        description = data.get("description")
        if not description:
            return jsonify({
                "success": False,
                "error": "Missing required field: description"
            }), 400

        # Get client IP for rate limiting
        client_ip = request.headers.get("X-Forwarded-For", request.remote_addr)

        result = claude_service.summarize_event(
            description=description,
            client_ip=client_ip
        )

        if "error" in result:
            status_code = result.pop("status_code", 500)
            return jsonify({"success": False, **result}), status_code

        return jsonify({"success": True, **result}), 200

    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
        }), 500


# ------------------------------------------------------------------------------
# MARK: - POST /api/claude/chat  (Future Use)
# ------------------------------------------------------------------------------

@claude_bp.route("/chat", methods=["POST"])
@require_auth
def chat():
    """
    General-purpose Claude chat endpoint for future features
    (e.g., campus Q&A, study help, etc.).
    Requires authentication via Bearer token.

    Request Body (JSON):
        {
            "message": str,           # User message (required)
            "max_tokens": int         # Optional, default 300, max 1000
        }

    Response (200 OK):
        {
            "success": true,
            "response": "Claude's response...",
            "remaining": 25
        }
    """
    try:
        data = request.get_json()

        if not data:
            return jsonify({
                "success": False,
                "error": "Request body must be JSON"
            }), 400

        message = data.get("message")
        if not message or not message.strip():
            return jsonify({
                "success": False,
                "error": "Missing required field: message"
            }), 400

        if len(message) > 2000:
            return jsonify({
                "success": False,
                "error": "Message too long (max 2000 chars)."
            }), 400

        # Rate limiting
        client_ip = request.headers.get("X-Forwarded-For", request.remote_addr)
        if not claude_service.rate_limiter.is_allowed(client_ip):
            return jsonify({
                "success": False,
                "error": "Rate limit exceeded. Try again later.",
                "remaining": 0
            }), 429

        # System prompt is server-controlled — never accept from client
        system_prompt = "You are a helpful assistant for UC Davis students using the TapIn app."
        max_tokens = min(data.get("max_tokens", 300), 1000)

        client = claude_service._get_client()
        response = client.messages.create(
            model="claude-sonnet-4-5-20250929",
            max_tokens=max_tokens,
            system=system_prompt,
            messages=[{"role": "user", "content": message}]
        )

        return jsonify({
            "success": True,
            "response": response.content[0].text.strip(),
            "remaining": claude_service.rate_limiter.remaining(client_ip)
        }), 200

    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
        }), 500


# ------------------------------------------------------------------------------
# MARK: - Health Check
# ------------------------------------------------------------------------------

@claude_bp.route("/health", methods=["GET"])
def health_check():
    """
    Health check for the Claude proxy service.

    Response (200 OK):
        {
            "status": "healthy",
            "service": "claude-proxy",
            "api_key_configured": true
        }
    """
    return jsonify({
        "status": "healthy",
        "service": "claude-proxy",
        "api_key_configured": claude_service.api_key is not None
    }), 200
