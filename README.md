# Dictator

Dictator is a macOS menubar dictation app bootstrap with a multi-agent development workflow.

## What this repo contains

- `apps/macos-client`: Swift menubar client scaffold (record toggle, API wiring, clipboard paste fallback)
- `services/orchestrator`: FastAPI scaffold for STT + LLM refinement pipeline
- `contracts`: API contract source of truth
- `prompts`: Prompt templates for transcript refinement
- `skills`: Four role skills (`architect`, `implementer`, `reviewer`, `tester`)
- `docs`: Governance, architecture, testing, and product docs

## Quick start

1. Copy `.env.example` to `.env` and set keys.
2. Start backend:
   - `cd services/orchestrator`
   - `python -m venv .venv && source .venv/bin/activate`
   - `pip install -e .[dev]`
   - `uvicorn app.main:app --reload`
3. Run backend tests:
   - `pytest`
4. Build/test macOS scaffold:
   - `cd apps/macos-client`
   - `swift build`
   - `swift test`

## Workflow

See `/docs/governance/WORKFLOWS.md` and `/AGENTS.md` for role orchestration and quality gates.
For short execution prompts, use `/Users/joyo/dictator/ENTRYPOINT.md`.

## Roadmap

See `/Users/joyo/dictator/docs/product/ROADMAP.md` for slice-by-slice delivery.
