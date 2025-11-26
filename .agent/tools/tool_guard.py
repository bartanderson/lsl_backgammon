#!/usr/bin/env python3
"""Simple guard that the LLM can call before using a tool.

Usage (conceptual):
    python .agent/tools/tool_guard.py <action> <target_file> [<extra_args>]

Supported actions:
    edit   – check if editing <target_file> is allowed.
            Returns exit code 0 if allowed, 1 otherwise.

The guard reads the same rules that we enforce via .cursorrules and the pre‑commit hook:
* Files >300 lines must be edited with safe_edit.py (or write_to_file for small edits).
* The LLM should not call replace_file_content on large files.

The script prints a short message explaining the decision – the LLM can capture the output
and decide whether to proceed.
"""
import sys
import pathlib

MAX_LINES = 300

def line_count(path: pathlib.Path) -> int:
    try:
        return sum(1 for _ in path.open('r', encoding='utf-8'))
    except Exception as e:
        print(f"Error reading {path}: {e}")
        return 0

def check_edit(target: pathlib.Path) -> bool:
    if not target.exists():
        print(f"File {target} does not exist.")
        return False
    lines = line_count(target)
    if lines > MAX_LINES:
        print(f"File {target} has {lines} lines (> {MAX_LINES}). Must use safe_edit.py.")
        return False
    print(f"File {target} has {lines} lines – safe to edit directly.")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Usage: tool_guard.py <action> <target_file>')
        sys.exit(1)
    action = sys.argv[1]
    target_file = pathlib.Path(sys.argv[2])
    if action == 'edit':
        allowed = check_edit(target_file)
        sys.exit(0 if allowed else 1)
    else:
        print(f'Unsupported action: {action}')
        sys.exit(1)
