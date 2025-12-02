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
1. Read `DEVELOPMENT_GUIDELINES.md` - **Strictly follow the Safety Protocol**
2. Read `.agent/PRE_EDIT_CHECKLIST.md` - Pre-edit checklist
3. Read `.agent/AGENT_RULES.md` - **MANDATORY Agent Rules**

## Step 3: Check Git Status
```powershell
git status
git log --oneline -5
```

## Step 4: Review Recent Bugs
```powershell
Get-Content BUGS_TRACKER.md
```

## Available Log Analysis Tools
When debugging game logs, remember these tools exist:
- **`python .agent/tools/analyze_log.py <logfile>`** - Tracks piece movements, detects ghosting/teleporting
- **`python verify_moves_v2.py`** - Validates combined moves have valid intermediate positions
- See `.agent/tools/README.md` for details
