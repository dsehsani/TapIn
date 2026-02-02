#
#  app.py
#  TapInApp - Wordle Leaderboard Server
#
#  Created by Darius Ehsani on 2/2/26.
#
#  MARK: - Flask Application Entry Point
#  This is the main entry point for the Wordle Leaderboard Flask server.
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
from api.leaderboard import leaderboard_bp


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
            "origins": "*",  # Allow all origins for development
            "methods": ["GET", "POST", "OPTIONS"],
            "allow_headers": ["Content-Type"]
        }
    })

    # --------------------------------------------------------------------------
    # MARK: - Blueprint Registration
    # --------------------------------------------------------------------------

    # Register the leaderboard API blueprint
    # All leaderboard endpoints will be prefixed with /api/leaderboard
    app.register_blueprint(leaderboard_bp)

    # --------------------------------------------------------------------------
    # MARK: - Root Endpoint
    # --------------------------------------------------------------------------

    @app.route("/")
    def index():
        """
        Root endpoint - provides basic API information.

        Response:
            {
                "service": "TapInApp Wordle Leaderboard API",
                "version": "1.0.0",
                "endpoints": {
                    "submit_score": "POST /api/leaderboard/score",
                    "get_leaderboard": "GET /api/leaderboard/<date>",
                    "health_check": "GET /api/leaderboard/health"
                }
            }
        """
        return jsonify({
            "service": "TapInApp Wordle Leaderboard API",
            "version": "1.0.0",
            "endpoints": {
                "submit_score": "POST /api/leaderboard/score",
                "get_leaderboard": "GET /api/leaderboard/<date>",
                "health_check": "GET /api/leaderboard/health"
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
    print("TapInApp Wordle Leaderboard Server")
    print("=" * 60)
    print("Server starting on http://localhost:8080")
    print("")
    print("Available endpoints:")
    print("  POST /api/leaderboard/score     - Submit a score")
    print("  GET  /api/leaderboard/<date>    - Get leaderboard")
    print("  GET  /api/leaderboard/health    - Health check")
    print("")
    print("Press Ctrl+C to stop the server")
    print("=" * 60)

    app.run(host="0.0.0.0", port=8080, debug=True)
