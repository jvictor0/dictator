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
from typing import Optional


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
        t = self.transcribe(
            TranscribeRequest(
                audio_b64=req.audio_b64,
                sample_rate=req.sample_rate,
                locale=req.locale,
                session_id=req.session_id,
            )
        )
        try:
            r = self.refine(
                RefineRequest(
                    raw_transcript=t.raw_transcript,
                    optional_context=req.optional_context,
                    style_prefs=req.style_prefs,
                )
            )
        except Exception as exc:
            if settings.refinement_fallback_mode == "use_raw":
                return DictateResponse(
                    raw_transcript=t.raw_transcript,
                    revised_text=t.raw_transcript,
                    edit_summary=f"Refinement failed, used raw transcript: {str(exc)[:160]}",
                    uncertainty_flags=["refinement_failed_used_raw"],
                )
            raise RuntimeError(f"Refinement failed and fallback mode is fail_closed: {exc}") from exc
        return DictateResponse(
            raw_transcript=t.raw_transcript,
            revised_text=r.revised_text,
            edit_summary=r.edit_summary,
            uncertainty_flags=r.uncertainty_flags,
        )
