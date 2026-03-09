#
#  moderation.py
#  TapIn Backend
#
#  AI moderation service using Claude for display name filtering.
#

import os
import json
import logging
import anthropic

logger = logging.getLogger(__name__)

NAME_MODERATION_PROMPT = """
You are reviewing a display name for a campus app. The name will be publicly visible.
Reject names containing slurs, hate speech, sexual content, or impersonation of real people or institutions.
Normal nicknames, usernames, and creative names are fine.

Name: {name}

Respond ONLY with JSON: {{"approved": true}}
"""


class ModerationService:
    def __init__(self):
        self.api_key = os.environ.get("CLAUDE_API_KEY") or os.environ.get("ANTHROPIC_API_KEY")

    def _get_client(self) -> anthropic.Anthropic:
        if not self.api_key:
            raise ValueError("CLAUDE_API_KEY not set")
        return anthropic.Anthropic(api_key=self.api_key)

    def moderate_display_name(self, name: str) -> bool:
        """
        Returns True if the name is acceptable, False if it should be rejected.
        Fail-closed: if Claude is unavailable, rejects the name.
        """
        try:
            client = self._get_client()
            message = client.messages.create(
                model="claude-sonnet-4-5-20250929",
                max_tokens=50,
                messages=[{
                    "role": "user",
                    "content": NAME_MODERATION_PROMPT.format(name=name)
                }]
            )
            raw = message.content[0].text.strip()
            result = json.loads(raw)
            return result.get("approved", False)
        except Exception as e:
            logger.error(f"Name moderation failed (fail-closed): {e}")
            return False


moderation_service = ModerationService()
