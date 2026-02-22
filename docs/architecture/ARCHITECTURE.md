# Architecture

## Components

- Shared Swift core (`apps/macos-client/Sources/DictatorCore`)
  - Contract DTOs (`Transcribe*`, `Refine*`, `Dictate*`)
  - Pipeline orchestration (`PipelineOrchestrator`)
  - STT/refinement interfaces (`STTEngine`, `RefinementEngine`)
  - Whisper runtime abstraction (`WhisperRuntime`) with native in-process implementation
  - Secret interface (`SecretStore`)
- macOS wrapper (`apps/macos-client/Sources/DictatorApp`)
  - Menubar state and record toggle
  - Audio capture and insertion UX
  - macOS Keychain `SecretStore` adapter
- iOS wrappers (`apps/ios-keyboard`)
  - Host app settings/onboarding shell
  - Keyboard extension shell
- Shared contract spec (`contracts/dictation_v1.yaml`)

## Data flow

1. Wrapper captures audio and context.
2. Wrapper calls `DictatorCoreClient` in-process.
3. Core runs STT engine to generate raw transcript.
4. Core runs refinement engine with optional context and style prefs.
5. Wrapper inserts revised text (or surfaces explicit failure).

## Extensibility

- Provider adapters isolate STT/LLM vendor logic.
- Contract DTO schema remains stable while internals evolve.
