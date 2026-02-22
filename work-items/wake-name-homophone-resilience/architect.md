# Architect notes

## Findings from logs
- Active context capture works in both Codex and Chrome/Discord.
- Failure pattern is STT lexical variance (`Chief`, `sheath`, `sheef`) in wake phrase, not context transport.

## Design
- Add a dedicated wake-name normalization rule to the system prompt.
- Constrain normalization to direct-address contexts to reduce false positives.
