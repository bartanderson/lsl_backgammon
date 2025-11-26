#!/usr/bin/env python3
import sys
import shutil
from pathlib import Path

# Usage: python safe_delete.py <file> <start_line> <end_line>
# Deletes lines from start_line to end_line (inclusive, 1-based).

if len(sys.argv) != 4:
    print("Usage: python safe_delete.py <file> <start_line> <end_line>")
    sys.exit(1)

filepath = Path(sys.argv[1])
start_line = int(sys.argv[2])
end_line = int(sys.argv[3])

if not filepath.exists():
    print(f"Error: File {filepath} not found.")
    sys.exit(1)

if start_line > end_line:
    print("Error: start_line must be <= end_line")
    sys.exit(1)

if start_line < 1:
    print("Error: start_line must be >= 1")
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

# Perform deletion
# Convert 1-based to 0-based
# start_line 1 -> index 0
# end_line 1 -> index 0 (slice up to 1)
start_index = start_line - 1
end_index = end_line # Slice is exclusive at the end, so end_line is correct index for slice end

if start_index >= len(lines):
    print("Error: Start line is beyond end of file.")
    sys.exit(1)

new_lines = lines[:start_index] + lines[end_index:]
new_count = len(new_lines)

lines_removed = end_index - start_index
print(f"✓ Edit summary:")
print(f"  - Removed {lines_removed} lines (lines {start_line}-{end_line})")
print(f"  - New line count: {new_count}")

# Write
with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"✓ File written successfully")
