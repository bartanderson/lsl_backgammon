import re
import sys

def parse_board(board_str):
    # Board string is comma-separated points, each point can have multiple pieces (e.g. "w1,w2")
    # But the log format for FRESH_BOARD_STATE params is a bit complex.
    # Based on log:
    # DEBUG AI: Point 0: 'w1,w2'
    # ...
    # We can also parse the "DEBUG AI: Point X: ..." lines if available, which is easier.
    pass

def parse_log(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()

    board = [[] for _ in range(24)]
    bar_white = []
    bar_black = []
    
    current_turn = ""
    dice = []
    
    errors = []
    moves_count = 0
    combined_moves_count = 0
    
    # Regex for move execution
    # DEBUG AI: Executing move: PLAYER_MOVE|white|0|2|2|1|196546
    move_pattern = re.compile(r"PLAYER_MOVE\|(white|black)\|(-?\d+)\|(-?\d+)\|(\d+)\|(\d+)")
    
    # Regex for board state dump (from DEBUG AI: Point X: ...)
    point_pattern = re.compile(r"DEBUG AI: Point (\d+): '(.*)'")
    
    # Regex for dice
    dice_pattern = re.compile(r"DEBUG AI: Received TRIGGER_AI_TURN - turn: (\w+), dice: (\d+),(\d+)")

    for i, line in enumerate(lines):
        # Track Dice
        m_dice = dice_pattern.search(line)
        if m_dice:
            current_turn = m_dice.group(1)
            dice = [int(m_dice.group(2)), int(m_dice.group(3))]
            # print(f"Turn: {current_turn} Dice: {dice}")
            continue

        # Track Board State from DEBUG logs
        m_point = point_pattern.search(line)
        if m_point:
            point_idx = int(m_point.group(1))
            content = m_point.group(2)
            if content:
                board[point_idx] = content.split(',')
            else:
                board[point_idx] = []
            continue
            
        # Track Bar State (approximate, usually printed in DEBUG RENDER: BAR_STATE)
        # But for validation, we mainly care about the board points for jumping.
        
        # Validate Move
        m_move = move_pattern.search(line)
        if m_move:
            player = m_move.group(1)
            from_point = int(m_move.group(2))
            to_point = int(m_move.group(3))
            die_val = int(m_move.group(4))
            moves_used = int(m_move.group(5))
            
            moves_count += 1
            
            if moves_used == 2:
                combined_moves_count += 1
                # print(f"Found Combined Move at line {i}: {line.strip()}")
                errors.append(f"INFO: Checking combined move at line {i}: {line.strip()}")
                
                # Validate Combined Move
                # We need to check if there was a valid intermediate step.
                # Dice are in 'dice' variable.
                # If die_val is sum of dice, we check both paths.
                
                d1, d2 = dice[0], dice[1]
                if d1 + d2 != die_val:
                    # Might be doubles case where we use 2 dice? 
                    # But usually combined move is distinct dice.
                    pass
                
                # Check path 1: from -> from+d1 -> to
                # Check path 2: from -> from+d2 -> to
                
                direction = 1 if player == "white" else -1
                
                mid1 = from_point + (d1 * direction)
                mid2 = from_point + (d2 * direction)
                
                valid_path_1 = is_point_open(board, mid1, player)
                valid_path_2 = is_point_open(board, mid2, player)
                
                if not valid_path_1 and not valid_path_2:
                    errors.append(f"INVALID COMBINED MOVE at line {i}: {line.strip()} - Both intermediate points {mid1} and {mid2} are blocked!")
                else:
                    errors.append(f"VALID: Combined move at line {i}. Paths: {mid1}({valid_path_1}), {mid2}({valid_path_2})")

    with open("verification_report.txt", "w", encoding="utf-8") as out_f:
        out_f.write(f"Total Moves: {moves_count}\n")
        out_f.write(f"Combined Moves: {combined_moves_count}\n")
        if errors:
            out_f.write("ERRORS FOUND:\n")
            for e in errors:
                out_f.write(e + "\n")
        else:
            out_f.write("No invalid combined moves found.\n")

def is_point_open(board, point_idx, player):
    if point_idx < 0 or point_idx >= 24:
        return True # Bearing off or bar logic (simplified)
        
    pieces = board[point_idx]
    if not pieces:
        return True
    
    # Check if blocked by opponent
    first_piece = pieces[0]
    if player == "white" and first_piece.startswith("b") and len(pieces) >= 2:
        return False
    if player == "black" and first_piece.startswith("w") and len(pieces) >= 2:
        return False
        
    return True

if __name__ == "__main__":
    parse_log("log4.txt")
