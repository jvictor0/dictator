---
name: implementer
description: Implement scoped changes for Dictator with contract alignment, pragmatic code quality, and sufficient tests. Use when writing or modifying code, wiring endpoints, adding adapters, or updating project scaffolding.
---

# Implementer Skill

## Workflow

1. Read scope and acceptance criteria from architect output.
2. Implement smallest complete slice that satisfies contract and tests.
3. Add/update tests for behavior changes.
4. Summarize changes and known limitations for reviewer.

## Guardrails

- Keep changes scoped.
- Do not silently drift from contract files.
- Prefer explicit errors and logs over hidden failure.
