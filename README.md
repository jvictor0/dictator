# Dictator

Dictator is a unified Swift dictation codebase with platform wrappers for macOS and iOS.

## What this repo contains

- `apps/macos-client`: Swift menubar app + shared `DictatorCore` Swift module
- `apps/ios-keyboard`: iOS host/keyboard wrapper scaffold sharing `DictatorCore`
- `contracts`: language-agnostic contract source of truth
- `prompts`: prompt templates for transcript refinement
- `prompts/system-prompts`: versioned system prompt files selectable at runtime
- `skills`: local Codex skills used by this project
- `docs`: architecture, testing, and product docs

## Quick start

1. Copy `.env.example` to `.env` and set keys.
   - Local refinement defaults to Ollama (`qwen2.5:7b-instruct`); OpenAI key is optional fallback.
   - Runtime mutable LLM config is persisted in `apps/macos-client/Config/runtime-config.json` and overrides `.env` for model/cloud mode and selected system prompt path.
   - System prompt versions live under `prompts/system-prompts/`; `system_prompt` is a path relative to that directory.
2. Build/test macOS app + shared core:
   - `cd apps/macos-client`
   - `swift build`
   - `swift test`
