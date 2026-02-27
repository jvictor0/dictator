#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: mayor-slice-from-issue.sh --work-item <id> --issue <issue-id|issue-file> [--slice <slice-id>] [--repo-root <path>]

Creates a new slice scaffold for a work-item issue and links the issue to that slice via Slice-ID.
USAGE
}

slugify() {
  local raw="$1"
  printf '%s' "$raw" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g'
}

extract_title() {
  local issue_file="$1"
  awk '
    /^#[[:space:]]+/ {
      line=$0
      sub(/^#[[:space:]]+/, "", line)
      sub(/^[Ii]ssue[[:space:]]+[0-9]+:[[:space:]]*/, "", line)
      print line
      exit
    }
  ' "$issue_file"
}

upsert_slice_id() {
  local issue_file="$1"
  local slice_id="$2"
  local tmp
  tmp=$(mktemp)
  awk -v value="$slice_id" '
    BEGIN { done=0 }
    {
      line=$0
      normalized=line
      sub(/^[[:space:]]*-[[:space:]]*/, "", normalized)
      if (!done && normalized ~ /^[Ss]lice-[Ii][Dd][[:space:]]*:/) {
        prefix=""
        if (line ~ /^[[:space:]]*-[[:space:]]*/) {
          prefix="- "
        }
        print prefix "Slice-ID: " value
        done=1
        next
      }
      print line
    }
    END {
      if (!done) {
        print "- Slice-ID: " value
      }
    }
  ' "$issue_file" > "$tmp"
  mv "$tmp" "$issue_file"
}

WORK_ITEM_ID=""
ISSUE_REF=""
SLICE_ID=""
REPO_ROOT="$(pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-item)
      WORK_ITEM_ID="$2"
      shift 2
      ;;
    --issue)
      ISSUE_REF="$2"
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

if [[ -z "$WORK_ITEM_ID" || -z "$ISSUE_REF" ]]; then
  usage
  exit 1
fi

REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
WORK_ITEM_PATH="$REPO_ROOT/work-items/$WORK_ITEM_ID"
ISSUES_PATH="$WORK_ITEM_PATH/issues"

if [[ ! -d "$WORK_ITEM_PATH" ]]; then
  echo "Work item not found: $WORK_ITEM_ID" >&2
  exit 2
fi

if [[ ! -d "$ISSUES_PATH" ]]; then
  echo "Issues directory not found: $ISSUES_PATH" >&2
  exit 2
fi

ISSUE_FILE=""
if [[ -f "$ISSUE_REF" ]]; then
  ISSUE_FILE="$ISSUE_REF"
else
  issue_id="$ISSUE_REF"
  issue_id="${issue_id##*/}"
  issue_id="${issue_id%.md}"
  if [[ "$issue_id" != issue-* ]]; then
    echo "Issue must be issue-<n> or an issue file path: $ISSUE_REF" >&2
    exit 2
  fi
  ISSUE_FILE="$ISSUES_PATH/$issue_id.md"
fi

if [[ ! -f "$ISSUE_FILE" ]]; then
  echo "Issue file not found: $ISSUE_FILE" >&2
  exit 2
fi

if [[ -z "$SLICE_ID" ]]; then
  title=$(extract_title "$ISSUE_FILE")
  if [[ -n "$title" ]]; then
    SLICE_ID="$(slugify "$title")"
  fi
  if [[ -z "$SLICE_ID" ]]; then
    issue_base=$(basename "$ISSUE_FILE")
    issue_base="${issue_base%.md}"
    SLICE_ID="slice-from-$issue_base"
  fi
fi

if [[ -z "$SLICE_ID" ]]; then
  echo "Unable to derive slice id; provide --slice explicitly." >&2
  exit 2
fi

"$REPO_ROOT/scripts/mayor-bootstrap.sh" \
  --work-item "$WORK_ITEM_ID" \
  --slice "$SLICE_ID" \
  --repo-root "$REPO_ROOT"

upsert_slice_id "$ISSUE_FILE" "$SLICE_ID"

cat <<OUT
Linked issue to slice:
- issue: ${ISSUE_FILE#$REPO_ROOT/}
- slice: $SLICE_ID
- slice path: work-items/$WORK_ITEM_ID/slices/$SLICE_ID
OUT
