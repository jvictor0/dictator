from abc import ABC, abstractmethod

from app.models.contracts import TranscribeRequest, TranscribeResponse


class STTProvider(ABC):
    @abstractmethod
    def transcribe(self, req: TranscribeRequest) -> TranscribeResponse:
        raise NotImplementedError
