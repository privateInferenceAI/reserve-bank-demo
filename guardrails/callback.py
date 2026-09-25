"""BankGuardrail — LiteLLM CustomGuardrail enforced at the gateway.

Policy is enforced where every consumer passes through. Web UIs, scripts, n8n,
and internal apps all get identical treatment. A UI-level filter can be bypassed
by calling the gateway directly; this callback cannot.

Two deterministic controls:
  1. PRE-CALL topic denial  — refused before the request reaches a model.
  2. POST-CALL PII redaction — response rewritten before it returns.

NOTE: hook signatures follow litellm.integrations.custom_guardrail.
Verify against the pinned LiteLLM version when upgrading.
"""

import re

from fastapi import HTTPException
from litellm.integrations.custom_guardrail import CustomGuardrail

# Keep in sync with guardrails/policy.txt.
DENIED_KEYWORDS = (
    "salary of", "how much does", "ssn", "social security number",
    "ignore previous instructions", "ignore all previous", "you are now", "system:",
)
REFUSAL_MESSAGE = "Request denied by gateway policy. Contact your administrator."
PII_PATTERNS = (r"\b\d{3}-\d{2}-\d{4}\b",)  # SSN -> [REDACTED]


class BankGuardrail(CustomGuardrail):
    """Pre-call topic denial + post-call PII redaction, enforced for every key."""

    @staticmethod
    def _last_user_text(data: dict) -> str:
        for m in reversed(data.get("messages", []) or []):
            if m.get("role") == "user":
                return (m.get("content") or "").lower()
        return ""

    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        """Runs before the model call. Raise to deny; return data to allow."""
        text = self._last_user_text(data)
        key_alias = getattr(user_api_key_dict, "key_alias", None)
        for kw in DENIED_KEYWORDS:
            if kw in text:
                # AUDIT LINE: denial events must be greppable.
                print(
                    f"[bank-guardrail] DENIED "
                    f"key_alias={key_alias} "
                    f"keyword={kw!r}"
                )
                raise HTTPException(status_code=400, detail=REFUSAL_MESSAGE)
        print(
            f"[bank-guardrail] ALLOW key_alias={key_alias} "
            f"model={data.get('model')}"
        )
        return data

    async def async_post_call_success_hook(self, data, user_api_key_dict, response):
        """Runs on the model response. Redact PII patterns before returning."""
        try:
            for choice in getattr(response, "choices", []) or []:
                content = getattr(choice.message, "content", None)
                if isinstance(content, str):
                    for pat in PII_PATTERNS:
                        content = re.sub(pat, "[REDACTED]", content)
                    choice.message.content = content
        except Exception as e:  # fail open on redaction errors, but log them
            print(f"[bank-guardrail] redaction error (passing through): {e}")
        return response


# LiteLLM expects an instance, not the class, in the callbacks config.
proxy_handler_instance = BankGuardrail()
