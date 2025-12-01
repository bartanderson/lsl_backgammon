---
description: Lightweight initialization for resuming work after a model handoff. Skips heavy environment checks but loads context and rules.
---
1. Read `task.md` to understand the current objective, active task, and overall progress.
2. Check git status to see uncommitted changes: `git status` (and `git log -1` to see last commit).
3. Read `DEVELOPMENT_GUIDELINES.md` to refresh memory on coding standards, **ALL .lsl files MUST use safe_edit.py**, and git practices.
3. Read `.agent/PRE_EDIT_CHECKLIST.md` to ensure compliance with pre-edit safety checks.
4. Read `BUGS_TRACKER.md` to review active issues and their status.
5. **CRITICAL**: Remember that ALL .lsl file edits MUST use `.agent/tools/safe_edit.py` - NEVER use replace_file_content on LSL files.
6. Check the current directory state with `Get-ChildItem -Recurse` if you need to re-orient yourself with the file structure (optional).
7. **PowerShell Warning**:
   - Use `Remove-Item` instead of `rm`
   - Use `Select-String` instead of `grep`
   - Use `Get-Content` instead of `cat`
