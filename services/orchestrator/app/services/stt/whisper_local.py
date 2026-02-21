import base64
import math
import tempfile
from pathlib import Path
from typing import Any, Callable, Optional

from app.core.config import settings
from app.models.contracts import Segment, TranscribeRequest, TranscribeResponse
from app.services.stt.base import STTProvider


class WhisperLocalProvider(STTProvider):
    _model_cache: dict[str, Any] = {}

    def __init__(
        self,
        model_name: Optional[str] = None,
        default_language: Optional[str] = None,
        transcribe_fn: Optional[Callable[..., dict[str, Any]]] = None,
    ) -> None:
        self.model_name = model_name or settings.whisper_model
        self.default_language = default_language or settings.whisper_language
        self._transcribe_fn = transcribe_fn

    def _load_transcriber(self) -> Callable[..., dict[str, Any]]:
        if self._transcribe_fn is not None:
            return self._transcribe_fn

        try:
            import whisper  # type: ignore[import-not-found]
        except ImportError as exc:
            raise RuntimeError("whisper dependency is missing; install openai-whisper") from exc

        if self.model_name not in self._model_cache:
            self._model_cache[self.model_name] = whisper.load_model(self.model_name)

        model = self._model_cache[self.model_name]
        return model.transcribe

    def _language_for_request(self, req: TranscribeRequest) -> str:
        locale_prefix = req.locale.split("-")[0].lower().strip()
        if locale_prefix:
            return locale_prefix
        return self.default_language

    def transcribe(self, req: TranscribeRequest) -> TranscribeResponse:
        try:
            audio_bytes = base64.b64decode(req.audio_b64, validate=True)
        except Exception as exc:
            raise ValueError("audio_b64 is not valid base64 audio payload") from exc

        if not audio_bytes:
            raise ValueError("audio_b64 payload is empty")

        transcribe = self._load_transcriber()
        language = self._language_for_request(req)

        with tempfile.NamedTemporaryFile(suffix=".caf", delete=False) as temp_file:
            temp_file.write(audio_bytes)
            temp_path = Path(temp_file.name)

        try:
            result = transcribe(
                str(temp_path),
                language=language,
                task="transcribe",
                fp16=False,
                verbose=False,
            )
        finally:
            temp_path.unlink(missing_ok=True)

        text = (result.get("text") or "").strip()
        raw_segments = result.get("segments") or []
        segments: list[Segment] = []
        confidences: list[float] = []

        for seg in raw_segments:
            start_ms = int(float(seg.get("start", 0.0)) * 1000)
            end_ms = int(float(seg.get("end", 0.0)) * 1000)
            seg_text = str(seg.get("text", "")).strip()
            if seg_text:
                segments.append(Segment(start_ms=start_ms, end_ms=end_ms, text=seg_text))
            avg_logprob = seg.get("avg_logprob")
            if isinstance(avg_logprob, (int, float)):
                confidences.append(max(0.0, min(1.0, math.exp(float(avg_logprob)))))

        if not text and segments:
            text = " ".join(seg.text for seg in segments).strip()

        duration_ms = segments[-1].end_ms if segments else 0
        confidence = sum(confidences) / len(confidences) if confidences else 0.0
        return TranscribeResponse(
            raw_transcript=text,
            segments=segments,
            confidence=confidence,
            duration_ms=duration_ms,
        )
