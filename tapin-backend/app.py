#
#  app.py
#  TapInApp - Backend Server
#
#  Created by Darius Ehsani on 2/2/26.
#
#  MARK: - Flask Application Entry Point
#  This is the main entry point for the TapIn Backend Flask server.
#
#  Architecture:
#  - Uses Flask application factory pattern
#  - Registers API blueprints for modular routing
#  - Configures CORS for iOS app communication
#  - Designed for local development and Google App Engine deployment
#
#  Running Locally:
#  - Install dependencies: pip install -r requirements.txt
#  - Run server: python app.py
#  - Server will be available at http://localhost:8080
#
#  Deployment:
#  - Deploy to Google App Engine: gcloud app deploy
#

from flask import Flask, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from api.leaderboard import leaderboard_bp
from api.claude import claude_bp
from api.events import events_bp
from api.articles import articles_bp
from api.users import users_bp

# Load environment variables from .env file (for local development)
load_dotenv()


# ------------------------------------------------------------------------------
# MARK: - Application Factory
# ------------------------------------------------------------------------------

def create_app() -> Flask:
    """
    Creates and configures the Flask application.

    This factory function:
    1. Creates a new Flask instance
    2. Configures CORS for cross-origin requests (needed for iOS app)
    3. Registers the leaderboard API blueprint
    4. Sets up error handlers

    Returns:
        Configured Flask application instance

    Usage:
        app = create_app()
        app.run(host="0.0.0.0", port=8080)
    """
    # Create Flask app instance
    app = Flask(__name__)

    # --------------------------------------------------------------------------
    # MARK: - CORS Configuration
    # --------------------------------------------------------------------------

    # Enable CORS for all routes
    # This allows the iOS app to make requests to the server
    CORS(app, resources={
        r"/api/*": {
            "origins": "*",  # iOS apps don't send Origin headers; this is safe for mobile-only APIs
            "methods": ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"]
        }
    })

    # --------------------------------------------------------------------------
    # MARK: - Blueprint Registration
    # --------------------------------------------------------------------------

    # Register the leaderboard API blueprint
    # All leaderboard endpoints will be prefixed with /api/leaderboard
    app.register_blueprint(leaderboard_bp)

    # Register the Claude API proxy blueprint
    # All Claude endpoints will be prefixed with /api/claude
    app.register_blueprint(claude_bp)

    # Register the Events blueprint
    # All event endpoints will be prefixed with /api/events
    app.register_blueprint(events_bp)

    # Register the Articles blueprint
    # All article endpoints will be prefixed with /api/articles
    app.register_blueprint(articles_bp)

    # Register the Users blueprint
    # All user endpoints will be prefixed with /api/users
    app.register_blueprint(users_bp)

    # --------------------------------------------------------------------------
    # MARK: - Root Endpoint
    # --------------------------------------------------------------------------

    @app.route("/")
    def index():
        """
        Root endpoint - provides basic API information.

        Response:
            {
                "service": "TapIn Backend API",
                "version": "1.0.0",
                "endpoints": {
                    "submit_score": "POST /api/leaderboard/score",
                    "get_leaderboard": "GET /api/leaderboard/<date>",
                    "health_check": "GET /api/leaderboard/health"
                }
            }
        """
        return jsonify({
            "service": "TapIn Backend API",
            "version": "1.0.0",
            "endpoints": {
                "submit_score": "POST /api/leaderboard/score",
                "get_leaderboard": "GET /api/leaderboard/<date>",
                "health_check": "GET /api/leaderboard/health",
                "summarize_event": "POST /api/claude/summarize",
                "claude_chat": "POST /api/claude/chat",
                "claude_health": "GET /api/claude/health",
                "get_events": "GET /api/events",
                "refresh_events": "POST /api/events/refresh",
                "events_health": "GET /api/events/health",
                "get_articles": "GET /api/articles?category=all",
                "get_article_content": "GET /api/articles/content?url=<encoded_url>",
                "daily_briefing": "GET /api/articles/daily-briefing",
                "refresh_articles": "POST /api/articles/refresh",
                "articles_health": "GET /api/articles/health",
                "auth_apple": "POST /api/users/auth/apple",
                "auth_google": "POST /api/users/auth/google",
                "auth_phone": "POST /api/users/auth/phone",
                "register": "POST /api/users/register",
                "login": "POST /api/users/login",
                "user_profile": "GET /api/users/me",
                "users_health": "GET /api/users/health",
            }
        })

    # --------------------------------------------------------------------------
    # MARK: - Error Handlers
    # --------------------------------------------------------------------------

    @app.errorhandler(404)
    def not_found(error):
        """Handle 404 Not Found errors."""
        return jsonify({
            "success": False,
            "error": "Endpoint not found"
        }), 404

    @app.errorhandler(405)
    def method_not_allowed(error):
        """Handle 405 Method Not Allowed errors."""
        return jsonify({
            "success": False,
            "error": "Method not allowed"
        }), 405

    @app.errorhandler(500)
    def internal_error(error):
        """Handle 500 Internal Server errors."""
        return jsonify({
            "success": False,
            "error": "Internal server error"
        }), 500

    return app


# ------------------------------------------------------------------------------
# MARK: - Main Entry Point
# ------------------------------------------------------------------------------

# Create the application instance
app = create_app()

if __name__ == "__main__":
    # Run the development server
    # - host="0.0.0.0" allows connections from other devices (useful for iOS testing)
    # - port=8080 matches Google App Engine's default port
    # - debug=True enables auto-reload and detailed error pages
    print("=" * 60)
    print("TapIn Backend Server")
    print("=" * 60)
    print("Server starting on http://localhost:8080")
    print("")
    print("Available endpoints:")
    print("  POST /api/leaderboard/score     - Submit a score")
    print("  GET  /api/leaderboard/<date>    - Get leaderboard")
    print("  GET  /api/leaderboard/health    - Health check")
    print("")
    print("  POST /api/claude/summarize      - Summarize event")
    print("  POST /api/claude/chat           - Claude chat")
    print("  GET  /api/claude/health         - Claude health check")
    print("")
    print("  POST /api/users/auth/apple      - Apple Sign-In")
    print("  POST /api/users/auth/phone      - Phone auth")
    print("  POST /api/users/register        - Email registration")
    print("  POST /api/users/login           - Email login")
    print("  GET  /api/users/me              - User profile")
    print("  GET  /api/users/health          - Users health check")
    print("")
    print("Press Ctrl+C to stop the server")
    print("=" * 60)

    app.run(host="0.0.0.0", port=8080, debug=False)
