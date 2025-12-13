import re

with open('audit_report.txt', 'r') as f:
    content = f.read()

# Find all White turns with incomplete moves
print("WHITE TURNS - CHECKING FOR MISSED MOVES")
print("="*70)

lines = content.split('\n')
i = 0
issues_found = []

while i < len(lines):
    line = lines[i]
    
    # Look for White turns
    if 'Turn' in line and 'white rolled' in line:
        turn_num_match = re.search(r'Turn (\d+)', line)
        dice_match = re.search(r'rolled (\d+),(\d+)', line)
        
        if turn_num_match and dice_match:
            turn_num = int(turn_num_match.group(1))
            d1, d2 = int(dice_match.group(1)), int(dice_match.group(2))
            
            # Collect turn data
            turn_data = [line]
            i += 1
            while i < len(lines) and not lines[i].startswith('='):
                turn_data.append(lines[i])
                i += 1
            
            turn_text = '\n'.join(turn_data)
            
            # Check for moves made
            moves_match = re.search(r'Moves made: \[(.*?)\]', turn_text)
            if moves_match:
                moves_str = moves_match.group(1)
                move_count = moves_str.count('(') if moves_str else 0
                
                # Expected moves
                if d1 == d2:
                    expected = 4
                else:
                    expected = 2
                
                # Check if fewer moves made
                if move_count < expected:
                    # Check if valid moves were available
                    if 'Valid moves available from' in turn_text:
                        print(f"\nTurn {turn_num}: White rolled {d1},{d2}")
                        print(f"  Expected {expected} moves, only made {move_count}")
                        
                        # Extract available moves
                        for line in turn_data:
                            if 'Point' in line and 'can move to' in line:
                                print(f"  {line.strip()}")
                        
                        print(f"  Moves made: {moves_str if moves_str else 'NONE'}")
                        issues_found.append(turn_num)
                        print("-"*70)
    else:
        i += 1

print(f"\n{'='*70}")
print(f"SUMMARY: Found {len(issues_found)} White turns with potential issues")
if issues_found:
    print(f"Turn numbers: {issues_found}")
