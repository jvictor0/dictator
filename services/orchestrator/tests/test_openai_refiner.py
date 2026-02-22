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


def test_request_payload_uses_intent_preserving_instructions(monkeypatch) -> None:
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_api_key", "sk-test")
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_model", "gpt-4.1-mini")

    captured = {}

    def fake_requester(model: str, _api_key: str, _raw_transcript: str) -> str:
        captured["model"] = model
        captured["instructions"] = OpenAIRefiner.INSTRUCTIONS
        return "Revised text"

    refiner = OpenAIRefiner(requester=fake_requester)
    _ = refiner.refine(RefineRequest(raw_transcript="I considered x but y is better"))

    assert captured["model"] == "gpt-4.1-mini"
    assert captured["instructions"].startswith("You are an intent-preserving voice transcription refiner.")
    assert "intent-preserving voice transcription refiner" in captured["instructions"]
    assert "Operating modes:" in captured["instructions"]
    assert "Selected-text transform mode" in captured["instructions"]
    assert "prioritize the final decision/intent (Y)" in captured["instructions"]
    assert "Conflict resolution rule" in captured["instructions"]
    assert "Context usage rule" in captured["instructions"]
    assert "selected input text is provided in context" in captured["instructions"]


def test_refiner_includes_optional_context_in_request_input(monkeypatch) -> None:
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_api_key", "sk-test")
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_model", "gpt-4.1-mini")

    captured = {}

    def fake_requester(_model: str, _api_key: str, composed_input: str) -> str:
        captured["input"] = composed_input
        return "Revised text"

    refiner = OpenAIRefiner(requester=fake_requester)
    _ = refiner.refine(
        RefineRequest(
            raw_transcript="i think we should do x actually do y",
            optional_context={
                "dictation_context": "You are currently dictating into Codex. You are talking to a coding agent.",
                "active_app": "Codex",
                "active_site": "",
            },
        )
    )

    assert captured["input"].startswith("Context:")
    assert "You are currently dictating into Codex." in captured["input"]
    assert "Active app: Codex" in captured["input"]
    assert "Transcript:\ni think we should do x actually do y" in captured["input"]


def test_refiner_uses_selected_text_transform_input(monkeypatch) -> None:
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_api_key", "sk-test")
    monkeypatch.setattr("app.services.llm.openai_refiner.settings.openai_model", "gpt-4.1-mini")

    captured = {}

    def fake_requester(_model: str, _api_key: str, composed_input: str) -> str:
        captured["input"] = composed_input
        return "Transformed text"

    refiner = OpenAIRefiner(requester=fake_requester)
    _ = refiner.refine(
        RefineRequest(
            raw_transcript="make this shorter and more formal",
            optional_context={"selected_text": "hey team, just checking in quickly"},
        )
    )

    assert captured["input"].startswith("Take the following input and modify it based on the following request.")
    assert "Input text:\nhey team, just checking in quickly" in captured["input"]
    assert "Request:\nmake this shorter and more formal" in captured["input"]
