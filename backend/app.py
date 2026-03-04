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

import os
from flask import Flask, jsonify, send_file
from flask_cors import CORS
from dotenv import load_dotenv
from api.leaderboard import leaderboard_bp
from api.claude import claude_bp
from api.events import events_bp
from api.articles import articles_bp
from api.users import users_bp
from api.pipes import pipes_bp
from api.analytics import analytics_bp

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

    # Register the Pipes blueprint
    # All pipes game endpoints will be prefixed with /api/pipes
    app.register_blueprint(pipes_bp)

    # Register the Analytics blueprint
    # DAU tracking and dashboard at /api/analytics
    app.register_blueprint(analytics_bp)

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
                "pipes_daily": "GET /api/pipes/daily",
                "pipes_daily_five": "GET /api/pipes/daily-five?date=YYYY-MM-DD",
                "pipes_health": "GET /api/pipes/health",
                "track_dau_event": "POST /api/analytics/track",
                "query_dau": "GET /api/analytics/dau",
                "analytics_health": "GET /api/analytics/health",
                "dau_dashboard": "GET /api/analytics/dashboard",
                "privacy_policy": "GET /privacy",
                "terms_of_service": "GET /terms",
            }
        })

    # --------------------------------------------------------------------------
    # MARK: - Legal Pages
    # --------------------------------------------------------------------------

    @app.route("/privacy")
    def privacy_policy():
        """Serve the Privacy Policy HTML page."""
        docs_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "docs")
        return send_file(os.path.join(docs_dir, "privacy_policy.html"))

    @app.route("/terms")
    def terms_of_service():
        """Serve the Terms of Service HTML page."""
        docs_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "docs")
        return send_file(os.path.join(docs_dir, "terms_of_service.html"))

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
    print("  GET  /api/pipes/daily           - Daily pipes puzzle")
    print("  GET  /api/pipes/daily-five      - Daily 5-puzzle set")
    print("  GET  /api/pipes/health          - Pipes health check")
    print("")
    print("Press Ctrl+C to stop the server")
    print("=" * 60)

    app.run(host="0.0.0.0", port=8080, debug=False)
