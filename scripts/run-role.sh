#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: run-role.sh --work-item <id> --slice <id> --role <architect|implementer|reviewer|tester> [--repo-root <path>]
USAGE
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//"/\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

array_to_json() {
  local had_nounset=0
  if [[ $- == *u* ]]; then
    had_nounset=1
    set +u
  fi

  local arr_name="$1"
  local arr_ref=()
  eval "arr_ref=(\"\${${arr_name}[@]}\")"
  local out="["
  local first=1
  local item
  for item in "${arr_ref[@]}"; do
    if [[ $first -eq 0 ]]; then
      out+=","
    fi
    first=0
    out+="\"$(json_escape "$item")\""
  done
  out+="]"
  if [[ $had_nounset -eq 1 ]]; then
    set -u
  fi
  printf '%s' "$out"
}

emit_result() {
  local status="$1"
  local message="$2"
  local code="$3"

  local artifacts_json
  local issues_open_json
  local issues_created_json
  local next_roles_json
  artifacts_json=$(array_to_json ARTIFACTS_WRITTEN)
  issues_open_json=$(array_to_json ISSUES_OPEN)
  issues_created_json=$(array_to_json ISSUES_CREATED)
  next_roles_json=$(array_to_json NEXT_ALLOWED_ROLES)

  cat <<JSON
{"run_id":"$(json_escape "$RUN_ID")","status":"$(json_escape "$status")","work_item_id":"$(json_escape "$WORK_ITEM_ID")","slice_id":"$(json_escape "$SLICE_ID")","role":"$(json_escape "$ROLE")","artifacts_written":$artifacts_json,"issues_open":$issues_open_json,"issues_created":$issues_created_json,"next_allowed_roles":$next_roles_json,"message":"$(json_escape "$message")"}
JSON
  exit "$code"
}

count_files() {
  local pattern="$1"
  local count
  count=$(find "$SLICE_PATH" -maxdepth 1 -type f -name "$pattern" | wc -l | tr -d ' ')
  printf '%s' "$count"
}

latest_reviewer_file() {
  local files
  files=$(find "$SLICE_PATH" -maxdepth 1 -type f -name 'reviewer-pass-*.md' | sed 's#.*/##' | sort -V)
  if [[ -z "$files" ]]; then
    return 1
  fi
  printf '%s\n' "$files" | tail -n 1
}

reviewer_approved() {
  local latest
  if ! latest=$(latest_reviewer_file); then
    return 1
  fi
  local lower
  lower=$(tr '[:upper:]' '[:lower:]' < "$SLICE_PATH/$latest")
  if [[ "$lower" == *"not approved"* ]] || [[ "$lower" == *"required fixes"* ]]; then
    return 1
  fi
  [[ "$lower" == *"approved"* ]]
}

collect_open_issues() {
  ISSUES_OPEN=()
  if [[ ! -d "$ISSUES_PATH" ]]; then
    return
  fi
  local file
  while IFS= read -r file; do
    local status
    status=$(awk -F': *' 'tolower($1)=="status" {print toupper($2); exit}' "$file" || true)
    if [[ "$status" == "OPEN" ]]; then
      ISSUES_OPEN+=("${file#$REPO_ROOT/}")
    fi
  done < <(find "$ISSUES_PATH" -maxdepth 1 -type f -name 'issue-*.md' | sort)
}

