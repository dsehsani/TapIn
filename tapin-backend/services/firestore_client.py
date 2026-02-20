#
#  firestore_client.py
#  TapInApp - Backend Server
#
#  MARK: - Firestore Client
#  Singleton Firestore client. Supports local dev (service account JSON)
#  and Cloud Run / App Engine (default credentials).
#
#  The google.cloud.firestore import is lazy (deferred until first call) to
#  avoid loading the protobuf C extension at module level, which is
#  incompatible with Python 3.14's stricter metaclass handling.
#

import os
import logging

logger = logging.getLogger(__name__)

# Initialized lazily on first call to get_firestore_client().
_firestore_client = None


def get_firestore_client():
    """Returns a singleton Firestore client, initializing it on first call."""
    global _firestore_client

    if _firestore_client is not None:
        return _firestore_client

    try:
        from google.cloud import firestore  # lazy — avoids protobuf C extension at import time

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
