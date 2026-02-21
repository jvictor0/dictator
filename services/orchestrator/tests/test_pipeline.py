from app.models.contracts import DictateRequest, RefineRequest, TranscribeRequest
from app.services.pipeline import DictationPipeline


def test_transcribe_returns_expected_shape() -> None:
    pipeline = DictationPipeline()
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
    pipeline = DictationPipeline()
    out = pipeline.refine(RefineRequest(raw_transcript="hello world"))
    assert out.revised_text.startswith("Hello")
    assert isinstance(out.uncertainty_flags, list)


def test_dictate_combines_transcribe_and_refine() -> None:
    pipeline = DictationPipeline()
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
