from fastapi import APIRouter

from app.models.contracts import (
    DictateRequest,
    DictateResponse,
    RefineRequest,
    RefineResponse,
    TranscribeRequest,
    TranscribeResponse,
)
from app.services.pipeline import DictationPipeline

router = APIRouter()
pipeline = DictationPipeline()


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/v1/transcribe", response_model=TranscribeResponse)
def transcribe(req: TranscribeRequest) -> TranscribeResponse:
    return pipeline.transcribe(req)


@router.post("/v1/refine", response_model=RefineResponse)
def refine(req: RefineRequest) -> RefineResponse:
    return pipeline.refine(req)


@router.post("/v1/dictate", response_model=DictateResponse)
def dictate(req: DictateRequest) -> DictateResponse:
    return pipeline.dictate(req)
