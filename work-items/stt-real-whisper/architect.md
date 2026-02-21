# Architect Notes

## Design rationale
- Keep provider interface (`STTProvider`) unchanged; swap implementation internals only.
- Decode audio payload to temp file and pass file path into Whisper transcriber.
- Convert Whisper segment/time/confidence shape into contract-defined fields.
- Introduce DI points in `DictationPipeline` constructor to keep unit tests deterministic and independent of live Whisper runtime.

## Key decisions
- Missing Whisper dependency now raises explicit runtime error.
- Confidence derived from average of `exp(avg_logprob)` when available.
- Duration derived from last segment end time.

## Tradeoffs
- First real inference may include model download latency.
- Temp-file transcription path is simple and stable for current scope.

## ADR impact
- No ADR update needed; this is implementation completion inside existing slice architecture.
