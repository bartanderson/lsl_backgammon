# Pre-Edit Checklist

Before editing any file in this project, verify the following:

1.  **[ ] LSL File Check**
    *   Is this a `.lsl` file?
    *   **YES**: **MUST** use `.agent/tools/safe_edit.py`. **NEVER** use `replace_file_content` or `multi_replace_file_content`.
    *   **NO**: Standard tools are acceptable.

2.  **[ ] Backup Check**
    *   Is this a critical file (`backgammon_*.lsl`)?
    *   If yes, is there a recent git commit?
    *   If unsure, `safe_edit.py` automatically creates backups.

3.  **[ ] Context Check**
    *   Have you read enough of the file to understand the context of the change?
    *   Do you have the latest version of the file? (Check `git status` or `ls -l` timestamp).

4.  **[ ] LSL Specifics**
    *   Are you using `llParseStringKeepNulls`?
    *   Are you avoiding known LSL pitfalls?

5.  **[ ] Commit Message**
    *   For large LSL files (>300 lines), include "SAFE_EDIT" in commit message
    *   Or use `git commit --no-verify` if the pre-commit hook blocks you
