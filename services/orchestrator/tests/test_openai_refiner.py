import pytest

from app.models.contracts import RefineRequest
from app.services.llm.openai_refiner import OpenAIRefiner


def test_refiner_requires_api_key(monkeypatch) -> None:
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_api_key", "")
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_model", "gpt-4.1-mini")

    refiner = OpenAIRefiner(requester=lambda *_args: "unused")

    with pytest.raises(ValueError, match="OPENAI_API_KEY"):
        refiner.refine(RefineRequest(raw_transcript="hello"))


def test_refiner_maps_auth_error(monkeypatch) -> None:
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_api_key", "sk-test")
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_model", "gpt-4.1-mini")

    def raising_requester(*_args):
        raise RuntimeError("OpenAI auth failed (401)")

    refiner = OpenAIRefiner(requester=raising_requester)

    with pytest.raises(RuntimeError, match="auth failed"):
        refiner.refine(RefineRequest(raw_transcript="hello"))


def test_refiner_maps_rate_limit_error(monkeypatch) -> None:
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_api_key", "sk-test")
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_model", "gpt-4.1-mini")

    refiner = OpenAIRefiner(requester=lambda *_args: (_ for _ in ()).throw(RuntimeError("OpenAI rate limited (429)")))

    with pytest.raises(RuntimeError, match="rate limited"):
        refiner.refine(RefineRequest(raw_transcript="hello"))


def test_refiner_returns_revised_text(monkeypatch) -> None:
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_api_key", "sk-test")
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_model", "gpt-4.1-mini")

    refiner = OpenAIRefiner(requester=lambda *_args: "Revised text")
    out = refiner.refine(RefineRequest(raw_transcript="hello"))

    assert out.revised_text == "Revised text"
