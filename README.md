# Dictator

Dictator is a unified Swift dictation codebase with platform wrappers for macOS and iOS.

## What this repo contains

- `apps/macos-client`: Swift menubar app + shared `DictatorCore` Swift module
- `apps/ios-keyboard`: iOS host/keyboard wrapper scaffold sharing `DictatorCore`
- `contracts`: language-agnostic contract source of truth
- `prompts`: Prompt templates for transcript refinement
- `skills`: Four role skills (`architect`, `implementer`, `reviewer`, `tester`)
- `docs`: Governance, architecture, testing, and product docs

## Quick start

1. Copy `.env.example` to `.env` and set keys.
2. Build/test macOS app + shared core:
   - `cd apps/macos-client`
   - `swift build`
   - `swift test`

## Workflow

See `/docs/governance/WORKFLOWS.md` and `/AGENTS.md` for role orchestration and quality gates.
For short execution prompts, use `/Users/joyo/dictator/ENTRYPOINT.md`.

## Roadmap

See `/Users/joyo/dictator/docs/product/ROADMAP.md` for slice-by-slice delivery.
