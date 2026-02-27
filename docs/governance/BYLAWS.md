# Bylaws

## Purpose

Define non-negotiable engineering and delivery standards for Dictator.

## Engineering standards

- Prefer simple, explicit designs over implicit magic.
- Keep API contracts stable and versioned.
- All behavioral changes require tests or documented rationale when tests are not feasible.
- Security-sensitive changes (auth, key handling, clipboard/accessibility permissions) require explicit review notes.
- Keep abstraction layers clean and avoid code duplication.

## Scope and authority rules

- Mayor is authorized only to create work-item slice scaffolding (via `scripts/mayor-bootstrap.sh`), create/update issue files, and execute `scripts/run-workflow.py`.
- Mayor is not authorized to modify production code or role-specific implementation/review/test artifacts.
- `SPEC.md` in each work item is the single source of implementation scope.
- Implementer is not authorized to change scope/spec.
- Tester is not authorized to change production code.

## Review standards

- Reviewer prioritizes bugs, regressions, and risk over style.
- Findings must include severity and concrete remediation.
- `P0/P1` issues block merge.

## Pass-limit policy

- Implementer has a hard limit of 2 passes per work item.
- If unresolved after pass 2, implementer must record blocker reason and stop.
- Default policy is no automatic escalation to architect.

## Testing standards

- Contract tests must pass for all public endpoints.
- Pipeline behavior changes require unit tests for success and failure modes.
- Menubar client scaffolding changes require smoke tests at minimum.
- Tester may return bugs to implementer; fixes must be re-reviewed before tester re-validation.

## Documentation standards

- Interface changes update `/contracts/dictation_v1.yaml` and related docs in the same PR.
- Architectural direction changes require an ADR entry.
- Each work item must include handoff artifacts in `/work-items/<work-item-id>/`.

## Release standards

- Merge only when role handoffs are complete.
- Keep release notes concise and user-impact oriented.
