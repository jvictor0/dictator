import base64

import pytest

from app.models.contracts import TranscribeRequest
from app.services.stt.whisper_local import WhisperLocalProvider


def test_whisper_provider_maps_result_shape() -> None:
    def fake_transcribe(*args, **kwargs):
        _ = args
        _ = kwargs
        return {
            "text": "hello world",
            "segments": [
                {"start": 0.0, "end": 0.5, "text": "hello", "avg_logprob": -0.1},
                {"start": 0.5, "end": 1.2, "text": "world", "avg_logprob": -0.2},
            ],
        }

    provider = WhisperLocalProvider(transcribe_fn=fake_transcribe)
    req = TranscribeRequest(
        audio_b64=base64.b64encode(b"fake-audio").decode("utf-8"),
        sample_rate=16000,
        locale="en-US",
        session_id="s1",
    )

    out = provider.transcribe(req)

    assert out.raw_transcript == "hello world"
    assert out.duration_ms == 1200
    assert len(out.segments) == 2
    assert out.confidence > 0


def test_whisper_provider_rejects_invalid_base64() -> None:
    provider = WhisperLocalProvider(transcribe_fn=lambda *_args, **_kwargs: {})
    req = TranscribeRequest(
        audio_b64="not-base64",
        sample_rate=16000,
        locale="en-US",
        session_id="s1",
    )

    with pytest.raises(ValueError, match="valid base64"):
        provider.transcribe(req)


def test_whisper_provider_normalizes_underscore_locale() -> None:
    provider = WhisperLocalProvider(default_language="en", transcribe_fn=lambda *_args, **_kwargs: {})
    req = TranscribeRequest(
        audio_b64=base64.b64encode(b"fake-audio").decode("utf-8"),
        sample_rate=16000,
        locale="en_US",
        session_id="s1",
    )
    assert provider._language_for_request(req) == "en"
