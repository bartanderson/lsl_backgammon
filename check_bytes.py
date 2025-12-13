with open('backgammon_AI_brain.lsl', 'rb') as f:
    content = f.read()
    
# Find line 1353
lines = content.split(b'\n')
if len(lines) >= 1353:
    line_1353 = lines[1352]  # 0-indexed
    print(f"Line 1353 (bytes): {line_1353}")
    print(f"Line 1353 (decoded): {line_1353.decode('utf-8', errors='replace')}")
    print(f"Has non-ASCII: {any(b > 127 for b in line_1353)}")
    
    # Check surrounding lines
    for i in range(max(0, 1350), min(1356, len(lines))):
        line = lines[i]
        has_non_ascii = any(b > 127 for b in line)
        print(f"Line {i+1}: {line.decode('utf-8', errors='replace')[:80]} [non-ASCII: {has_non_ascii}]")
