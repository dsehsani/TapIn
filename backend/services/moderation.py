#
#  moderation.py
#  TapIn Backend
#
#  AI moderation service using Claude for comment screening
#  and display name filtering.
#

import os
import json
import logging
import anthropic

logger = logging.getLogger(__name__)

COMMENT_MODERATION_PROMPT = """
You are a content moderator for TapIn, a campus news and events app for UC Davis students.
Review the following user comment and determine if it is appropriate to publish.

Reject the comment if it contains any of the following:
- Hate speech, slurs, or discriminatory language targeting any group
- Harassment, bullying, or personal attacks against individuals
- Threats of violence or self-harm
- Sexually explicit content
- Spam or promotional content unrelated to campus life
- Doxxing or sharing personal information about others
- Content that violates UC Davis's student conduct code

The community is a campus news feed — everyday opinions, criticism of articles, event comments,
and debate are all acceptable even if strong or negative.

Comment to review:
<comment>{comment_body}</comment>

Respond ONLY with valid JSON in this exact format:
{{"approved": true, "score": 0.0, "reason": null}}

Where score 0.0 = completely clean, 1.0 = clearly violating. Use 0.6 as the approval threshold.
Valid reasons: null, "hate_speech", "harassment", "threat", "explicit", "spam", "doxxing", "other"
"""

NAME_MODERATION_PROMPT = """
You are reviewing a display name for a campus app. The name will be publicly visible.
Reject names containing slurs, hate speech, sexual content, or impersonation of real people or institutions.
Normal nicknames, usernames, and creative names are fine.

Name: {name}

Respond ONLY with JSON: {{"approved": true}}
"""


class ModerationResult:
    def __init__(self, approved: bool, score: float = 0.0, reason: str | None = None):
        self.approved = approved
        self.score = score
        self.reason = reason


class ModerationService:
    def __init__(self):
        self.api_key = os.environ.get("CLAUDE_API_KEY") or os.environ.get("ANTHROPIC_API_KEY")

    def _get_client(self) -> anthropic.Anthropic:
        if not self.api_key:
            raise ValueError("CLAUDE_API_KEY not set")
        return anthropic.Anthropic(api_key=self.api_key)

    def moderate_comment(self, body: str) -> ModerationResult:
        """
        Sends the comment to Claude for moderation.
        Returns ModerationResult with approved/score/reason.
        Fail-open: if Claude is unavailable, approves with reason='moderation_unavailable'.
        """
        try:
            client = self._get_client()
            message = client.messages.create(
                model="claude-sonnet-4-5-20250929",
                max_tokens=100,
                messages=[{
                    "role": "user",
                    "content": COMMENT_MODERATION_PROMPT.format(comment_body=body)
                }]
            )
            raw = message.content[0].text.strip()
            result = json.loads(raw)
            approved = result.get("approved", True) and result.get("score", 0.0) < 0.6
            return ModerationResult(
                approved=approved,
                score=result.get("score", 0.0),
                reason=result.get("reason")
            )
        except Exception as e:
            logger.error(f"Comment moderation failed (fail-open): {e}")
            return ModerationResult(approved=True, score=0.0, reason="moderation_unavailable")

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
