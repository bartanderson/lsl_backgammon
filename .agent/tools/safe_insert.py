#!/usr/bin/env python3
import sys
import shutil
from pathlib import Path

# Usage: python safe_insert.py <file> <line_num> <content_file>
# Inserts content AFTER line_num (1-based). 
# If line_num is 0, inserts at the beginning.

if len(sys.argv) != 4:
    print("Usage: python safe_insert.py <file> <line_num> <content_file>")
    sys.exit(1)

filepath = Path(sys.argv[1])
insert_after_line = int(sys.argv[2])
content_file = sys.argv[3]

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

# Read content to insert
with open(content_file, 'r', encoding='utf-8') as f:
    insert_content = f.read()

insert_lines = insert_content.splitlines(keepends=True)
if insert_content and not insert_content.endswith('\n'):
    insert_lines[-1] += '\n' # Ensure last line has newline if missing

# Perform insertion
# 1-based index. 
# If insert_after_line is 0, we insert at index 0 (start of file).
# If insert_after_line is 1, we insert at index 1 (after first line).
insert_index = insert_after_line 

if insert_index > len(lines):
    insert_index = len(lines) # Append to end if line number is beyond EOF

new_lines = lines[:insert_index] + insert_lines + lines[insert_index:]
new_count = len(new_lines)

lines_added = len(insert_lines)
print(f"✓ Edit summary:")
print(f"  - Inserted {lines_added} lines after line {insert_after_line}")
print(f"  - New line count: {new_count}")

# Write
with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"✓ File written successfully")
