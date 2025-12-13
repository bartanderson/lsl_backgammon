#!/usr/bin/env python3
"""
Batch replace DEBUG_MODE with LOG_LEVEL checks in LSL files.
This script helps convert hardcoded DEBUG_MODE flags to configurable LOG_LEVEL system.
"""

import re
import sys

def replace_debug_mode(filepath):
    """Replace DEBUG_MODE checks with appropriate LOG_LEVEL checks."""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace if (DEBUG_MODE) with if (LOG_LEVEL >= LOG_DEBUG)
    # Most debug statements should be at DEBUG level
    content = re.sub(
        r'if \(DEBUG_MODE\)',
        r'if (LOG_LEVEL >= LOG_DEBUG)',
        content
    )
    
    # Write back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Updated {filepath}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python replace_debug_mode.py <file>")
        sys.exit(1)
    
    replace_debug_mode(sys.argv[1])
