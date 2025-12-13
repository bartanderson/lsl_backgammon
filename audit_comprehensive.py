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

def reset_board():
    global board, white_bar, black_bar, white_off, black_off
    board = [[] for _ in range(BOARD_SIZE)]
    white_bar = []
    black_bar = []
    white_off = []
    black_off = []
    
    # Standard Setup
    for i in range(2): board[0].append("w")
    for i in range(5): board[11].append("w")
    for i in range(3): board[16].append("w")
    for i in range(5): board[18].append("w")
    
    for i in range(2): board[23].append("b")
    for i in range(5): board[12].append("b")
    for i in range(3): board[7].append("b")
    for i in range(5): board[5].append("b")

def get_point_owner(point_idx):
    if point_idx < 0 or point_idx >= BOARD_SIZE: return None
    if not board[point_idx]: return None
    return board[point_idx][0]

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
        for i in range(0, 18):
            if get_point_owner(i) == "w": return False
        return True
    else:
        if len(black_bar) > 0: return False
        for i in range(6, 24):
            if get_point_owner(i) == "b": return False
        return True

def is_valid_bear_off(from_point, die, color_code):
    if not all_pieces_in_home(color_code): return False
    
    if color_code == WHITE:
        if not (18 <= from_point <= 23): return False
        dist = 24 - from_point
    else:
        if not (0 <= from_point <= 5): return False
        dist = from_point + 1
        
    if die == dist: return True
    
    if die > dist:
        if color_code == WHITE:
            for i in range(18, from_point):
                if get_point_owner(i) == "w": return False
        else:
            for i in range(from_point + 1, 6):
                if get_point_owner(i) == "b": return False
        return True
        
    return False

def get_all_valid_moves_for_turn(color_code, dice):
    """Get ALL valid moves for a given turn with specific dice"""
    all_moves = {}  # point -> list of valid destinations
    
    direction = 1 if color_code == WHITE else -1
    player_char = "w" if color_code == WHITE else "b"
    can_bear_off = all_pieces_in_home(color_code)
    
    # Check bar first
    bar_list = white_bar if color_code == WHITE else black_bar
    if bar_list:
        all_moves[-2] = []  # Bar
        for die in dice:
            if color_code == WHITE:
                target = die - 1
            else:
                target = 24 - die
            if 0 <= target < 24 and not is_blocked(target, color_code):
                all_moves[-2].append(target)
        return all_moves  # MUST move from bar first
    
    # Check all board points
    for point in range(BOARD_SIZE):
        if get_point_owner(point) != player_char:
            continue
            
        valid_dests = []
        
        for die in dice:
            target = point + (die * direction)
            
            # Bear off
            if not (0 <= target < 24):
                if can_bear_off and is_valid_bear_off(point, die, color_code):
                    valid_dests.append(-1)
                continue
                
            # Normal move
            if not is_blocked(target, color_code):
                valid_dests.append(target)
        
        if valid_dests:
            all_moves[point] = valid_dests
            
    return all_moves

def print_board_state():
    """Print current board state for debugging"""
    print("  Board State:")
    for i in range(24):
        if board[i]:
            print(f"    Point {i}: {board[i]}")
    print(f"    White Bar: {white_bar}, Black Bar: {black_bar}")
    print(f"    White Off: {len(white_off)}, Black Off: {len(black_off)}")

def audit_comprehensive(filepath):
    global board, white_bar, black_bar, white_off, black_off
    reset_board()
    
    current_turn = None
    current_dice = []
    turn_number = 0
    issues_found = []
    
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Track dice rolls (start of turn)
        m_roll = re.search(r'Backgammon: (white|black) rolled (\d+) and (\d+)', line)
        if m_roll:
            current_turn = m_roll.group(1)
            d1, d2 = int(m_roll.group(2)), int(m_roll.group(3))
            if d1 == d2:
                current_dice = [d1, d1, d1, d1]
            else:
                current_dice = [d1, d2]
            turn_number += 1
            
            color_code = WHITE if current_turn == "white" else BLACK
            
            # Calculate ALL valid moves for this turn
            all_valid = get_all_valid_moves_for_turn(color_code, current_dice)
            
            if not all_valid:
                print(f"\n{'='*60}")
                print(f"Turn {turn_number}: {current_turn} rolled {d1},{d2}")
                print(f"  NO VALID MOVES AVAILABLE (correctly blocked)")
            else:
                print(f"\n{'='*60}")
                print(f"Turn {turn_number}: {current_turn} rolled {d1},{d2}")
                print(f"  Valid moves available from {len(all_valid)} points:")
                for point, dests in sorted(all_valid.items()):
                    point_str = "Bar" if point == -2 else str(point)
                    dest_str = ", ".join(["Off" if d == -1 else str(d) for d in dests])
                    print(f"    Point {point_str}: can move to [{dest_str}]")
                
                # Now track what moves were actually made
                moves_made = []
                j = i + 1
                while j < len(lines):
                    next_line = lines[j].strip()
                    
                    # Stop at next roll or turn change
                    if re.search(r'Backgammon: (white|black) rolled', next_line):
                        break
                    if "Turn changed to:" in next_line:
                        break
                        
                    # Track actual moves
                    m_move = re.search(r'CORE: processMove - \w+ from:(-?\d+) to:(-?\d+)', next_line)
                    if m_move:
                        from_p = int(m_move.group(1))
                        to_p = int(m_move.group(2))
                        moves_made.append((from_p, to_p))
                    
                    j += 1
                
                if moves_made:
                    print(f"  Moves made: {moves_made}")
                else:
                    print(f"  WARNING: No moves made despite valid moves available!")
                    issues_found.append({
                        'turn': turn_number,
                        'player': current_turn,
                        'dice': current_dice,
                        'valid_moves': all_valid,
                        'moves_made': []
                    })
        
        # Update board state
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
        
        m_bear = re.search(r'Bear off piece ([wb])\d+ from (\d+)', line)
        if m_bear:
            color_char = m_bear.group(1)
            p = int(m_bear.group(2))
            if board[p]: board[p].pop()
            if color_char == 'w': white_off.append('w')
            else: black_off.append('b')
        
        i += 1
    
    # Summary
    print(f"\n{'='*60}")
    print(f"AUDIT COMPLETE")
    print(f"Total turns analyzed: {turn_number}")
    print(f"Issues found: {len(issues_found)}")
    
    if issues_found:
        print(f"\nDETAILED ISSUES:")
        for issue in issues_found:
            print(f"\n  Turn {issue['turn']} ({issue['player']}):")
            print(f"    Dice: {issue['dice']}")
            print(f"    Valid moves were available but not made!")
            for point, dests in issue['valid_moves'].items():
                print(f"      Point {point}: {dests}")

audit_comprehensive("c:/Users/bartl/dev/lsl_backgammon/logs/ai v human.txt")
