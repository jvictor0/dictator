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

1. Configure runtime files (no environment variables):
   - Environment variables are never used for runtime configuration in this repo.
   - All non-secret settings live in `apps/macos-client/Config/runtime-config.json`.
   - Safe defaults live in `apps/macos-client/Config/runtime-config.safe`.
   - Secrets live in `apps/macos-client/Config/secrets.json` (local, gitignored). Use `apps/macos-client/Config/secrets.example.json` as the template.
   - System prompt versions live under `prompts/system-prompts/`; `system_prompt` is a path relative to that directory.
2. Build/test macOS app + shared core:
   - `cd apps/macos-client`
   - `swift build`
   - `swift test`

## Compatibility

- There are no stable installs for this project.
- We do not optimize for backward compatibility in general; configuration and behavior may change between revisions.
