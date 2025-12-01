---
description: Mandatory agent initialization when resuming LSL backgammon work
---

# Agent Initialization Workflow

**RUN THIS FIRST when resuming work on LSL backgammon project**

## Step 1: Check Current Task Status
```powershell
Get-Content task.md  # In root directory
```
Review what was in progress.

## Step 2: Review Critical Guidelines
1. Read `DEVELOPMENT_GUIDELINES.md` - **ALL .lsl files MUST use safe_edit.py**
2. Read `.agent/PRE_EDIT_CHECKLIST.md` - Pre-edit checklist

## Step 3: Verify Tools Are Available
```powershell
Test-Path .agent/tools/safe_edit.py
```
If False, restore from git:
```powershell
git checkout HEAD -- .agent/tools/safe_edit.py
```

## Step 4: Check Git Status
```powershell
git status
git log --oneline -5
```

## Step 5: Review Recent Bugs
```powershell
Get-Content BUGS_TRACKER.md
```

## Critical Rules Reminder
- **ALL .lsl files**: Use standard tools with MANDATORY post-edit verification
- Commit immediately after successful edits (THE REAL SAFETY NET)
- LSL: Use `llParseStringKeepNulls` not `llParseString2List`
- **PowerShell**:
  - Use `Remove-Item` instead of `rm`
  - Use `Select-String` instead of `grep`
  - Use `Get-Content` instead of `cat`

## Available Log Analysis Tools
When debugging game logs, remember these tools exist:
- **`python .agent/tools/analyze_log.py <logfile>`** - Tracks piece movements, detects ghosting/teleporting
- **`python verify_moves_v2.py`** - Validates combined moves have valid intermediate positions
- See `.agent/tools/README.md` for details
