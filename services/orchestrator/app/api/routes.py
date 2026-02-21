import os
import signal
import time

from fastapi import APIRouter, BackgroundTasks, HTTPException, Response

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


def _terminate_self() -> None:
    # Give the HTTP response a chance to flush before shutting down.
    time.sleep(0.05)
    os.kill(os.getpid(), signal.SIGTERM)


@router.post("/exit")
def exit_service(background_tasks: BackgroundTasks) -> dict[str, str]:
    background_tasks.add_task(_terminate_self)
    return {"status": "shutting_down"}


@router.post("/v1/transcribe", response_model=TranscribeResponse)
def transcribe(req: TranscribeRequest) -> TranscribeResponse:
    try:
        return pipeline.transcribe(req)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.post("/v1/refine", response_model=RefineResponse)
def refine(req: RefineRequest) -> RefineResponse:
    try:
        return pipeline.refine(req)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.post("/v1/dictate", response_model=DictateResponse)
def dictate(req: DictateRequest, response: Response) -> DictateResponse:
    try:
        if hasattr(pipeline, "dictate_with_metrics"):
            out, transcribe_ms, refine_ms = pipeline.dictate_with_metrics(req)  # type: ignore[attr-defined]
            response.headers["X-Dictator-Transcribe-Ms"] = str(transcribe_ms)
            response.headers["X-Dictator-Refine-Ms"] = str(refine_ms)
            return out
        return pipeline.dictate(req)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
