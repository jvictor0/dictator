from pathlib import Path

import yaml


def test_contract_has_required_endpoints() -> None:
    contract_path = Path(__file__).resolve().parents[3] / "contracts" / "dictation_v1.yaml"
    data = yaml.safe_load(contract_path.read_text())

    endpoints = {(e["method"], e["path"]) for e in data["endpoints"]}
    assert ("POST", "/v1/transcribe") in endpoints
    assert ("POST", "/v1/refine") in endpoints
    assert ("POST", "/v1/dictate") in endpoints


def test_dictate_response_fields_present() -> None:
    contract_path = Path(__file__).resolve().parents[3] / "contracts" / "dictation_v1.yaml"
    data = yaml.safe_load(contract_path.read_text())

    dictate = [e for e in data["endpoints"] if e["path"] == "/v1/dictate"][0]
    required = set(dictate["response"]["required"])
    assert {"raw_transcript", "revised_text", "edit_summary", "uncertainty_flags"}.issubset(required)
