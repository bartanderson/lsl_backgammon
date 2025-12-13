import re
import sys

# Constants
BOARD_SIZE = 24
WHITE = 0
BLACK = 1
WHITE_HOME_START = 18
WHITE_HOME_END = 23
BLACK_HOME_START = 5
BLACK_HOME_END = 0

# State
board = [[] for _ in range(BOARD_SIZE)]
white_bar = []
black_bar = []
white_off = []
black_off = []
current_dice = []
current_turn = None

def reset_board():
    global board, white_bar, black_bar, white_off, black_off
    board = [[] for _ in range(BOARD_SIZE)]
    white_bar = []
    black_bar = []
    white_off = []
    black_off = []
    
    # Standard Setup
    # White (0) moves +ve (0->23)
    # Black (1) moves -ve (23->0)
    
    # White: 2@0, 5@11, 3@16, 5@18
    for i in range(2): board[0].append("w")
    for i in range(5): board[11].append("w")
    for i in range(3): board[16].append("w")
    for i in range(5): board[18].append("w")
    
    # Black: 2@23, 5@12, 3@7, 5@5
    for i in range(2): board[23].append("b")
    for i in range(5): board[12].append("b")
    for i in range(3): board[7].append("b")
    for i in range(5): board[5].append("b")

def get_point_owner(point_idx):
    if point_idx < 0 or point_idx >= BOARD_SIZE: return None
    if not board[point_idx]: return None
    return board[point_idx][0] # "w" or "b"

def is_blocked(point_idx, color_code):
    owner = get_point_owner(point_idx)
    if owner is None: return False
    
    opp_char = "b" if color_code == WHITE else "w"
    if owner == opp_char and len(board[point_idx]) >= 2:
        return True
    return False

def all_pieces_in_home(color_code):
    if color_code == WHITE:
        if len(white_bar) > 0: return False
        # Check points 0-17
        for i in range(0, 18):
            if get_point_owner(i) == "w": return False
        return True
    else:
        if len(black_bar) > 0: return False
        # Check points 6-23
        for i in range(6, 24):
            if get_point_owner(i) == "b": return False
        return True

def is_valid_bear_off(from_point, die, color_code):
    if not all_pieces_in_home(color_code): return False
    
    # Must be in home board
    if color_code == WHITE:
        if not (18 <= from_point <= 23): return False
        dist = 24 - from_point
    else:
        if not (0 <= from_point <= 5): return False
        dist = from_point + 1
        
    if die == dist: return True
    
    if die > dist:
        # Overshoot: allowed ONLY if no pieces further away
        if color_code == WHITE:
            # Check 18 to from_point-1
            for i in range(18, from_point):
                if get_point_owner(i) == "w": return False
        else:
            # Check from_point+1 to 5
            for i in range(from_point + 1, 6):
                if get_point_owner(i) == "b": return False
        return True
        
    return False

def get_valid_moves(from_point, dice, color_code):
    moves = []
    direction = 1 if color_code == WHITE else -1
    
    # Handle Bar
    if from_point == -2: # Bar
        bar_list = white_bar if color_code == WHITE else black_bar
        if not bar_list: return []
        
        for die in dice:
            if color_code == WHITE:
                target = die - 1
            else:
                target = 24 - die
                
            if 0 <= target < 24 and not is_blocked(target, color_code):
                moves.append(f"Bar->{target} (Die {die})")
        return moves

    # Handle Board
    # Check if piece exists
    if not (0 <= from_point < 24): return []
    owner = get_point_owner(from_point)
    expected = "w" if color_code == WHITE else "b"
    if owner != expected: return []
    
    can_bear_off = all_pieces_in_home(color_code)
    
    for die in dice:
        target = from_point + (die * direction)
        
        # Bear Off
        if not (0 <= target < 24):
            if can_bear_off and is_valid_bear_off(from_point, die, color_code):
                moves.append(f"{from_point}->Off (Die {die})")
            continue
            
        # Normal Move
        if not is_blocked(target, color_code):
            moves.append(f"{from_point}->{target} (Die {die})")
            
    return moves

