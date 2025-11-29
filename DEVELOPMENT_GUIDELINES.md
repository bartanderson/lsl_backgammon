# LSL Backgammon Development Guidelines

## 1. File Editing Rules
*   **ALL LSL Files**:
    *   **MUST** use `.agent/tools/safe_edit.py` for ANY edits to `.lsl` files.
    *   **NEVER** use `replace_file_content` or `multi_replace_file_content` on LSL files. These tools are unreliable for LSL files (especially with CRLF line endings) and cause file corruption.
    *   The 300-line threshold mentioned previously was too lax - use `safe_edit.py` for ALL LSL files regardless of size.
*   **Pre-commit Hook**:
    *   A git pre-commit hook enforces this rule for files >300 lines.
    *   Commits modifying large LSL files MUST include "SAFE_EDIT" in the commit message.
    *   If the hook blocks your commit, use: `git commit --no-verify -m "SAFE_EDIT: your message"`
*   **safe_edit.py Usage**:
    ```bash
    # 1. Create a temp file with the replacement content
    # 2. Run safe_edit.py with: filepath start_line end_line replacement_file
    python .agent/tools/safe_edit.py backgammon_render.lsl 241 249 .temp_replacement.txt
    # 3. Clean up temp files after committing
    ```
*   **Sequential Edits**:
    *   **NEVER** queue multiple `safe_edit.py` calls for the same file in a single turn.
    *   **ALWAYS** `view_file` after *every* edit to re-verify line numbers before the next edit.
    *   Line numbers shift after every edit. Guessing new line numbers is the #1 cause of file corruption.
*   **Post-Edit Verification (MANDATORY)**:
    *   After **EVERY** `safe_edit.py` call, you MUST:
        1. `view_file` the edited section plus 10 lines before and after
        2. Verify syntax: Check for balanced braces `{}`, proper `else if` chains, no orphaned statements
        3. Verify logic: Ensure the edit makes sense in context
        4. **If any issues found**, fix them IMMEDIATELY before proceeding
    *   This is NOT optional. Skipping verification has caused multiple file corruptions.


## 2. LSL Coding Standards
*   **String Parsing**:
    *   Use `llParseStringKeepNulls` instead of `llParseString2List`. The latter strips empty strings, which can break list indexing when parsing serialized data (e.g., game state).
*   **Memory Management**:
    *   LSL scripts have a hard memory limit (64KB for Mono). Be mindful of large lists or strings.
    *   Use global variables for large data structures to avoid stack overflow, but be careful with state changes.
*   **Event Handling**:
    *   Keep event handlers concise. Long processing blocks can block other events.
*   **Syntax Limitations**:
    *   **NO Ternary Operators**: LSL does not support the `condition ? true : false` syntax. Use standard `if/else` blocks.

## 3. Git Workflow
*   **Commit Frequency**:
    *   Commit immediately after **every** successful edit or logical set of edits.
    *   Do not accumulate multiple unrelated changes in a single commit.
*   **Commit Messages**:
    *   Use descriptive messages explaining *what* changed and *why*.
*   **Safety**:
    *   Always ensure the code compiles (if possible to check) or is at least syntactically plausible before committing.

## 4. Agent Behavior
*   **Initialization**:
    *   Always run the `/initialize` workflow at the start of a session to ensure the environment is ready.
*   **Pre-Edit Check**:
    *   Consult `.agent/PRE_EDIT_CHECKLIST.md` before making changes to critical files.
