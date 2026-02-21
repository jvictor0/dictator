# Architecture

## Components

- macOS client (`apps/macos-client`)
  - Menubar state and record toggle
  - Backend API client
  - Clipboard paste insertion fallback
- Orchestrator service (`services/orchestrator`)
  - Endpoint routing and request validation
  - STT adapter interface (local Whisper first)
  - LLM refinement adapter interface (cloud API key first)
- Shared contract (`contracts/dictation_v1.yaml`)

## Data flow

1. Client sends audio + metadata to `/v1/transcribe` or `/v1/dictate`.
2. Service runs STT adapter and returns raw transcript.
3. Service runs refinement adapter and returns revised text.
4. Client inserts revised text.

## Extensibility

- Provider adapters isolate STT/LLM vendor logic.
- Endpoint contract remains stable while internals evolve.
