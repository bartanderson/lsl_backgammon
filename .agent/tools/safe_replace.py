#!/usr/bin/env python3
import sys
import shutil
from pathlib import Path

# Usage: python safe_replace.py <file> <start_line> <end_line> <content_file>
# Replaces lines from start_line to end_line (inclusive, 1-based) with content from content_file.

if len(sys.argv) != 5:
    print("Usage: python safe_replace.py <file> <start_line> <end_line> <content_file>")
    sys.exit(1)

filepath = Path(sys.argv[1])
start_line = int(sys.argv[2])
end_line = int(sys.argv[3])
replacement_file = sys.argv[4]

if not filepath.exists():
    print(f"Error: File {filepath} not found.")
    sys.exit(1)

# Create backup
backup_path = filepath.with_suffix(filepath.suffix + '.backup')
shutil.copy2(filepath, backup_path)
print(f"✓ Created backup: {backup_path}")

# Read original
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

original_count = len(lines)
print(f"✓ Original file: {original_count} lines")

# Read replacement
with open(replacement_file, 'r', encoding='utf-8') as f:
    replacement = f.read()

replacement_lines = replacement.splitlines(keepends=True)
if replacement and not replacement.endswith('\n'):
    replacement_lines[-1] += '\n'

# Perform edit (1-indexed to 0-indexed)
start_index = start_line - 1
end_index = end_line 

if start_index < 0: start_index = 0
if end_index > len(lines): end_index = len(lines)

new_lines = lines[:start_index] + replacement_lines + lines[end_index:]
new_count = len(new_lines)

lines_removed = end_index - start_index
lines_added = len(replacement_lines)
print(f"✓ Edit summary:")
print(f"  - Removed {lines_removed} lines (lines {start_line}-{end_line})")
print(f"  - Added {lines_added} lines")
print(f"  - Net change: {lines_added - lines_removed:+d} lines")
print(f"  - New line count: {new_count}")

# Write
with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"✓ File written successfully")
