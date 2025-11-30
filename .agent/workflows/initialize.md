---
description: Mandatory agent initialization when resuming LSL backgammon work
---

# Agent Initialization Workflow

**RUN THIS FIRST when resuming work on LSL backgammon project**

## Step 1: Check Current Task Status
```bash
cat task.md  # In artifacts directory
```
Review what was in progress.

## Step 2: Review Critical Guidelines
1. Read `DEVELOPMENT_GUIDELINES.md` - **ALL .lsl files MUST use safe_edit.py**
2. Read `.agent/PRE_EDIT_CHECKLIST.md` - Pre-edit checklist

## Step 3: Verify Tools Are Available
```bash
ls .agent/tools/safe_edit.py
```
If missing, restore from git:
```bash
git checkout HEAD -- .agent/tools/safe_edit.py
```

## Step 4: Check Git Status
```bash
git status
git log --oneline -5
```

## Step 5: Review Recent Bugs
```bash
cat BUGS_TRACKER.md
```

## Critical Rules Reminder
- **ALL .lsl files**: MUST use `safe_edit.py` - NEVER use replace_file_content
- Pre-commit hook requires "SAFE_EDIT" in commit message for large files
- Commit immediately after successful edits
- LSL: Use `llParseStringKeepNulls` not `llParseString2List`
- **PowerShell**:
  - Do NOT use `rm`. Use `Remove-Item`.
  - Do NOT use `grep`. Use `Select-String` or the `grep_search` tool.
