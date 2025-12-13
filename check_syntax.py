with open('backgammon_AI_brain.lsl', 'r', encoding='utf-8') as f:
    content = f.read()
    
open_braces = content.count('{')
close_braces = content.count('}')

print(f"Opening braces: {open_braces}")
print(f"Closing braces: {close_braces}")
print(f"Difference: {open_braces - close_braces}")

# Check around line 1353
lines = content.split('\n')
print(f"\nTotal lines: {len(lines)}")
print(f"\nLines 1350-1360:")
for i in range(1349, min(1360, len(lines))):
    print(f"{i+1}: {lines[i]}")
