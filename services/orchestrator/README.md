# Orchestrator Service

FastAPI orchestrator for Dictator STT + LLM refinement.

## Run

```bash
python -m venv .venv
source .venv/bin/activate
pip install .[dev]
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

## Whisper notes

- STT provider `whisper_local` now uses `openai-whisper` locally.
- Ensure `ffmpeg` is available on PATH for audio decoding.
- First run may download the configured model (`WHISPER_MODEL`, default `tiny`).
- Internal lifecycle endpoint: `POST /exit` (used by mac wrapper for graceful shutdown).

## Test

```bash
pytest
```
