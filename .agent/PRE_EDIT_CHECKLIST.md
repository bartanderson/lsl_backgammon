# Pre-Edit Checklist

**Reality Check:** The agent will use standard tools despite instructions. Focus on what actually works: verification and git commits.

Before editing any LSL file:

1.  **[ ] View First**
    *   Use `view_file` to get exact, current line numbers
    *   Never use stale line numbers from previous views

2.  **[ ] Git Status Check**
    *   Run `git status` to see current state
    *   Ensure previous edits are committed

3.  **[ ] Single File Focus**
    *   Are you making multiple edits to the same file?
    *   **STOP**: Do them one by one
    *   **VERIFY**: `view_file` after *each* edit to confirm line numbers for the next step

## POST-EDIT VERIFICATION (MANDATORY)

**After EVERY edit to an LSL file, you MUST complete this checklist:**

1.  **[ ] View Result**
    *   Use `view_file` to view edited section PLUS 10 lines before and after
    *   This catches context issues like orphaned braces

2.  **[ ] Check Syntax**
    *   Balanced braces: Every `{` has matching `}`
    *   Proper `else if` chains: No missing conditions
    *   No orphaned statements: Every statement inside proper block
    *   LSL-specific: Check for proper semicolons, quotes

3.  **[ ] Verify Logic**
    *   Does the edit make sense in context?
    *   Are there unintended side effects?
    *   Did the replacement preserve surrounding code?

4.  **[ ] Commit Immediately (THE REAL SAFETY NET)**
    *   `git add <file>`
    *   `git commit -m "Descriptive message"`
    *   This allows instant rollback if problems discovered later
    *   **DO NOT** accumulate multiple LSL edits before committing

5.  **[ ] If Issues Found**
    *   Fix IMMEDIATELY before proceeding
    *   Do NOT make additional edits with syntax errors present
    *   Use `git restore <file>` to rollback if needed

**Why immediate commits work:** You (the user) can monitor git history and instantly revert bad changes. This is more reliable than trying to prevent the agent from using certain tools.


## POST-EDIT VERIFICATION (MANDATORY)

**After EVERY `safe_edit.py` call, you MUST complete this checklist:**

1.  **[ ] View Result**
    *   Use `view_file` to view edited section PLUS 10 lines before and after
    *   This catches context issues like orphaned braces

2.  **[ ] Check Syntax**
    *   Balanced braces: Every `{` has matching `}`
    *   Proper `else if` chains: No missing conditions
    *   No orphaned statements: Every statement inside proper block
    *   LSL-specific: Check for proper semicolons, quotes

3.  **[ ] Verify Logic**
    *   Does the edit make sense in context?
    *   Are there unintended side effects?
    *   Did the replacement preserve surrounding code?

4.  **[ ] If Issues Found**
    *   Fix IMMEDIATELY before proceeding
    *   Do NOT make additional edits with syntax errors present

**Skipping this verification has caused multiple file corruptions. It is NOT optional.**
