# Issue 0006: Arrow-key suppression fix is ineffective during active next-window hold-cycle

- Status: RESOLVED
- Slice-ID: arrow-key-suppression-fix-is-ineffective-during-active-next-window-hold-cycle
- Reported by: mayor
- Source: user report

## Problem
The previously completed suppression change did not resolve user-facing behavior. During active `0,4` next-window hold-cycle, arrow keys are still reaching the foreground app in at least one runtime path.

## Requested investigation
- Reproduce on-device with `0,4` held and arrow keys pressed in a text-input foreground app.
- Identify why local arrow event suppression is not consistently taking effect.
- Verify monitor ordering, callback thread/actor context, and any path that returns/pass-throughs events while cycle state is active.
- Confirm whether global monitor side effects or duplicate event handling are masking local suppression behavior.

## Requested outcome
- Arrow key events are reliably consumed (not delivered to foreground app) while hold-cycle session is active.
- No regression to cycle navigation behavior.
- Outside hold-cycle session, normal arrow delivery remains unchanged.
