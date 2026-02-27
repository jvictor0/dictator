#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: run-role.sh --work-item <id> --slice <id> --role <architect|implementer|reviewer|tester> [--repo-root <path>]
USAGE
}

PASS_COMPLETE_SENTINEL="pass complete"

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
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

is_pass_complete() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local last
  last=$(tail -n 1 "$file" | tr -d '\r')
  [[ "$last" == "$PASS_COMPLETE_SENTINEL" ]]
}

ensure_pass_complete() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  is_pass_complete "$file"
}

count_completed_pass_files() {
  local pattern="$1"
  local count=0
  local file
  while IFS= read -r file; do
    if is_pass_complete "$file"; then
      count=$((count + 1))
    fi
  done < <(find "$SLICE_PATH" -maxdepth 1 -type f -name "$pattern" | sort)
  printf '%s' "$count"
}

pass_file_completed() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  is_pass_complete "$file"
}

artifact_for_pass_label() {
  local pass_label="$1"
  case "$pass_label" in
    architect) printf '%s\n' "$SLICE_PATH/architect.md" ;;
    implementer-pass-1|implementer-pass-2) printf '%s\n' "$SLICE_PATH/$pass_label.md" ;;
    reviewer-pass-1|reviewer-pass-2) printf '%s\n' "$SLICE_PATH/$pass_label.md" ;;
    tester) printf '%s\n' "$SLICE_PATH/tester.md" ;;
    *) return 1 ;;
  esac
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
  if ! pass_file_completed "$SLICE_PATH/$latest"; then
    return 1
  fi
  local lower
  lower=$(tr '[:upper:]' '[:lower:]' < "$SLICE_PATH/$latest")
  if [[ "$lower" == *"not approved"* ]]; then
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
    local status slice_id
    status=$(awk '
      {
        line=$0
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        if (tolower(line) ~ /^[[:space:]]*status[[:space:]]*:/) {
          sub(/^[[:space:]]*[Ss][Tt][Aa][Tt][Uu][Ss][[:space:]]*:[[:space:]]*/, "", line)
          gsub(/[[:space:]]+$/, "", line)
          print toupper(line)
          exit
        }
      }
    ' "$file" || true)
    slice_id=$(awk '
      {
        line=$0
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        if (tolower(line) ~ /^[[:space:]]*slice-id[[:space:]]*:/) {
          sub(/^[[:space:]]*[Ss][Ll][Ii][Cc][Ee]-[Ii][Dd][[:space:]]*:[[:space:]]*/, "", line)
          gsub(/[[:space:]]+$/, "", line)
          print line
          exit
        }
      }
    ' "$file" || true)
    if [[ "$status" == "OPEN" ]]; then
      if [[ -z "$slice_id" || "$slice_id" == "$SLICE_ID" ]]; then
        ISSUES_OPEN+=("${file#$REPO_ROOT/}")
      fi
    fi
  done < <(find "$ISSUES_PATH" -maxdepth 1 -type f -name 'issue-*.md' | sort)
}

has_open_issues() {
  collect_open_issues
  [[ ${#ISSUES_OPEN[@]} -gt 0 ]]
}

snapshot_files() {
  local out="$1"
  shift
  : > "$out"
  local base file rel hash
  for base in "$@"; do
    if [[ ! -d "$base" ]]; then
      continue
    fi
    while IFS= read -r file; do
      rel=${file#$REPO_ROOT/}
      hash=$(shasum -a 256 "$file" | awk '{print $1}')
      printf '%s\t%s\n' "$rel" "$hash" >> "$out"
    done < <(find "$base" -type f | sort)
  done
  sort -u -o "$out" "$out"
}

compute_artifact_changes() {
  ARTIFACTS_WRITTEN=()
  ISSUES_CREATED=()

  while IFS= read -r rel; do
    [[ -n "$rel" ]] && ARTIFACTS_WRITTEN+=("$rel")
  done < <(awk -F'\t' 'NR==FNR {before[$1]=$2; next} {if (!($1 in before) || before[$1] != $2) print $1}' "$BEFORE_SNAPSHOT" "$AFTER_SNAPSHOT" | sort)

  while IFS= read -r rel; do
    [[ -n "$rel" ]] && ISSUES_CREATED+=("$rel")
  done < <(awk -F'\t' \
    -v issuePattern="^"$(printf '%s' "$ISSUES_REL" | sed 's/[.[\\*^$(){}?+|]/\\&/g')"/issue-" \
    'NR==FNR {before[$1]=1; next} {if ($1 ~ issuePattern && !($1 in before)) print $1}' \
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

  NEXT_ALLOWED_ROLES+=("architect")

  if [[ -f "$spec" ]]; then
    if ! pass_file_completed "$SLICE_PATH/implementer-pass-1.md"; then
      NEXT_ALLOWED_ROLES+=("implementer")
    elif has_open_issues && ! pass_file_completed "$SLICE_PATH/implementer-pass-2.md"; then
      NEXT_ALLOWED_ROLES+=("implementer")
    fi
  fi

  if pass_file_completed "$SLICE_PATH/implementer-pass-1.md" && ! pass_file_completed "$SLICE_PATH/reviewer-pass-1.md"; then
    NEXT_ALLOWED_ROLES+=("reviewer")
  elif pass_file_completed "$SLICE_PATH/implementer-pass-2.md" && pass_file_completed "$SLICE_PATH/reviewer-pass-1.md" && ! pass_file_completed "$SLICE_PATH/reviewer-pass-2.md"; then
    NEXT_ALLOWED_ROLES+=("reviewer")
  fi

  if reviewer_approved && ! pass_file_completed "$SLICE_PATH/tester.md"; then
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
4. Use work-item issues at $ISSUES_PATH, file names issue-0001.md, issue-0002.md, etc.
5. If no changes are needed, write an explicit no-op statement in the role artifact.
6. Never create extra pass files beyond the requested pass.
7. The role artifact for this run must end with the exact last line: pass complete

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
ISSUES_PATH="$WORK_ITEM_PATH/issues"
SLICE_REL="work-items/$WORK_ITEM_ID/slices/$SLICE_ID"
ISSUES_REL="work-items/$WORK_ITEM_ID/issues"
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

snapshot_files "$BEFORE_SNAPSHOT" "$SLICE_PATH" "$ISSUES_PATH"

PASS_LABEL=""
VALIDATION_MSG=""
SHORT_CIRCUIT_MSG=""

case "$ROLE" in
  architect)
    PASS_LABEL="architect"
    if pass_file_completed "$SLICE_PATH/architect.md"; then
      SHORT_CIRCUIT_MSG="pass already complete: architect"
    fi
    ;;
  implementer)
    if [[ ! -f "$SLICE_PATH/SPEC.md" ]]; then
      VALIDATION_MSG="implementer requires SPEC.md"
    elif pass_file_completed "$SLICE_PATH/implementer-pass-2.md"; then
      PASS_LABEL="implementer-pass-2"
      SHORT_CIRCUIT_MSG="pass already complete: implementer-pass-2"
    elif ! pass_file_completed "$SLICE_PATH/implementer-pass-1.md"; then
      PASS_LABEL="implementer-pass-1"
    elif has_open_issues; then
      PASS_LABEL="implementer-pass-2"
      if pass_file_completed "$SLICE_PATH/implementer-pass-2.md"; then
        SHORT_CIRCUIT_MSG="pass already complete: implementer-pass-2"
      fi
    else
      PASS_LABEL="implementer-pass-1"
      SHORT_CIRCUIT_MSG="pass already complete: implementer-pass-1"
    fi
    ;;
  reviewer)
    if pass_file_completed "$SLICE_PATH/reviewer-pass-2.md"; then
      PASS_LABEL="reviewer-pass-2"
      SHORT_CIRCUIT_MSG="pass already complete: reviewer-pass-2"
    elif ! pass_file_completed "$SLICE_PATH/reviewer-pass-1.md"; then
      if pass_file_completed "$SLICE_PATH/implementer-pass-1.md"; then
        PASS_LABEL="reviewer-pass-1"
      else
        VALIDATION_MSG="reviewer pass-1 requires implementer-pass-1.md"
      fi
    elif pass_file_completed "$SLICE_PATH/implementer-pass-2.md"; then
      PASS_LABEL="reviewer-pass-2"
      if pass_file_completed "$SLICE_PATH/reviewer-pass-2.md"; then
        SHORT_CIRCUIT_MSG="pass already complete: reviewer-pass-2"
      fi
    else
      PASS_LABEL="reviewer-pass-1"
      SHORT_CIRCUIT_MSG="pass already complete: reviewer-pass-1"
    fi
    ;;
  tester)
    if pass_file_completed "$SLICE_PATH/tester.md"; then
      PASS_LABEL="tester"
      SHORT_CIRCUIT_MSG="pass already complete: tester"
    elif reviewer_approved; then
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

if [[ -n "$SHORT_CIRCUIT_MSG" ]]; then
  collect_open_issues
  compute_next_allowed_roles
  emit_result "success" "$SHORT_CIRCUIT_MSG" 0
fi

build_prompt "$PASS_LABEL"
run_codex

PASS_ARTIFACT=""
if PASS_ARTIFACT=$(artifact_for_pass_label "$PASS_LABEL"); then
  if [[ ! -f "$PASS_ARTIFACT" ]]; then
    emit_result "validation_error" "expected role artifact not found: ${PASS_ARTIFACT#$REPO_ROOT/}" 2
  fi
  if ! ensure_pass_complete "$PASS_ARTIFACT"; then
    emit_result "validation_error" "role artifact missing completion sentinel on last line: ${PASS_ARTIFACT#$REPO_ROOT/}" 2
  fi
fi

snapshot_files "$AFTER_SNAPSHOT" "$SLICE_PATH" "$ISSUES_PATH"
compute_artifact_changes
collect_open_issues
compute_next_allowed_roles

emit_result "success" "role executed" 0
