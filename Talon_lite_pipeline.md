# Talon Lite Pipeline

This document defines the end-to-end Talon Lite processing pipeline.

## Inputs And Outputs

- Input: Raw user speech audio.
- Output: Final rendered text inserted at the active cursor.

## Pipeline Overview

1. Speech-to-text with Whisper.
2. Grammar validation against `talon_lite_grammar.md`.
3. Recovery pass via LLM if validation fails.
4. Guaranteed grammar-valid transcript.
5. Rendering/formatting pass.
6. Cursor injection.

## Step 1: Whisper Transcription

- Record voice input.
- Run Whisper transcription.
- Produce a raw transcript string.

Result: `raw_transcript`.


## Step 2: Grammar Match Attempt

- Parse `raw_transcript` against [talon_lite_grammar.md](/Users/joyo/dictator/talon_lite_grammar.md).
- If parse succeeds: continue directly to rendering.
- If parse fails: continue to LLM recovery.

Result on success: `grammar_valid_transcript`.

## Step 3: LLM Recovery (Only On Parse Failure)

Send the failed transcript to an LLM with a strict system prompt that includes the grammar.

### Required LLM Prompt Contract

- Provide the full grammar from [talon_lite_grammar.md](/Users/joyo/dictator/talon_lite_grammar.md).
- Instruct the model to transform Whisper output so it matches the grammar exactly.
- Instruct the model to return only the corrected transcript.
- Disallow commentary, explanations, alternatives, and creative rewrites.
- Preserve intended content while converting to valid Talon Lite tokens.

### Post-LLM Validation

- Re-parse LLM output against the grammar.
- If parse still fails: raise a terminal parse/recovery error.
- If parse succeeds: continue.

Result: `grammar_valid_transcript`.

## Step 4: Guaranteed Grammar-Valid Transcript

At this point, the system holds a transcript that is guaranteed to match the grammar.

Invariant:
- Downstream rendering receives only grammar-valid input.

## Step 5: Render/Format

- Send `grammar_valid_transcript` to the rendering pipeline.
- Rendering handles operator execution, brace balancing behavior, and text-style formatting.

Reference: [Rendering_pipeline.md](/Users/joyo/dictator/Rendering_pipeline.md).

## Step 6: Cursor Injection

- Insert rendered final string at the active cursor location.
- No additional text transformations are applied after render.

## Control Flow Summary

```text
Audio
  -> Whisper
  -> grammar parse
     -> success -> render -> inject
     -> failure -> LLM correction with grammar -> re-parse
         -> success -> render -> inject
         -> failure -> terminal error
```

## Non-Goals

- This document does not define the exact band-character replacement rules.
- This document does not define full rendering internals; those are in `Rendering_pipeline.md`.
