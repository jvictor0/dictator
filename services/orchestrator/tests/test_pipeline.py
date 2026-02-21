from app.models.contracts import (
    DictateRequest,
    RefineRequest,
    RefineResponse,
    Segment,
    TranscribeRequest,
    TranscribeResponse,
)
from app.services.llm.base import LLMProvider
from app.services.pipeline import DictationPipeline
from app.services.stt.base import STTProvider


class FakeSTTProvider(STTProvider):
    def transcribe(self, req: TranscribeRequest) -> TranscribeResponse:
        return TranscribeResponse(
            raw_transcript="mock transcript from fake stt",
            segments=[Segment(start_ms=0, end_ms=1000, text="mock transcript from fake stt")],
            confidence=0.8,
            duration_ms=1000,
        )


class FakeLLMProvider(LLMProvider):
    def refine(self, req: RefineRequest) -> RefineResponse:
        return RefineResponse(
            revised_text=req.raw_transcript.capitalize(),
            edit_summary="Mock capitalization",
            uncertainty_flags=[],
        )


def test_transcribe_returns_expected_shape() -> None:
    pipeline = DictationPipeline(stt_provider=FakeSTTProvider(), llm_provider=FakeLLMProvider())
    out = pipeline.transcribe(
        TranscribeRequest(
            audio_b64="ZmFrZQ==",
            sample_rate=16000,
            locale="en-US",
            session_id="s1",
        )
    )
    assert out.raw_transcript
    assert out.duration_ms >= 0
    assert out.segments


def test_refine_normalizes_text() -> None:
    pipeline = DictationPipeline(stt_provider=FakeSTTProvider(), llm_provider=FakeLLMProvider())
    out = pipeline.refine(RefineRequest(raw_transcript="hello world"))
    assert out.revised_text.startswith("Hello")
    assert isinstance(out.uncertainty_flags, list)


def test_dictate_combines_transcribe_and_refine() -> None:
    pipeline = DictationPipeline(stt_provider=FakeSTTProvider(), llm_provider=FakeLLMProvider())
    out = pipeline.dictate(
        DictateRequest(
            audio_b64="ZmFrZQ==",
            sample_rate=16000,
            locale="en-US",
            session_id="s2",
        )
    )
    assert out.raw_transcript
    assert out.revised_text