has_open_issues() {
  collect_open_issues
  [[ ${#ISSUES_OPEN[@]} -gt 0 ]]
}

snapshot_files() {
  local base="$1"
  local out="$2"
  : > "$out"
  if [[ ! -d "$base" ]]; then
    return
  fi
  local file rel hash
  while IFS= read -r file; do
    rel=${file#$REPO_ROOT/}
    hash=$(shasum -a 256 "$file" | awk '{print $1}')
    printf '%s\t%s\n' "$rel" "$hash" >> "$out"
  done < <(find "$base" -type f | sort)
}

compute_artifact_changes() {
  ARTIFACTS_WRITTEN=()
  ISSUES_CREATED=()

  while IFS= read -r rel; do
    [[ -n "$rel" ]] && ARTIFACTS_WRITTEN+=("$rel")
  done < <(awk -F'\t' 'NR==FNR {before[$1]=$2; next} {if (!($1 in before) || before[$1] != $2) print $1}' "$BEFORE_SNAPSHOT" "$AFTER_SNAPSHOT" | sort)

  while IFS= read -r rel; do
    [[ -n "$rel" ]] && ISSUES_CREATED+=("$rel")
  done < <(awk -F'\t' 'NR==FNR {before[$1]=1; next} {if ($1 ~ issuePattern && !($1 in before)) print $1}' \
    -v issuePattern="^"$(printf '%s' "$ISSUES_REL" | sed 's/[.[\\*^$(){}?+|]/\\&/g')"/issue-" \
    "$BEFORE_SNAPSHOT" "$AFTER_SNAPSHOT" | sort)
}

compute_next_allowed_roles() {
  NEXT_ALLOWED_ROLES=()

  if [[ ! -d "$WORK_ITEM_PATH" ]]; then
    NEXT_ALLOWED_ROLES+=("architect")
    return
  fi

  if [[ ! -d "$SLICE_PATH" ]]; then
    NEXT_ALLOWED_ROLES+=("architect")
    return
  fi

  local spec="$SLICE_PATH/SPEC.md"
  local implementer_count reviewer_count tester_exists
  implementer_count=$(count_files 'implementer-pass-*.md')
  reviewer_count=$(count_files 'reviewer-pass-*.md')
  tester_exists=0
  [[ -f "$SLICE_PATH/tester.md" ]] && tester_exists=1

  NEXT_ALLOWED_ROLES+=("architect")

  if [[ -f "$spec" ]]; then
    if [[ "$implementer_count" -eq 0 ]]; then
      NEXT_ALLOWED_ROLES+=("implementer")
    elif [[ "$implementer_count" -eq 1 ]]; then
      if has_open_issues; then
        NEXT_ALLOWED_ROLES+=("implementer")
      fi
    fi
  fi

  if [[ "$reviewer_count" -eq 0 ]]; then
    if [[ -f "$SLICE_PATH/implementer-pass-1.md" ]]; then
      NEXT_ALLOWED_ROLES+=("reviewer")
    fi
  elif [[ "$reviewer_count" -eq 1 ]]; then
    if [[ -f "$SLICE_PATH/implementer-pass-2.md" ]]; then
      NEXT_ALLOWED_ROLES+=("reviewer")
    fi
  fi

  if reviewer_approved; then
    NEXT_ALLOWED_ROLES+=("tester")
  fi

  IFS=$'\n' NEXT_ALLOWED_ROLES=($(printf '%s\n' "${NEXT_ALLOWED_ROLES[@]}" | awk '!seen[$0]++'))
}

build_prompt() {
  local pass_label="$1"
  cat > "$PROMPT_FILE" <<PROMPT
You are executing one deterministic role run in repo: $REPO_ROOT

Required policy files:
- $REPO_ROOT/AGENTS.md
- $REPO_ROOT/docs/governance/BYLAWS.md
- $REPO_ROOT/docs/governance/WORKFLOWS.md
- $REPO_ROOT/docs/governance/ROLE_HANDOFFS.md

Run request:
- work item: $WORK_ITEM_ID
- slice: $SLICE_ID
- role: $ROLE
- pass label: $pass_label
- target path: $SLICE_PATH

Hard rules:
1. Perform only this role and only files required by this role.
2. Enforce strict bylaw sequencing and pass limits.
3. Do not modify SPEC scope during implementer runs.
4. Use per-slice issues at $ISSUES_PATH, file names issue-0001.md, issue-0002.md, etc.
5. If no changes are needed, write an explicit no-op statement in the role artifact.
6. Never create extra pass files beyond the requested pass.

Expected output artifact for this run:
- architect: architect.md (and SPEC.md if missing or update requested)
- implementer: implementer-pass-N.md
- reviewer: reviewer-pass-N.md with findings and approval decision
- tester: tester.md with matrix and confidence
PROMPT
}

run_codex() {
  local codex_bin="${CODEX_BIN:-codex}"
  if ! command -v "$codex_bin" >/dev/null 2>&1 && [[ ! -x "$codex_bin" ]]; then
    emit_result "execution_error" "codex executable not found: $codex_bin" 3
  fi

  if [[ "${RUN_ROLE_SKIP_EXEC:-0}" == "1" ]]; then
    return
  fi

  "$codex_bin" exec --ephemeral -C "$REPO_ROOT" "$(cat "$PROMPT_FILE")" >/tmp/run-role-codex-${RUN_ID}.log 2>&1 || {
    local tail_log
    tail_log=$(tail -n 20 /tmp/run-role-codex-${RUN_ID}.log | tr '\n' ' ')
    emit_result "execution_error" "codex execution failed: ${tail_log}" 3
  }
}

WORK_ITEM_ID=""
SLICE_ID=""
ROLE=""
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
    --role)
      ROLE="$2"
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

if [[ -z "$WORK_ITEM_ID" || -z "$SLICE_ID" || -z "$ROLE" ]]; then
  usage
  exit 1
fi

case "$ROLE" in
  architect|implementer|reviewer|tester) ;;
  *)
    echo "Invalid role: $ROLE" >&2
    exit 1
    ;;
esac

REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
WORK_ITEM_PATH="$REPO_ROOT/work-items/$WORK_ITEM_ID"
SLICE_PATH="$WORK_ITEM_PATH/slices/$SLICE_ID"
ISSUES_PATH="$SLICE_PATH/issues"
SLICE_REL="work-items/$WORK_ITEM_ID/slices/$SLICE_ID"
ISSUES_REL="$SLICE_REL/issues"
RUN_ID="run-$(date +%Y%m%dT%H%M%S)-$$"

ARTIFACTS_WRITTEN=()
ISSUES_OPEN=()
ISSUES_CREATED=()
NEXT_ALLOWED_ROLES=()

if [[ ! -d "$WORK_ITEM_PATH" ]]; then
  compute_next_allowed_roles
  emit_result "validation_error" "work item not found: $WORK_ITEM_ID" 2
fi

if [[ ! -d "$SLICE_PATH" ]]; then
  compute_next_allowed_roles
  emit_result "validation_error" "slice not found: $SLICE_ID" 2
fi

mkdir -p "$ISSUES_PATH"

TMP_DIR=$(mktemp -d /tmp/run-role.XXXXXX)
trap 'rm -rf "$TMP_DIR" /tmp/run-role-codex-${RUN_ID}.log >/dev/null 2>&1 || true' EXIT
PROMPT_FILE="$TMP_DIR/prompt.txt"
BEFORE_SNAPSHOT="$TMP_DIR/before.snapshot"
AFTER_SNAPSHOT="$TMP_DIR/after.snapshot"

snapshot_files "$SLICE_PATH" "$BEFORE_SNAPSHOT"

implementer_count=$(count_files 'implementer-pass-*.md')
reviewer_count=$(count_files 'reviewer-pass-*.md')

PASS_LABEL=""
VALIDATION_MSG=""

case "$ROLE" in
  architect)
    PASS_LABEL="architect"
    ;;
  implementer)
    if [[ ! -f "$SLICE_PATH/SPEC.md" ]]; then
      VALIDATION_MSG="implementer requires SPEC.md"
    elif [[ "$implementer_count" -eq 0 ]]; then
      PASS_LABEL="implementer-pass-1"
    elif [[ "$implementer_count" -eq 1 ]]; then
      if has_open_issues; then
        PASS_LABEL="implementer-pass-2"
      else
        VALIDATION_MSG="implementer pass-2 requires open reviewer/tester issues"
      fi
    else
      VALIDATION_MSG="implementer pass limit reached (max 2)"
    fi
    ;;
  reviewer)
    if [[ "$reviewer_count" -eq 0 ]]; then
      if [[ -f "$SLICE_PATH/implementer-pass-1.md" ]]; then
        PASS_LABEL="reviewer-pass-1"
      else
        VALIDATION_MSG="reviewer pass-1 requires implementer-pass-1.md"
      fi
    elif [[ "$reviewer_count" -eq 1 ]]; then
      if [[ -f "$SLICE_PATH/implementer-pass-2.md" ]]; then
        PASS_LABEL="reviewer-pass-2"
      else
        VALIDATION_MSG="reviewer pass-2 requires implementer-pass-2.md"
      fi
    else
      VALIDATION_MSG="reviewer pass limit reached (max 2)"
    fi
    ;;
  tester)
    if reviewer_approved; then
      PASS_LABEL="tester"
    else
      VALIDATION_MSG="tester requires approved reviewer pass"
    fi
    ;;
esac

if [[ -n "$VALIDATION_MSG" ]]; then
  collect_open_issues
  compute_next_allowed_roles
  emit_result "validation_error" "$VALIDATION_MSG" 2
fi

build_prompt "$PASS_LABEL"
run_codex

snapshot_files "$SLICE_PATH" "$AFTER_SNAPSHOT"
compute_artifact_changes
collect_open_issues
compute_next_allowed_roles

emit_result "success" "role executed" 0
