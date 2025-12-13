#!/usr/bin/env python3
"""
Fix nested function calls in LSL scripts.
LSL doesn't support nested function calls like llStringTrim(llGetSubString(...))
"""

import re

def fix_nested_calls(filepath):
    """Fix nested llStringTrim(llGetSubString(...)) calls."""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to find: llStringTrim(llGetSubString(line, 0, eqPos - 1), STRING_TRIM)
    # Replace with two separate statements
    
    # Find the pattern for key extraction
    pattern1 = r'string key = llStringTrim\(llGetSubString\(line, 0, eqPos - 1\), STRING_TRIM\);'
    replacement1 = '''string keyRaw = llGetSubString(line, 0, eqPos - 1);
                        string key = llStringTrim(keyRaw, STRING_TRIM);'''
    
    content = re.sub(pattern1, replacement1, content)
    
    # Find the pattern for value extraction
    pattern2 = r'string value = llStringTrim\(llGetSubString\(line, eqPos \+ 1, -1\), STRING_TRIM\);'
    replacement2 = '''string valueRaw = llGetSubString(line, eqPos + 1, -1);
                        string value = llStringTrim(valueRaw, STRING_TRIM);'''
    
    content = re.sub(pattern2, replacement2, content)
    
    # Write back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Fixed {filepath}")

# Fix all LSL scripts
scripts = [
    'backgammon_core.lsl',
    'backgammon_ui.lsl',
    'backgammon_render.lsl',
    'backgammon_AI.lsl',
    'backgammon_menu.lsl',
    'Backgammon_persistence.lsl'
]

for script in scripts:
    try:
        fix_nested_calls(script)
    except Exception as e:
        print(f"Error fixing {script}: {e}")
