#!/usr/bin/env python3
"""Execute a role workflow and print artifacts after each run."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


DEFAULT_SEQUENCE = ["architect", "implementer", "reviewer", "tester"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a sequence of roles via scripts/run-role.sh and print slice artifacts after each run."
    )
    parser.add_argument("--work-item", required=True, help="Work item id")
    parser.add_argument("--slice", required=True, dest="slice_id", help="Slice id")
    parser.add_argument(
        "--repo-root",
        default=os.getcwd(),
        help="Repository root path (default: current directory)",
    )
    parser.add_argument(
        "--runner",
        default=None,
        help="Path to run-role.sh (default: <repo-root>/scripts/run-role.sh)",
    )
    parser.add_argument(
        "--sequence",
        default=",".join(DEFAULT_SEQUENCE),
        help="Comma-separated role sequence (default: architect,implementer,reviewer,tester)",
    )
    parser.add_argument(
        "--continue-on-error",
        action="store_true",
        help="Continue executing remaining roles when a run fails",
    )
    parser.add_argument(
        "--env",
        action="append",
        default=[],
        help="Extra environment variable in KEY=VALUE form (repeatable)",
    )
    return parser.parse_args()


def parse_env(entries: list[str]) -> dict[str, str]:
    merged: dict[str, str] = {}
    for entry in entries:
        if "=" not in entry:
            raise ValueError(f"Invalid --env entry: {entry!r}. Expected KEY=VALUE.")
        key, value = entry.split("=", 1)
        key = key.strip()
        if not key:
            raise ValueError(f"Invalid --env entry with empty key: {entry!r}")
        merged[key] = value
    return merged


def list_artifacts(slice_path: Path) -> list[str]:
    if not slice_path.exists():
        return []
    artifacts: list[str] = []
    for path in sorted(slice_path.rglob("*")):
        if path.is_file():
            artifacts.append(path.relative_to(slice_path).as_posix())
    return artifacts


def read_issue_statuses(work_item_path: Path, slice_id: str) -> list[str]:
    issues_dir = work_item_path / "issues"
    if not issues_dir.exists():
        return []

    statuses: list[str] = []
    for issue_file in sorted(issues_dir.glob("issue-*.md")):
        status = "UNKNOWN"
        issue_slice_id = ""
        try:
            for raw_line in issue_file.read_text(encoding="utf-8").splitlines():
                line = raw_line.strip()
                normalized = line.lstrip("-").strip()
                if normalized.lower().startswith("slice-id:"):
                    issue_slice_id = normalized.split(":", 1)[1].strip()
                if normalized.lower().startswith("status:"):
                    status = normalized.split(":", 1)[1].strip().upper() or "UNKNOWN"
            if issue_slice_id and issue_slice_id != slice_id:
                continue
        except OSError:
            status = "UNREADABLE"
        suffix = f" (Slice-ID: {issue_slice_id})" if issue_slice_id else ""
        statuses.append(f"{issue_file.name}: {status}{suffix}")
    return statuses


def is_pass_complete(file_path: Path) -> bool:
    try:
        if not file_path.exists():
            return False
        last_line = file_path.read_text(encoding="utf-8").splitlines()[-1].strip()
        return last_line == "pass complete"
    except (OSError, IndexError):
        return False


def reviewer_approved(slice_path: Path) -> bool:
    reviewer_files = sorted(slice_path.glob("reviewer-pass-*.md"))
    if not reviewer_files:
        return False
    latest = reviewer_files[-1]
    if not is_pass_complete(latest):
        return False
    try:
        lower = latest.read_text(encoding="utf-8").lower()
    except OSError:
        return False
    if "not approved" in lower:
        return False
    return "approved" in lower


def slice_done(slice_path: Path) -> bool:
    tester = slice_path / "tester.md"
    return is_pass_complete(tester) and reviewer_approved(slice_path)


def resolve_open_slice_issues(work_item_path: Path, slice_id: str) -> list[str]:
    issues_dir = work_item_path / "issues"
    if not issues_dir.exists():
        return []

    resolved: list[str] = []
    for issue_file in sorted(issues_dir.glob("issue-*.md")):
        try:
            lines = issue_file.read_text(encoding="utf-8").splitlines()
        except OSError:
            continue

        status_index = -1
        status_value = ""
        issue_slice_id = ""
        for idx, raw_line in enumerate(lines):
            normalized = raw_line.strip().lstrip("-").strip()
            if normalized.lower().startswith("status:"):
                status_index = idx
                status_value = normalized.split(":", 1)[1].strip().upper()
            elif normalized.lower().startswith("slice-id:"):
                issue_slice_id = normalized.split(":", 1)[1].strip()

        if status_index < 0 or status_value != "OPEN":
            continue
        if issue_slice_id and issue_slice_id != slice_id:
            continue

        original = lines[status_index]
        updated = re.sub(
            r"(?i)^(\s*-\s*status\s*:\s*)open(\s*)$",
            r"\1RESOLVED\2",
            original,
        )
        if updated == original:
            updated = re.sub(
                r"(?i)^(\s*status\s*:\s*)open(\s*)$",
                r"\1RESOLVED\2",
                original,
            )
        if updated == original:
            continue

        lines[status_index] = updated
        try:
            issue_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
        except OSError:
            continue
        resolved.append(issue_file.name)

    return resolved


def run_role(
    runner: Path,
    repo_root: Path,
    work_item: str,
    slice_id: str,
    role: str,
    extra_env: dict[str, str],
) -> tuple[int, dict[str, Any], str]:
    cmd = [
        str(runner),
        "--work-item",
        work_item,
        "--slice",
        slice_id,
        "--role",
        role,
        "--repo-root",
        str(repo_root),
    ]

    env = dict(os.environ)
    env.update(extra_env)

    completed = subprocess.run(
        cmd,
        check=False,
        text=True,
        capture_output=True,
        env=env,
    )

    stdout = completed.stdout.strip()
    stderr = completed.stderr.strip()

    payload: dict[str, Any]
    if stdout:
        try:
            payload = json.loads(stdout)
        except json.JSONDecodeError:
            payload = {
                "status": "execution_error",
                "message": "runner returned non-JSON output",
                "raw_stdout": stdout,
            }
    else:
        payload = {
            "status": "execution_error",
            "message": "runner returned empty output",
        }

    return completed.returncode, payload, stderr


def print_run_report(
    run_index: int,
    requested_role: str,
    exit_code: int,
    payload: dict[str, Any],
    stderr: str,
    work_item_path: Path,
    slice_path: Path,
    slice_id: str,
) -> None:
    print(f"\n=== Run {run_index}: {requested_role} ===")
    print(f"exit_code: {exit_code}")
    print(f"status: {payload.get('status', 'unknown')}")
    print(f"message: {payload.get('message', '')}")

    def print_list(label: str, key: str) -> None:
        items = payload.get(key, [])
        if not isinstance(items, list):
            items = [str(items)]
        print(f"{label}:")
        if not items:
            print("  - (none)")
            return
        for item in items:
            print(f"  - {item}")

    print_list("artifacts_written", "artifacts_written")
    print_list("issues_created", "issues_created")
    print_list("issues_open", "issues_open")
    print_list("next_allowed_roles", "next_allowed_roles")

    artifacts = list_artifacts(slice_path)
    print("slice_artifacts:")
    if not artifacts:
        print("  - (none)")
    else:
        for artifact in artifacts:
            print(f"  - {artifact}")

    issue_statuses = read_issue_statuses(work_item_path, slice_id)
    print("issue_statuses:")
    if not issue_statuses:
        print("  - (none)")
    else:
        for status in issue_statuses:
            print(f"  - {status}")

    if stderr:
        print("stderr:")
        for line in stderr.splitlines():
            print(f"  {line}")


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    runner = Path(args.runner).resolve() if args.runner else repo_root / "scripts" / "run-role.sh"

    if not runner.exists():
        print(f"Runner not found: {runner}", file=sys.stderr)
        return 2

    try:
        extra_env = parse_env(args.env)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 2

    sequence = [item.strip() for item in args.sequence.split(",") if item.strip()]
    if not sequence:
        print("Empty --sequence is not allowed", file=sys.stderr)
        return 2

    slice_path = repo_root / "work-items" / args.work_item / "slices" / args.slice_id
    work_item_path = repo_root / "work-items" / args.work_item

    final_exit = 0
    tester_ran_successfully = False
    for index, role in enumerate(sequence, start=1):
        exit_code, payload, stderr = run_role(
            runner=runner,
            repo_root=repo_root,
            work_item=args.work_item,
            slice_id=args.slice_id,
            role=role,
            extra_env=extra_env,
        )

        print_run_report(index, role, exit_code, payload, stderr, work_item_path, slice_path, args.slice_id)
        if role == "tester" and exit_code == 0 and payload.get("status") == "success":
            tester_ran_successfully = True

        if exit_code != 0:
            final_exit = exit_code
            if not args.continue_on_error:
                break

    if final_exit == 0 and tester_ran_successfully and slice_done(slice_path):
        resolved = resolve_open_slice_issues(work_item_path, args.slice_id)
        if resolved:
            print("\nauto_resolved_issues:")
            for issue_name in resolved:
                print(f"  - {issue_name}")
            print("issue_statuses_after_auto_resolve:")
            for status in read_issue_statuses(work_item_path, args.slice_id):
                print(f"  - {status}")

    return final_exit


if __name__ == "__main__":
    raise SystemExit(main())
