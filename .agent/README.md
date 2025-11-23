# Agent Startup Checklist

**MANDATORY: Read this FIRST when resuming work on this project**

## Step 1: Review Project Guidelines (ALWAYS)
1. Read `DEVELOPMENT_GUIDELINES.md` - File editing rules
2. Read `.agent/PRE_EDIT_CHECKLIST.md` - Pre-edit checklist
3. Check `task.md` in artifacts dir - Current task status

## Step 2: Available Tools
- `.agent/tools/safe_edit.py` - Safe file editing with backups and validation
  - Usage: `python .agent/tools/safe_edit.py <file> <start_line> <end_line> <replacement_file>`
  - Creates automatic backups
  - Validates changes
  - Warns on suspicious edits

## Step 3: Project-Specific Files to Check
- `BUGS_TRACKER.md` - Known bugs and their status
- `implementation_plan.md` (in artifacts) - Current implementation plan if active
- `DEVELOPMENT_GUIDELINES.md` - Critical file editing rules

## Step 4: Git Status Check
Always check:
```bash
git status
git log --oneline -5
```

## Critical Rules Summary
1. **Files >300 lines**: Use `write_to_file` or `.agent/tools/safe_edit.py` - NEVER `replace_file_content`
2. **Before ANY edit**: Check file line count first
3. **After ANY edit**: Commit immediately to git
4. **LSL-specific**: Use `llParseStringKeepNulls` not `llParseString2List`

## Why safe_edit.py "disappeared"
- Created with `write_to_file` but not immediately committed
- File existed in session but not in git
- Now properly committed and tracked
- Always commit tools immediately after creation

## If Tools Are Missing
1. Check git: `git log --all --oneline -- .agent/`
2. Restore from git: `git checkout HEAD -- .agent/tools/safe_edit.py`
3. Or recreate from git history: `git show HEAD:.agent/tools/safe_edit.py`