def parse_log(filepath):
    global current_dice, current_turn
    
    reset_board()
    
    with open(filepath, 'r') as f:
        lines = f.readlines()
        
    for line in lines:
        line = line.strip()
        
        # Dice Roll
        m_roll = re.search(r'Backgammon: (white|black) rolled (\d+) and (\d+)', line)
        if m_roll:
            current_turn = m_roll.group(1)
            d1, d2 = int(m_roll.group(2)), int(m_roll.group(3))
            if d1 == d2: current_dice = [d1, d1, d1, d1]
            else: current_dice = [d1, d2]
            # print(f"DEBUG: {current_turn} rolled {current_dice}")
            continue

        # Dice Update (Remaining)
        m_rem = re.search(r'DEBUG UI: Dice remaining - (\d+), (\d+)', line)
        if m_rem:
            d1, d2 = int(m_rem.group(1)), int(m_rem.group(2))
            current_dice = []
            if d1 > 0: current_dice.append(d1)
            if d2 > 0: current_dice.append(d2)
            # print(f"DEBUG: Dice updated to {current_dice}")
            continue
            
        # Move Piece (Sync State)
        # [16:29] Bar: DEBUG RENDER: MOVE_PIECE - b11 from 5 to 3
        m_move = re.search(r'MOVE_PIECE - ([wb])\d+ from (-?\d+) to (-?\d+)', line)
        if m_move:
            color_char = m_move.group(1)
            f_p = int(m_move.group(2))
            t_p = int(m_move.group(3))
            
            # Remove from source
            if f_p == -2:
                if color_char == 'w': 
                    if white_bar: white_bar.pop()
                else: 
                    if black_bar: black_bar.pop()
            else:
                if board[f_p]: board[f_p].pop()
                
            # Add to dest
            if t_p == -1: # Off
                if color_char == 'w': white_off.append(color_char)
                else: black_off.append(color_char)
            else:
                board[t_p].append(color_char)
            continue
            
        # Hit Piece
        # [16:32] Bar: DEBUG RENDER: HIT_PIECE received - w1 from point 1
        m_hit = re.search(r'HIT_PIECE received - ([wb])\d+ from point (\d+)', line)
        if m_hit:
            color_char = m_hit.group(1)
            p = int(m_hit.group(2))
            # Logic usually handles the move to bar implicitly via updateLocalBoard or similar in log?
            # Actually, looking at log:
            # [16:32] Bar: DEBUG RENDER: HIT_PIECE received - b8 from point 1
            # [16:32] Bar: DEBUG RENDER: Added b8 to BlackBarList
            # [16:32] Bar: DEBUG RENDER: MOVE_PIECE - w1 from -2 to 1
            # The HIT_PIECE log comes *before* the move that caused it?
            # Or is it just a notification?
            # "Added b8 to BlackBarList" implies it moved to bar.
            # Let's trust "Added X to BarList" if available, or just manually move it.
            if color_char == 'w': white_bar.append('w')
            else: black_bar.append('b')
            
            # Remove from board if not already handled?
            # The HIT usually happens because a piece landed there.
            # The piece that was hit is removed from the point.
            if board[p] and board[p][0] == color_char:
                board[p].pop()
            continue
            
        # Bear Off (Explicit)
        # [16:50] Bar: DEBUG RENDER: Bear off piece w1 from 21
        m_bear = re.search(r'Bear off piece ([wb])\d+ from (\d+)', line)
        if m_bear:
            color_char = m_bear.group(1)
            p = int(m_bear.group(2))
            if board[p]: board[p].pop()
            if color_char == 'w': white_off.append('w')
            else: black_off.append('b')
            continue

        # Check "No valid moves"
        if "No valid moves for this piece" in line:
            # Find context
            # Look back for "Piece selected at position X"
            # Since we process line by line, we need to store the last selection
            pass

        m_sel = re.search(r'DEBUG UI: PIECE_POSITION - [wb]\d+ at position (-?\d+).*currentTurn: (white|black)', line)
        if m_sel:
            sel_pos = int(m_sel.group(1))
            sel_turn = m_sel.group(2)
            
            # Peek ahead for "No valid moves"
            # Actually, let's just store this state and if next relevant line is "No valid moves", we check.
            pass

        if "No valid moves for this piece" in line:
            # We need the last selected position and dice
            # Since we are parsing linearly, we assume the last parsed selection is relevant.
            # But wait, we need to be sure.
            # Let's just print the state when we see this message.
            print(f"\nAUDIT: 'No valid moves' detected at line: {line}")
            print(f"  Turn: {current_turn}")
            print(f"  Dice: {current_dice}")
            # We need to know WHICH piece was selected.
            # We'll rely on the script outputting the board state so we can manually verify or automate it.
            # Better: Store last selection.
            
    # To make this useful, we need to correlate selection with the error.
    # Let's re-read the file but keep track of last selection.

