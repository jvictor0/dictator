from app.core.config import settings
from app.models.contracts import (
    DictateRequest,
    DictateResponse,
    RefineRequest,
    RefineResponse,
    TranscribeRequest,
    TranscribeResponse,
)
from app.services.llm.openai_refiner import OpenAIRefiner
from app.services.stt.whisper_local import WhisperLocalProvider


class DictationPipeline:
    def __init__(self) -> None:
        self.stt = WhisperLocalProvider()
        self.llm = OpenAIRefiner()

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
        r = self.refine(
            RefineRequest(
                raw_transcript=t.raw_transcript,
                optional_context=req.optional_context,
                style_prefs=req.style_prefs,
            )
        )
        return DictateResponse(
            raw_transcript=t.raw_transcript,
            revised_text=r.revised_text,
            edit_summary=r.edit_summary,
            uncertainty_flags=r.uncertainty_flags,
        )
