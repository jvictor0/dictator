.PHONY: setup-backend run-backend test-backend build-macos test-macos ci

setup-backend:
	cd services/orchestrator && python -m venv .venv && . .venv/bin/activate && pip install -e .[dev]

run-backend:
	cd services/orchestrator && . .venv/bin/activate && uvicorn app.main:app --reload

test-backend:
	cd services/orchestrator && . .venv/bin/activate && pytest

build-macos:
	cd apps/macos-client && swift build

test-macos:
	cd apps/macos-client && swift test

ci: test-backend test-macos
