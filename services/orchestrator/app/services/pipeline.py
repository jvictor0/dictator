import logging
import time
from typing import Optional

from app.core.config import settings
from app.models.contracts import (
    DictateRequest,
    DictateResponse,
    RefineRequest,
    RefineResponse,
    TranscribeRequest,
    TranscribeResponse,
)
from app.services.llm.base import LLMProvider
from app.services.llm.openai_refiner import OpenAIRefiner
from app.services.stt.base import STTProvider
from app.services.stt.whisper_local import WhisperLocalProvider

logger = logging.getLogger(__name__)


class DictationPipeline:
    def __init__(
        self,
        stt_provider: Optional[STTProvider] = None,
        llm_provider: Optional[LLMProvider] = None,
    ) -> None:
        self.stt = stt_provider or WhisperLocalProvider()
        self.llm = llm_provider or OpenAIRefiner()

    def transcribe(self, req: TranscribeRequest) -> TranscribeResponse:
        # Future provider switch can use settings.stt_provider.
        _ = settings.stt_provider
        return self.stt.transcribe(req)

    def refine(self, req: RefineRequest) -> RefineResponse:
        _ = settings.llm_provider
        return self.llm.refine(req)

    def dictate(self, req: DictateRequest) -> DictateResponse:
        out, _, _ = self.dictate_with_metrics(req)
        return out

    def dictate_with_metrics(self, req: DictateRequest) -> tuple[DictateResponse, int, int]:
        transcribe_started = time.perf_counter()
        t = self.transcribe(
            TranscribeRequest(
                audio_b64=req.audio_b64,
                sample_rate=req.sample_rate,
                locale=req.locale,
                session_id=req.session_id,
            )
        )
        transcribe_ms = int((time.perf_counter() - transcribe_started) * 1000)
        if not t.raw_transcript.strip():
            logger.info("Transcription returned empty text; skipping refinement")
            return (
                DictateResponse(
                    raw_transcript="",
                    revised_text="",
                    edit_summary="Transcription empty; skipped refinement.",
                    uncertainty_flags=["empty_transcript_skipped_refinement"],
                ),
                transcribe_ms,
                0,
            )
        refine_started = time.perf_counter()
        try:
            r = self.refine(
                RefineRequest(
                    raw_transcript=t.raw_transcript,
                    optional_context=req.optional_context,
                    style_prefs=req.style_prefs,
                )
            )
            refine_ms = int((time.perf_counter() - refine_started) * 1000)
        except Exception as exc:
            refine_ms = int((time.perf_counter() - refine_started) * 1000)
            if settings.refinement_fallback_mode == "use_raw":
                logger.warning(
                    "Refinement failed, using raw transcript fallback (refine_ms=%s, error=%s)",
                    refine_ms,
                    str(exc)[:220],
                )
                return (
                    DictateResponse(
                        raw_transcript=t.raw_transcript,
                        revised_text=t.raw_transcript,
                        edit_summary=f"Refinement failed, used raw transcript: {str(exc)[:160]}",
                        uncertainty_flags=["refinement_failed_used_raw"],
                    ),
                    transcribe_ms,
                    refine_ms,
                )
            logger.error(
                "Refinement failed with fail_closed mode (refine_ms=%s, error=%s)",
                refine_ms,
                str(exc)[:220],
            )
            raise RuntimeError(f"Refinement failed and fallback mode is fail_closed: {exc}") from exc
        return (
            DictateResponse(
                raw_transcript=t.raw_transcript,
                revised_text=r.revised_text,
                edit_summary=r.edit_summary,
                uncertainty_flags=r.uncertainty_flags,
            ),
            transcribe_ms,
            refine_ms,
        )
