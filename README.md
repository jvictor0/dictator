# Dictator

Dictator is a unified Swift dictation codebase with platform wrappers for macOS and iOS.

## What this repo contains

- `apps/dictator-main`: Swift menubar app + shared `DictatorCore` Swift module + LAN dictation HTTP server
- `apps/ios-keyboard`: iOS host/keyboard app that records audio and calls the LAN dictation endpoint
- `contracts`: language-agnostic contract source of truth
- `prompts`: prompt templates for transcript refinement
- `prompts/system-prompts`: versioned system prompt files selectable at runtime
- `skills`: local Codex skills used by this project
- `docs`: architecture, testing, and product docs

## Quick start

1. Configure runtime files (no environment variables):
   - Environment variables are never used for runtime configuration in this repo.
   - All non-secret settings live in `apps/dictator-main/Config/runtime-config.json`.
   - Safe defaults live in `apps/dictator-main/Config/runtime-config.safe`.
   - Secrets live in `apps/dictator-main/Config/secrets.json` (local, gitignored). Use `apps/dictator-main/Config/secrets.example.json` as the template.
   - System prompt versions live under `prompts/system-prompts/`; `system_prompt` is a path relative to that directory.
   - LAN server config is in `dictator_server_enabled`, `dictator_server_host`, `dictator_server_port`.
2. Build/test macOS app + shared core:
   - `cd apps/dictator-main`
   - `swift build`
   - `swift test`

## Compatibility

- There are no stable installs for this project.
- We do not optimize for backward compatibility in general; configuration and behavior may change between revisions.