parse_log("c:/Users/bartl/dev/lsl_backgammon/logs/ai v human.txt")

# Refined loop for checking
def audit_log(filepath):
    global current_dice, current_turn
    reset_board()
    
    last_selected_pos = None
    last_selected_color = None
    
    with open(filepath, 'r') as f:
        lines = f.readlines()
        
    for i, line in enumerate(lines):
        line = line.strip()
        
        # Update State (Dice, Moves)
        # ... (Same logic as above to keep board sync) ...
        m_roll = re.search(r'Backgammon: (white|black) rolled (\d+) and (\d+)', line)
        if m_roll:
            current_turn = m_roll.group(1)
            d1, d2 = int(m_roll.group(2)), int(m_roll.group(3))
            if d1 == d2: current_dice = [d1, d1, d1, d1]
            else: current_dice = [d1, d2]
            continue

        m_rem = re.search(r'DEBUG UI: Dice remaining - (\d+), (\d+)', line)
        if m_rem:
            d1, d2 = int(m_rem.group(1)), int(m_rem.group(2))
            current_dice = []
            if d1 > 0: current_dice.append(d1)
            if d2 > 0: current_dice.append(d2)
            continue
            
        m_move = re.search(r'MOVE_PIECE - ([wb])\d+ from (-?\d+) to (-?\d+)', line)
        if m_move:
            color_char = m_move.group(1)
            f_p = int(m_move.group(2))
            t_p = int(m_move.group(3))
            if f_p == -2:
                if color_char == 'w': 
                    if white_bar: white_bar.pop()
                else: 
                    if black_bar: black_bar.pop()
            else:
                if board[f_p]: board[f_p].pop()
            if t_p == -1:
                if color_char == 'w': white_off.append(color_char)
                else: black_off.append(color_char)
            else:
                board[t_p].append(color_char)
            continue
            
        m_hit = re.search(r'HIT_PIECE received - ([wb])\d+ from point (\d+)', line)
        if m_hit:
            color_char = m_hit.group(1)
            p = int(m_hit.group(2))
            if color_char == 'w': white_bar.append('w')
            else: black_bar.append('b')
            if board[p] and board[p][0] == color_char:
                board[p].pop()
            continue
            
        m_bear = re.search(r'Bear off piece ([wb])\d+ from (\d+)', line)
        if m_bear:
            color_char = m_bear.group(1)
            p = int(m_bear.group(2))
            if board[p]: board[p].pop()
            if color_char == 'w': white_off.append('w')
            else: black_off.append('b')
            continue

        # Track Selection
        m_sel = re.search(r'DEBUG UI: PIECE_POSITION - ([wb])\d+ at position (-?\d+).*currentTurn: (white|black)', line)
        if m_sel:
            last_selected_color = WHITE if m_sel.group(1) == 'w' else BLACK
            last_selected_pos = int(m_sel.group(2))
            
        # Audit Error
        if "No valid moves for this piece" in line:
            print(f"--------------------------------------------------")
            print(f"AUDIT ALERT at Line {i+1}: {line}")
            print(f"Context: Turn={current_turn}, Dice={current_dice}")
            print(f"Selected Piece: Pos={last_selected_pos}, Color={last_selected_color}")
            
            # Calculate Valid Moves
            valid_moves = get_valid_moves(last_selected_pos, current_dice, last_selected_color)
            
            if valid_moves:
                print(f"FAILURE: The game said 'No moves', but I found: {valid_moves}")
                print(f"Board State around {last_selected_pos}:")
                # Print relevant board section
                start = max(0, last_selected_pos - 6)
                end = min(24, last_selected_pos + 7)
                for p in range(start, end):
                    print(f"  Point {p}: {board[p]}")
                print(f"  White Bar: {white_bar}, Black Bar: {black_bar}")
                print(f"  White Off: {len(white_off)}, Black Off: {len(black_off)}")
            else:
                print(f"SUCCESS: Correctly rejected. No valid moves found.")
                
audit_log("c:/Users/bartl/dev/lsl_backgammon/logs/ai v human.txt")
