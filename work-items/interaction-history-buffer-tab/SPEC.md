# SPEC: Interaction history capture and overlay tab

## Scope
Implement an in-memory interaction history feature in the macOS client that captures dictation workflow details and exposes them in the Launchpad fullscreen overlay.

## Requirements
1. Define an interaction model that includes:
   - Whisper output.
   - Final refined output.
   - Mode (`raw_dictation`, `revision`, `text_replacement`).
   - System prompt used.
   - Model/provider used.
   - Timing information for each step.
2. Persist interactions in a configurable-size circular buffer.
3. Default maximum buffer memory to 100 MB.
4. On insert, evict oldest interactions until usage is within configured limit.
5. Tracked interaction size must equal UTF-8 byte length of whisper output plus final output.
6. Reuse existing workflow abstractions to capture details when dictation completes.
7. Replace overlay tab #3 placeholder with an `Interactions` tab.
8. Interactions tab layout:
   - Left column: chronological final outputs, oldest at top and newest at bottom.
   - Right column: selected interaction details including system prompt, whisper output, final output, mode, model/provider, context, and timings.
9. Up/down keys must select interactions in the tab.
10. On tab load, default selection is the latest interaction.

## Non-goals
- Persist interaction history to disk.
- Add contract changes to `contracts/dictation_v1.yaml`.

## Acceptance criteria
1. Successful dictation appends an interaction record with required metadata.
2. Buffer eviction removes oldest entries first when size limit is exceeded.
3. Interaction buffer limit can be adjusted via runtime configuration and applies immediately.
4. Overlay displays interactions as specified and supports keyboard selection behavior.
5. Tests cover core buffer eviction and tab selection behavior.
