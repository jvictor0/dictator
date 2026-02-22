import json
import logging
import urllib.error
import urllib.request
from typing import Callable, Optional

from app.core.config import settings
from app.models.contracts import RefineRequest, RefineResponse
from app.services.llm.base import LLMProvider

logger = logging.getLogger(__name__)


class OpenAIRefiner(LLMProvider):
    INSTRUCTIONS = (
        "You are an intent-preserving voice transcription refiner.\n\n"
        "Input context:\n"
        "- The user text comes from a full voice-to-text pipeline (Whisper + refinement).\n"
        "- Transcription may contain errors, missing punctuation, repeated words, or misheard phrases.\n\n"
        "Operating modes:\n"
        "1) Transcript refinement mode (default): improve transcript quality while preserving meaning.\n"
        "2) Selected-text transform mode: when optional context includes selected input text, treat transcript "
        "as the user's modification request for that selected text.\n\n"
        "Your task:\n"
        "1) Rewrite the text to reflect the speaker's intended meaning, not just literal transcript wording.\n"
        "2) Correct likely transcription errors, grammar, punctuation, and clarity issues.\n"
        "3) Preserve tone and important details, but remove obvious filler, false starts, and rambling "
        "when they do not add meaning.\n"
        "4) If the speaker changes their mind (e.g., 'I thought X, but actually Y'), prioritize the final "
        "decision/intent (Y) in the refined output.\n"
        "5) When earlier and later statements conflict, treat later statements as updates unless the speaker "
        "explicitly says both should be kept.\n"
        "6) Do not invent facts. If meaning is ambiguous, produce the most likely interpretation and keep "
        "wording neutral.\n\n"
        "Conflict resolution rule:\n"
        "- If a statement includes a correction, reversal, or preference update ('actually', 'instead', "
        "'rather', 'on second thought', 'change that'), treat it as the active intent and de-emphasize "
        "superseded wording.\n\n"
        "Context usage rule:\n"
        "- Optional context may indicate the active dictation target (app/site/coding-agent hint). "
        "Use it to disambiguate wording and intent, but do not invent facts.\n"
        "- If selected input text is provided in context, apply the spoken request to that selected text.\n\n"
        "Output format:\n"
        "- Return only the final output text for the active mode.\n"
        "- Do not include explanations, notes, or meta-commentary unless explicitly requested."
    )

    def __init__(self, requester: Optional[Callable[[str, str, str], str]] = None) -> None:
        self._requester = requester or self._request_openai

    def refine(self, req: RefineRequest) -> RefineResponse:
        logger.info("OpenAI system prompt:\n%s", self.INSTRUCTIONS)
        dictation_context = req.optional_context.get("dictation_context")
        if isinstance(dictation_context, str) and dictation_context.strip():
            logger.info("Dictation context: %s", dictation_context.strip())
        else:
            logger.info("Dictation context: <none>")
        selected_text = req.optional_context.get("selected_text")
        if isinstance(selected_text, str) and selected_text.strip():
            logger.info("Selected text mode: enabled (chars=%s)", len(selected_text.strip()))
        else:
            logger.info("Selected text mode: disabled")
        api_key = settings.openai_api_key.strip()
        if not api_key:
            raise ValueError("OPENAI_API_KEY is required when llm_provider=openai")

        if not settings.openai_model.strip():
            raise ValueError("OPENAI_MODEL is required when llm_provider=openai")

        request_input = self._build_input(req.raw_transcript, req.optional_context)
        revised = self._requester(settings.openai_model, api_key, request_input)
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
            "instructions": self.INSTRUCTIONS,
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

    @staticmethod
    def _build_input(raw_transcript: str, optional_context: dict) -> str:
        selected_text = optional_context.get("selected_text")
        if isinstance(selected_text, str) and selected_text.strip():
            return (
                "Take the following input and modify it based on the following request.\n\n"
                "Input text:\n"
                f"{selected_text.strip()}\n\n"
                "Request:\n"
                f"{raw_transcript}"
            )

        if not optional_context:
            return raw_transcript

        context_lines: list[str] = []
        dictation_context = optional_context.get("dictation_context")
        if isinstance(dictation_context, str) and dictation_context.strip():
            context_lines.append(dictation_context.strip())

        active_app = optional_context.get("active_app")
        if isinstance(active_app, str) and active_app.strip():
            context_lines.append(f"Active app: {active_app.strip()}")

        active_site = optional_context.get("active_site")
        if isinstance(active_site, str) and active_site.strip():
            context_lines.append(f"Active site: {active_site.strip()}")

        if not context_lines:
            return raw_transcript

        return "Context:\n" + "\n".join(f"- {line}" for line in context_lines) + "\n\nTranscript:\n" + raw_transcript
