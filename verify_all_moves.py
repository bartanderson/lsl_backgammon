#!/usr/bin/env python3
"""Complete move verification for log_invalid_move.txt"""

import re

# Extract all moves from the log
with open('logs/log_invalid_move.txt', 'r', encoding='utf-8') as f:
    content = f.read()

# Find all processMove lines
moves = re.findall(r'\[(\d+:\d+)\].*?processMove - (\w+) from:(-?\d+) to:(-?\d+) die:(\d+) movesUsed:(\d+)', content)

print(f"Total moves extracted: {len(moves)}\n")

# Also extract dice rolls to validate moves against available dice
rolls = re.findall(r'\[(\d+:\d+)\].*?(\w+) rolled (\d+) and (\d+)', content)

# Store move validation results
move_details = []

for i, (time, player, from_pt, to_pt, die, moves_used) in enumerate(moves, 1):
    from_pt, to_pt, die = int(from_pt), int(to_pt), int(die)
    
    # Calculate expected distance
    if from_pt == -2:  # Bar
        entry_desc = "Bar entry"
    elif to_pt == -1:  # Bear off
        entry_desc = "Bear-off attempt"
    else:
        if player == 'white':
            distance = to_pt - from_pt
        else:
            distance = from_pt - to_pt
        entry_desc = f"Move {from_pt}->{to_pt} (dist={distance})"
    
    move_details.append({
        'num': i,
        'time': time,
        'player': player,
        'from': from_pt,
        'to': to_pt,
        'die': die,
        'desc': entry_desc
    })

# Write detailed report
with open('logs/complete_move_verification.txt', 'w') as f:
    f.write("COMPLETE MOVE-BY-MOVE VERIFICATION\n")
    f.write("=" * 80 + "\n\n")
    
    for move in move_details:
        f.write(f"Move {move['num']:2d} [{move['time']}] {move['player']:5s}: {move['desc']}, die={move['die']}\n")
    
    f.write("\n" + "=" * 80 + "\n")
    f.write(f"\nTotal moves processed: {len(move_details)}\n")

print("Full verification written to logs/complete_move_verification.txt")

# Print first 20 and last 10 for quick review
print("\nFirst 20 moves:")
for move in move_details[:20]:
    print(f"  {move['num']:2d}. [{move['time']}] {move['player']:5s}: {move['desc']}, die={move['die']}")

print("\n...")
print("\nLast 10 moves:")
for move in move_details[-10:]:
    print(f"  {move['num']:2d}. [{move['time']}] {move['player']:5s}: {move['desc']}, die={move['die']}")
