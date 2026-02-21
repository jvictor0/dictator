from app.models.contracts import Segment, TranscribeRequest, TranscribeResponse
from app.services.stt.base import STTProvider


class WhisperLocalProvider(STTProvider):
    """
    Thin placeholder provider for local Whisper integration.
    Replace mock logic with actual whisper.cpp/faster-whisper/MLX implementation.
    """

    def transcribe(self, req: TranscribeRequest) -> TranscribeResponse:
        text = "mock transcript from local whisper"
        return TranscribeResponse(
            raw_transcript=text,
            segments=[Segment(start_ms=0, end_ms=1000, text=text)],
            confidence=0.75,
            duration_ms=1000,
        )
