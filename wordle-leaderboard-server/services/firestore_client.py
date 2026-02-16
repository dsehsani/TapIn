#
#  firestore_client.py
#  TapInApp - Wordle Leaderboard Server
#
#  MARK: - Firestore Client
#  This module provides a singleton Firestore client instance.
#  Supports both local development (service account JSON) and
#  App Engine production (default credentials).
#

import os
import logging
from typing import Optional
from google.cloud import firestore

# Configure logging
logger = logging.getLogger(__name__)

# Singleton client instance
_firestore_client: Optional[firestore.Client] = None


def get_firestore_client() -> firestore.Client:
    """
    Returns a singleton Firestore client instance.

    The client is initialized once and reused for all requests.
    Supports both local development and App Engine deployment:
    - Local: Uses GOOGLE_APPLICATION_CREDENTIALS environment variable
    - App Engine: Uses default service account credentials

    Returns:
        firestore.Client: Configured Firestore client

    Raises:
        Exception: If Firestore client cannot be initialized
    """
    global _firestore_client

    if _firestore_client is not None:
        return _firestore_client

    try:
        # Get project ID from environment or let client auto-detect
        project_id = os.environ.get("GCP_PROJECT")

        if project_id:
            logger.info(f"Initializing Firestore client for project: {project_id}")
            _firestore_client = firestore.Client(project=project_id)
        else:
            # Auto-detect project (works on App Engine)
            logger.info("Initializing Firestore client with auto-detected project")
            _firestore_client = firestore.Client()

        logger.info("Firestore client initialized successfully")
        return _firestore_client

    except Exception as e:
        logger.error(f"Failed to initialize Firestore client: {e}")
        raise


def is_firestore_connected() -> bool:
    """
    Checks if Firestore is reachable.

    Performs a lightweight operation to verify connectivity.

    Returns:
        bool: True if connected, False otherwise
    """
    try:
        client = get_firestore_client()
        # Perform a simple operation to verify connectivity
        # Listing collections is lightweight and confirms connection
        list(client.collections())
        return True
    except Exception as e:
        logger.error(f"Firestore connectivity check failed: {e}")
        return False
