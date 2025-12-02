# Agent Rules & Best Practices

## 🔍 Searching
- **grep_search Tool**:
  - **ALWAYS** set `MatchPerLine: true` to ensure line numbers and content are returned.
  - Only set `MatchPerLine: false` if you specifically only need a list of filenames.
- **PowerShell**:
  - Use `Select-String` instead of `grep`.

## ✏️ Editing
- **LSL Files (.lsl)**:
  - **MANDATORY**: Use `.agent/tools/safe_edit.py` for ALL edits.
  - **FORBIDDEN**: Do NOT use `replace_file_content` or `multi_replace_file_content` on .lsl files directly.
- **PowerShell**:
  - Use `Remove-Item` instead of `rm`.
- **Commits**:
  - Commit immediately after successful edits. This is your primary safety net.

## 🛡️ General
- **LSL Coding**:
  - Use `llParseStringKeepNulls` instead of `llParseString2List` for consistent empty string handling.
  - **FORBIDDEN**: LSL does NOT support `continue` or `break` statements. Use conditional logic instead.
  - **FORBIDDEN**: LSL does NOT support `switch` statements. Use `if/else if` chains instead.
  - **FORBIDDEN**: LSL does NOT support ternary operators (`? :`). Use `if/else` statements instead.
- **File Reading**:
  - Use `Get-Content` instead of `cat` in PowerShell.
