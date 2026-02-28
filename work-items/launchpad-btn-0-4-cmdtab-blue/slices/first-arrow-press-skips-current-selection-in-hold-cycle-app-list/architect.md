# Architect Notes

## Scope Decision
This slice is a targeted correctness fix for first-arrow behavior in `0,4` hold-cycle sessions. The only intended behavior change is first-step navigation accuracy relative to the true current selection. Mapping, colors, and broader interception architecture stay unchanged unless minimally required.

## Current-State Read
- Hold session starts in `main.swift` via `launchpadAppCycleState.start(with:currentPID:)` after immediate next-window activation.
- Cycle stepping logic currently increments/decrements index inside `LaunchpadAppCycleSession.step(_:)` before returning a PID.
- Existing tests validate frozen order and wraparound, but do not pin first-step semantics against real hold-session baseline expectations.

## Root-Cause Hypotheses
1. Session anchor PID passed to cycle-state start is not the same logical selection users perceive as "current" at first arrow dispatch.
2. Current-index seeding is correct, but first-step transition rule is offset for the desired UX contract.
3. Baseline PID can be absent from frozen list in some runtime paths, causing fallback index behavior that appears as a first-step skip.

## Proposed Implementation Direction
1. Define explicit first-step contract in cycle state: first arrow step is exactly one move from the baseline current selection in requested direction.
2. Keep frozen candidate list immutable for the session; adjust only anchor/index semantics as needed.
3. Ensure runtime start path passes the intended baseline PID and does not rely on implicit assumptions.
4. If baseline PID is missing, choose one deterministic fallback (for example index `0`) and codify it in tests and comments.

## Tradeoffs
- Moving logic into cycle-state abstraction increases clarity and testability, but may require slight initializer signature expansion.
- Keeping behavior scoped to first-step correctness avoids churn in event interception paths and lowers regression risk.

## Interface and Contract Impact
- No public API/contract change (`/contracts/dictation_v1.yaml` unchanged).
- No ADR required; this is a scoped behavioral correctness adjustment inside existing Launchpad hold-cycle internals.

## Risks and Mitigations
- Risk: accidental regression in established wraparound traversal.
- Mitigation: keep current wraparound tests and add first-step-specific assertions for both directions.
- Risk: baseline ambiguity between pre-switch and post-switch app.
- Mitigation: implementer must anchor to runtime current selection at cycle start and validate with focused tests that mirror actual start call inputs.
- Risk: session lifecycle regressions.
- Mitigation: avoid teardown/start lifecycle changes unless strictly necessary; verify existing stop/idle tests continue to pass.

## Test Guidance
- Update `LaunchpadAppCycleStateTests.swift` (and `LaunchpadTests.swift` if needed) to include:
- first forward step from seeded current PID returns immediate next frozen candidate,
- first backward step from seeded current PID returns immediate previous frozen candidate,
- baseline PID absent case uses deterministic fallback with documented expected first step,
- existing frozen-order immutability and stop semantics remain green.
- Run focused test commands at minimum:
- `swift test --package-path /Users/joyo/dictator/apps/macos-client --filter LaunchpadAppCycleStateTests`
- `swift test --package-path /Users/joyo/dictator/apps/macos-client --filter LaunchpadTests`

## Handoff
Architect pass complete. `SPEC.md` is approved for implementer pass 1.
pass complete
