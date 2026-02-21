# Orchestrator Service

FastAPI scaffold for Dictator STT + LLM refinement.

## Run

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
uvicorn app.main:app --reload
```

## Test

```bash
pytest
```
