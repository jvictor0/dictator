#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: mayor-bootstrap.sh --work-item <id> --slice <id> [--repo-root <path>]

Creates a new work-item slice scaffold for role workflow orchestration.
USAGE
}

WORK_ITEM_ID=""
SLICE_ID=""
REPO_ROOT="$(pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-item)
      WORK_ITEM_ID="$2"
      shift 2
      ;;
    --slice)
      SLICE_ID="$2"
      shift 2
      ;;
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$WORK_ITEM_ID" || -z "$SLICE_ID" ]]; then
  usage
  exit 1
fi

REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
WORK_ITEM_PATH="$REPO_ROOT/work-items/$WORK_ITEM_ID"
SLICE_PATH="$WORK_ITEM_PATH/slices/$SLICE_ID"
ISSUES_PATH="$SLICE_PATH/issues"

mkdir -p "$ISSUES_PATH"

if [[ ! -e "$SLICE_PATH/SPEC.md" ]]; then
  cat > "$SLICE_PATH/SPEC.md" <<'EOF_SPEC'
# SPEC

Status: DRAFT

## Goals
-

## In Scope
-

## Out of Scope
-

## Acceptance Criteria
-
EOF_SPEC
fi

if [[ ! -e "$SLICE_PATH/architect.md" ]]; then
  cat > "$SLICE_PATH/architect.md" <<'EOF_ARCH'
# Architect Notes

-
EOF_ARCH
fi

if [[ ! -e "$SLICE_PATH/implementer-pass-1.md" ]]; then
  cat > "$SLICE_PATH/implementer-pass-1.md" <<'EOF_IMPL'
# Implementer Pass 1

Pending execution.
EOF_IMPL
fi

if [[ ! -e "$SLICE_PATH/reviewer-pass-1.md" ]]; then
  cat > "$SLICE_PATH/reviewer-pass-1.md" <<'EOF_REV'
# Reviewer Pass 1

Pending execution.
EOF_REV
fi

if [[ ! -e "$SLICE_PATH/tester.md" ]]; then
  cat > "$SLICE_PATH/tester.md" <<'EOF_TEST'
# Tester

Pending execution.
EOF_TEST
fi

cat <<OUT
Bootstrapped work item slice:
- work item: $WORK_ITEM_ID
- slice: $SLICE_ID
- path: $SLICE_PATH

Artifacts:
- $( [[ -f "$SLICE_PATH/SPEC.md" ]] && echo "SPEC.md" )
- $( [[ -f "$SLICE_PATH/architect.md" ]] && echo "architect.md" )
- $( [[ -f "$SLICE_PATH/implementer-pass-1.md" ]] && echo "implementer-pass-1.md" )
- $( [[ -f "$SLICE_PATH/reviewer-pass-1.md" ]] && echo "reviewer-pass-1.md" )
- $( [[ -f "$SLICE_PATH/tester.md" ]] && echo "tester.md" )
- issues/
OUT
