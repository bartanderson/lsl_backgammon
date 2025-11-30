# LSL Backgammon Development Guidelines

## 1. File Editing Rules - THE REAL SAFETY NET

**Reality Check:** The agent will use `replace_file_content` and `multi_replace_file_content` despite instructions otherwise. Accept this and focus on safety nets that actually work.

### Mandatory Safety Protocol for ALL LSL Edits:

1. **BEFORE Edit:**
   - `view_file` to get exact, current line numbers
   - Never use stale line numbers from previous views

2. **DURING Edit:**
   - Use `replace_file_content` for single, contiguous edits
   - Use `multi_replace_file_content` for multiple non-contiguous edits
   - **NEVER** make multiple edits to the same file in parallel

3. **AFTER Edit (MANDATORY - NOT OPTIONAL):**
   - `view_file` the edited section PLUS 10 lines before and after
   - Verify syntax: Balanced braces `{}`, proper `else if` chains, no orphaned statements
   - Verify logic: Edit makes sense in context
   - **If ANY issues found**: Fix IMMEDIATELY before proceeding

4. **COMMIT Immediately (THE REAL SAFETY NET):**
   - After successful edit + verification, commit to git IMMEDIATELY
   - Use descriptive commit message
   - This allows instant rollback if problems discovered later
   - **DO NOT** accumulate multiple LSL edits before committing

### Why This Works:
- Post-edit verification catches corruption early
- Immediate git commits provide instant rollback capability
- You (the user) can monitor git history and revert bad changes
- Accepts agent behavior reality rather than fighting it

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
*   **Logic Trace (MANDATORY)**:
    *   Before writing any loop or index calculation, explicitly trace the bounds (Start, End, Count) in your thought process.
    *   Verify 0-based vs 1-based indexing for every list operation.
    *   **STOP** and verify math like `count - index` or `limit - start`. Do not assume it is trivial.

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
    *   Always run the `/initialize` or `/resume` workflow at the start of a session to ensure the environment is ready.
*   **Pre-Edit Check**:
    *   Consult `.agent/PRE_EDIT_CHECKLIST.md` before making changes to critical files.
