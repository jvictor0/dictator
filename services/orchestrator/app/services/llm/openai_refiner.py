import json
import urllib.error
import urllib.request
from typing import Callable, Optional

from app.core.config import settings
from app.models.contracts import RefineRequest, RefineResponse
from app.services.llm.base import LLMProvider


class OpenAIRefiner(LLMProvider):
    def __init__(self, requester: Optional[Callable[[str, str, str], str]] = None) -> None:
        self._requester = requester or self._request_openai

    def refine(self, req: RefineRequest) -> RefineResponse:
        api_key = settings.openai_api_key.strip()
        if not api_key:
            raise ValueError("OPENAI_API_KEY is required when llm_provider=openai")

        if not settings.openai_model.strip():
            raise ValueError("OPENAI_MODEL is required when llm_provider=openai")

        revised = self._requester(settings.openai_model, api_key, req.raw_transcript)
        revised = revised.strip()
        if not revised:
            raise RuntimeError("OpenAI returned empty revised_text")
        return RefineResponse(
            revised_text=revised,
            edit_summary="Refined with OpenAI model.",
            uncertainty_flags=[],
        )

    def _request_openai(self, model: str, api_key: str, raw_transcript: str) -> str:
        url = "https://api.openai.com/v1/responses"
        payload = {
            "model": model,
            "instructions": (
                "Rewrite the transcript into polished final text while preserving meaning. "
                "Return only final revised text."
            ),
            "input": raw_transcript,
        }
        data = json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(url, data=data, method="POST")
        request.add_header("Content-Type", "application/json")
        request.add_header("Authorization", f"Bearer {api_key}")

        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="ignore")
            if exc.code in (401, 403):
                raise RuntimeError(f"OpenAI auth failed ({exc.code})") from exc
            if exc.code == 429:
                raise RuntimeError("OpenAI rate limited (429)") from exc
            raise RuntimeError(f"OpenAI request failed ({exc.code}): {body[:200]}") from exc
        except Exception as exc:
            raise RuntimeError(f"OpenAI request failed: {exc}") from exc

        parsed = json.loads(body)
        output_text = parsed.get("output_text")
        if isinstance(output_text, str) and output_text.strip():
            return output_text

        for item in parsed.get("output", []):
            for content in item.get("content", []):
                text = content.get("text")
                if isinstance(text, str) and text.strip():
                    return text

        raise RuntimeError("OpenAI response did not include output text")
