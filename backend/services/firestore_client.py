#
#  firestore_client.py
#  TapInApp - Backend Server
#
#  MARK: - Firestore Client
#  Singleton Firestore client. Supports local dev (service account JSON)
#  and Cloud Run / App Engine (default credentials).
#

import os
import logging
from typing import Optional
from google.cloud import firestore

logger = logging.getLogger(__name__)

_firestore_client: Optional[firestore.Client] = None


def get_firestore_client() -> firestore.Client:
    """Returns a singleton Firestore client, initializing it on first call."""
    global _firestore_client

    if _firestore_client is not None:
        return _firestore_client

    try:
        project_id = os.environ.get("GCP_PROJECT")
        if project_id:
            logger.info(f"Initializing Firestore for project: {project_id}")
            _firestore_client = firestore.Client(project=project_id)
        else:
            logger.info("Initializing Firestore with auto-detected project")
            _firestore_client = firestore.Client()

        logger.info("Firestore client initialized successfully")
        return _firestore_client

    except Exception as e:
        logger.error(f"Failed to initialize Firestore client: {e}")
        raise


def is_firestore_connected() -> bool:
    """Lightweight connectivity check."""
    try:
        client = get_firestore_client()
        list(client.collections())
        return True
    except Exception as e:
        logger.error(f"Firestore connectivity check failed: {e}")
        return False
