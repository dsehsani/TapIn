#
#  config.py
#  TapInApp - Wordle Leaderboard Server
#
#  MARK: - Configuration
#  Centralized configuration management for the application.
#  Loads settings from environment variables with sensible defaults.
#

import os


class Config:
    """
    Application configuration loaded from environment variables.

    Attributes:
        ENV: Environment name ("development" or "production")
        GCP_PROJECT: Google Cloud project ID
        DEBUG: Enable debug mode (auto-detected from ENV)
    """

    # Environment: "development" or "production"
    ENV: str = os.environ.get("ENV", "development")

    # Google Cloud project ID
    GCP_PROJECT: str = os.environ.get("GCP_PROJECT", "tapin-app-487603")

    # Debug mode (enabled in development)
    DEBUG: bool = ENV == "development"

    # Server configuration
    HOST: str = os.environ.get("HOST", "0.0.0.0")
    PORT: int = int(os.environ.get("PORT", "8080"))

    @classmethod
    def is_production(cls) -> bool:
        """Check if running in production environment."""
        return cls.ENV == "production"

    @classmethod
    def is_development(cls) -> bool:
        """Check if running in development environment."""
        return cls.ENV == "development"

    @classmethod
    def validate(cls) -> None:
        """
        Validates required configuration for production.

        Raises:
            ValueError: If required production settings are missing
        """
        if cls.is_production():
            if not cls.GCP_PROJECT:
                raise ValueError("GCP_PROJECT must be set in production")


# Validate on import in production
if Config.is_production():
    Config.validate()
