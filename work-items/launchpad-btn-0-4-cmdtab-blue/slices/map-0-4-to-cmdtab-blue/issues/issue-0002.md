# Issue 0002: Workflow runner JSON encoding breaks when codex logs include quoted text

- Status: OPEN
- Reported by: mayor
- Source: workflow debug run

## Observed behavior
`python3 scripts/run-workflow.py --work-item launchpad-btn-0-4-cmdtab-blue --slice map-0-4-to-cmdtab-blue --sequence architect`
can report:
- `status: execution_error`
- `message: runner returned non-JSON output`

## Root cause
`/Users/joyo/dictator/scripts/run-role.sh` uses `json_escape()` to encode the final JSON payload, but its quote replacement does not escape double quotes in strings:
- current logic leaves `"` unescaped when source message contains `"..."`
- codex error logs include quoted paths (for example shell snapshot path), which can invalidate JSON

## Impact
The underlying codex failure reason is masked by parse errors in `run-workflow.py`.

## Suggested fix
In `json_escape()`, replace quote-escaping expression with one that matches literal `"` correctly in bash parameter expansion (so `"` is emitted in JSON for every `"` input character).
