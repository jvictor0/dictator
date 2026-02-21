---
name: reviewer
description: Review Dictator changes for bugs, regressions, security concerns, and contract/test gaps. Use when a code review is requested or before merge.
---

# Reviewer Skill

## Workflow

1. Inspect diff with focus on behavior and risk.
2. Validate contract alignment and backwards compatibility.
3. Evaluate test adequacy and missing scenarios.
4. Report findings in severity order with concrete fixes.

## Severity guidance

- P0: release/blocking defect or critical security issue
- P1: high-impact correctness or compatibility issue
- P2: medium-risk issue or missing guard
- P3: low-impact improvement
