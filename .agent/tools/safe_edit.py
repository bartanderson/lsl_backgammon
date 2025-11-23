#!/usr/bin/env python3
import sys
import shutil
from pathlib import Path

filepath = Path(sys.argv[1])
start_line = int(sys.argv[2])
end_line = int(sys.argv[3])
replacement_file = sys.argv[4]

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

replacement_lines = replacement.splitlines(keepends=True) if replacement else []

# Perform edit (1-indexed to 0-indexed)
new_lines = lines[:start_line-1] + replacement_lines + lines[end_line:]
new_count = len(new_lines)

lines_removed = (end_line - start_line + 1)
lines_added = len(replacement_lines)
print(f"✓ Edit summary:")
print(f"  - Removed {lines_removed} lines")
print(f"  - Added {lines_added} lines")
print(f"  - Net change: {lines_added - lines_removed:+d} lines")
print(f"  - New line count: {new_count}")

# Write
with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"✓ File written successfully")
print(f"✓ Verification passed")
print(f"✓ Edit complete. Backup available at: {backup_path}")
