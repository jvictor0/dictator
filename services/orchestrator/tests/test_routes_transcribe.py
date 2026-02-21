from fastapi import HTTPException, Response

import app.api.routes as routes
from app.models.contracts import (
    DictateRequest,
    DictateResponse,
    RefineRequest,
    RefineResponse,
    Segment,
    TranscribeRequest,
    TranscribeResponse,
)


class _ErrorPipeline:
    def __init__(self, exc: Exception) -> None:
        self._exc = exc

    def transcribe(self, req):  # pragma: no cover - exercised through route
        _ = req
        raise self._exc

    def refine(self, req):
        _ = req
        raise self._exc

    def dictate(self, req):
        _ = req
        raise self._exc


class _SuccessPipeline:
    def transcribe(self, req):  # pragma: no cover - exercised through route
        _ = req
        return TranscribeResponse(
            raw_transcript="route success",
            segments=[Segment(start_ms=0, end_ms=1000, text="route success")],
            confidence=0.9,
            duration_ms=1000,
        )

    def refine(self, req):
        _ = req
        return RefineResponse(
            revised_text="refined text",
            edit_summary="summary",
            uncertainty_flags=[],
        )

    def dictate(self, req):
        _ = req
        return DictateResponse(
            raw_transcript="raw",
            revised_text="refined text",
            edit_summary="summary",
            uncertainty_flags=[],
        )


def _request() -> TranscribeRequest:
    return TranscribeRequest(
        audio_b64="ZmFrZS1hdWRpbw==",
        sample_rate=16000,
        locale="en-US",
        session_id="route-test",
    )


def test_transcribe_maps_value_error_to_400() -> None:
    original = routes.pipeline
    routes.pipeline = _ErrorPipeline(ValueError("bad payload"))
    try:
        try:
            routes.transcribe(_request())
            assert False, "Expected HTTPException"
        except HTTPException as exc:
            assert exc.status_code == 400
            assert exc.detail == "bad payload"
    finally:
        routes.pipeline = original


def test_transcribe_maps_runtime_error_to_503() -> None:
    original = routes.pipeline
    routes.pipeline = _ErrorPipeline(RuntimeError("whisper missing"))
    try:
        try:
            routes.transcribe(_request())
            assert False, "Expected HTTPException"
        except HTTPException as exc:
            assert exc.status_code == 503
            assert exc.detail == "whisper missing"
    finally:
        routes.pipeline = original


def test_transcribe_success_route_shape() -> None:
    original = routes.pipeline
    routes.pipeline = _SuccessPipeline()
    try:
        out = routes.transcribe(_request())
    finally:
        routes.pipeline = original

    assert out.raw_transcript == "route success"
    assert out.segments[0].text == "route success"


def test_refine_maps_runtime_error_to_503() -> None:
    original = routes.pipeline
    routes.pipeline = _ErrorPipeline(RuntimeError("refiner outage"))
    try:
        try:
            routes.refine(RefineRequest(raw_transcript="hello"))
            assert False, "Expected HTTPException"
        except HTTPException as exc:
            assert exc.status_code == 503
            assert exc.detail == "refiner outage"
    finally:
        routes.pipeline = original


def test_refine_success_route_shape() -> None:
    original = routes.pipeline
    routes.pipeline = _SuccessPipeline()
    try:
        out = routes.refine(RefineRequest(raw_transcript="hello"))
    finally:
        routes.pipeline = original
    assert out.revised_text == "refined text"


def test_dictate_maps_runtime_error_to_503() -> None:
    original = routes.pipeline
    routes.pipeline = _ErrorPipeline(RuntimeError("dictate outage"))
    try:
        req = DictateRequest(
            audio_b64="ZmFrZS1hdWRpbw==",
            sample_rate=16000,
            locale="en-US",
            session_id="route-test",
        )
        try:
            routes.dictate(req, Response())
            assert False, "Expected HTTPException"
        except HTTPException as exc:
            assert exc.status_code == 503
            assert exc.detail == "dictate outage"
    finally:
        routes.pipeline = original
