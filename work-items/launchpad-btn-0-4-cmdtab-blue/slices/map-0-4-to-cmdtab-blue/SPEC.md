# SPEC

Status: APPROVED
Role Pass: architect
Work Item: launchpad-btn-0-4-cmdtab-blue
Slice: map-0-4-to-cmdtab-blue

## Problem Statement
The Launchpad profile does not yet define the requested behavior for button coordinate `0,4`: issuing `Command+Tab` and displaying blue color. This slice introduces that exact mapping and color assignment.

## Goals
- Map Launchpad button `0,4` to key chord `Command+Tab`.
- Set Launchpad button `0,4` color to blue.
- Keep changes minimal and isolated to this single button entry.

## In Scope
- Configuration/code updates required to assign action `Command+Tab` to Launchpad coordinate `0,4`.
- Configuration/code updates required to assign blue color to Launchpad coordinate `0,4`.
- Any directly related tests or fixtures that validate this mapping/color behavior.

## Out of Scope
- Any remapping of coordinates other than `0,4`.
- Any color changes for buttons other than `0,4`.
- Changes to workflow tooling, role-runner scripts, or governance docs.
- Contract/schema redesign unless implementation reveals a hard blocker.

## API/Type/Contract Changes
- Expected: none to public API contract (`/contracts/dictation_v1.yaml`).
- Internal mapping structures may be updated only as needed to represent `0,4 -> Command+Tab` and blue color.

## Acceptance Criteria
1. Launchpad coordinate `0,4` resolves to action `Command+Tab` in runtime mapping.
2. Launchpad coordinate `0,4` resolves to blue color in runtime mapping.
3. Existing mappings for all other coordinates remain unchanged.
4. Automated test evidence is added or updated to verify (1) and (2), and to guard against regression in (3).
5. Implementer handoff explicitly states that no spec scope was changed.

## Risks
- Platform-specific key-chord representation mismatch (for example, `cmd+tab` vs structured modifiers/key) could map incorrectly.
- Color representation mismatch (name vs numeric/RGB code) could produce non-blue output.
- Collateral edits to adjacent mapping table entries could cause silent regressions.

## Fallback Plan
- If a direct `Command+Tab` representation is unsupported, use the repository’s existing canonical key-chord format for equivalent behavior and document it in implementer notes.
- If blue is represented by palette index/value, use the existing canonical blue value already used elsewhere in the codebase.
- If implementation cannot satisfy acceptance criteria without scope expansion, implementer must stop and record blocker per governance policy.
