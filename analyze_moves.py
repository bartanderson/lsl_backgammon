#!/usr/bin/env python3
"""Analyze all moves in log_invalid_move.txt for rule violations."""

import re
from collections import defaultdict

# Board state tracker
class BackgammonAnalyzer:
    def __init__(self):
        self.board = [[] for _ in range(24)]
        self.white_bar = []
        self.black_bar = []
        self.white_off = []
        self.black_off = []
        self.current_turn = None
        self.dice = []
        self.moves_analyzed = 0
        self.errors = []
        
    def init_board(self):
        """Initialize standard backgammon starting position."""
        # White pieces (points 0-23 in our internal representation)
        self.board[0] = ['w1', 'w2']
        self.board[11] = ['w3', 'w4', 'w5', 'w6', 'w7']
        self.board[16] = ['w8', 'w9', 'w10']
        self.board[18] = ['w11', 'w12', 'w13', 'w14', 'w15']
        
        # Black pieces
        self.board[23] = ['b1', 'b2']
        self.board[12] = ['b3', 'b4', 'b5', 'b6', 'b7']
        self.board[7] = ['b8', 'b9', 'b10']
        self.board[5] = ['b11', 'b12', 'b13', 'b14', 'b15']
        
    def analyze_move(self, player, from_pt, to_pt, die_value, line_num, commit=True):
        """Analyze if a move is legal and update board state."""
        color = 'w' if player == 'white' else 'b'
        opponent_color = 'b' if player == 'white' else 'w'
        move_desc = f"Line {line_num}: {player} from:{from_pt} to:{to_pt} die:{die_value}"
        
        # Check if piece exists at from point
        if from_pt == -2:  # Bar
            bar = self.white_bar if player == 'white' else self.black_bar
            if not bar:
                self.errors.append(f"{move_desc} - ERROR: No pieces on bar")
                return False
        elif from_pt >= 0 and from_pt < 24:
            if not any(p.startswith(color) for p in self.board[from_pt]):
                self.errors.append(f"{move_desc} - ERROR: No {player} piece at point {from_pt}")
                return False
        
        # Check distance matches die value
        if from_pt >= 0 and to_pt >= 0:
            expected_dist = abs(to_pt - from_pt)
            if player == 'white':
                expected_dist = to_pt - from_pt
            else:
                expected_dist = from_pt - to_pt
                
            if expected_dist != die_value:
                self.errors.append(f"{move_desc} - ERROR: Distance {expected_dist} != die {die_value}")
                return False
        
        # --- UPDATE STATE ---
        if not commit:
            # If not committing, we just wanted to validate.
            # But we also need to validate bear-off logic below before returning!
            pass

        # 1. Remove from source (Only if commit)
        piece = None
        if commit:
            if from_pt == -2:
                bar = self.white_bar if player == 'white' else self.black_bar
                piece = bar.pop()
            else:
                piece = self.board[from_pt].pop()

        # 2. Handle Destination
        if to_pt == -1: # Bear off
            is_valid, msg = self.validate_bear_off(player, from_pt, die_value)
            if not is_valid:
                self.errors.append(f"{move_desc} - ERROR: Illegal Bear-off: {msg}")
                # If we committed the pop above, we should undo it? 
                # Ideally validation happens BEFORE commit.
                # Let's move commit logic AFTER validation.
                return False
            
            if commit:
                if player == 'white':
                    self.white_off.append(piece)
                else:
                    self.black_off.append(piece)
        else:
            # Check for hit
            dest_point = self.board[to_pt]
            if len(dest_point) == 1 and dest_point[0].startswith(opponent_color):
                # HIT!
                if commit:
                    hit_piece = dest_point.pop()
                    if opponent_color == 'w':
                        self.white_bar.append(hit_piece)
                    else:
                        self.black_bar.append(hit_piece)
            
            if commit:
                self.board[to_pt].append(piece)
        
        return True

    # ... (validate_bear_off stays same) ...

    def process_log(self, filename):
        # ... (init stays same) ...
        
        # ... (loop stays same) ...
                
                # CHECK AHEAD FOR REJECTION
                is_rejected = False
                if i + 2 < len(lines):
                    if "REJECTED" in lines[i+1] or "REJECTED" in lines[i+2]:
                        is_rejected = True
                
                self.moves_analyzed += 1
                
                if is_rejected:
                    # Validate but don't commit
                    is_valid = self.analyze_move(player, from_pt, to_pt, die, i + 1, commit=False)
                    if is_valid:
                        self.errors.append(f"Line {i+1}: {player} move REJECTED by game but seems VALID by analyzer.")
                    else:
                        # It was rejected and it WAS invalid. Good.
                        # We might want to log this as "Correctly Rejected"
                        pass
                else:
                    self.analyze_move(player, from_pt, to_pt, die, i + 1, commit=True)
    
    def validate_bear_off(self, player, from_pt, die_value):
        """Check if bear-off is legal."""
        # Check if all pieces are in home board
        # White Home: 18-23. Pieces outside: 0-17
        # Black Home: 0-5. Pieces outside: 6-23
        
        if player == 'white':
            outside_pieces = []
            for i in range(18):
                outside_pieces.extend(self.board[i])
            if self.white_bar:
                outside_pieces.extend(self.white_bar)
                
            if outside_pieces:
                return False, f"Pieces still outside home board: {outside_pieces}"
                
            # Check distance
            # Distance to off (24) from pt. e.g. from 23 needs 1, from 18 needs 6.
            # wait, internal 0-23. Off is 24.
            # from 23 (6-point) needs 1? No, 23 is 6-point. 24 is off.
            # distance = 24 - from_pt.
            # from 18 (1-point? No 18 is 19th point. 18..23 is 6 points).
            # Let's verify mapping.
            # White moves 0 -> 23.
            # 0 is White's 24-point (furthest).
            # 23 is White's 1-point (closest to off).
            # Wait, usually 0 is 1-point or 24-point?
            # Log: "white from:0 to:6". 0 is start. 6 is closer to end?
            # Log: "white from:18 to:-1". -1 is Bear Off.
            # So White moves 0 -> 23?
            # If White moves 0->23, then 23 is home. Bear off is > 23?
            # But log says "from:18 to:-1".
            # Maybe White moves 23 -> 0?
            # Log line 26: "white from:0 to:6".
            # Log line 337: "white from:18 to:23".
            # Log line 2659: "white from:18 to:-1".
            # This is contradictory. 18->23 is +5. 18->-1 is ... bear off?
            # If 18->23 is valid, then 23 is a high point.
            # If 18->-1 is bear off, maybe -1 is just a flag.
            # Let's assume standard mapping:
            # White moves 0 -> 23. Home is 18-23.
            # Bear off from 18-23.
            # Distance from 18 to Off (24) is 6.
            # Distance from 23 to Off (24) is 1.
            
            dist = 24 - from_pt
            if die_value == dist:
                return True, ""
            elif die_value > dist:
                # Allowed ONLY if no pieces on higher points (further away)
                # Higher points for White are < from_pt (e.g. 18 is higher/further than 23)
                # Wait, mapping: 0=Start, 23=End.
                # 18 is 6 away. 23 is 1 away.
                # Higher points (further from 24) are < from_pt.
                # e.g. if at 23 (dist 1), die 6. Allowed if no pieces at 18..22.
                
                higher_pieces = []
                for i in range(18, from_pt):
                    higher_pieces.extend(self.board[i])
                
                if higher_pieces:
                    return False, f"Die {die_value} > Dist {dist} but pieces exist at higher points: {higher_pieces}"
                return True, ""
            else:
                # die_value < dist
                # Cannot bear off. Must move inside.
                return False, f"Die {die_value} < Dist {dist} (Move inside board instead)"

        else: # Black
            # Black moves 23 -> 0?
            # Log line 88: "black from:23 to:22". Yes, decreasing.
            # Home is 0-5.
            outside_pieces = []
            for i in range(6, 24):
                outside_pieces.extend(self.board[i])
            if self.black_bar:
                outside_pieces.extend(self.black_bar)
                
            if outside_pieces:
                return False, f"Pieces still outside home board: {outside_pieces}"
            
            # Distance to off (-1).
            # from 0 (1-point) needs 1.
            # from 5 (6-point) needs 6.
            # distance = from_pt + 1.
            return True, ""

    def process_log(self, filename):
        """Process the entire log file."""
        with open(filename, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        self.init_board()
        
        skip_next = False
        
        for i, line in enumerate(lines):
            if skip_next:
                skip_next = False
                continue

            # Extract dice rolls
            dice_match = re.search(r'(\w+) rolled (\d+) and (\d+)', line)
            if dice_match:
                player, d1, d2 = dice_match.groups()
                self.current_turn = player
                self.dice = [int(d1), int(d2)]
                continue
            
            # Extract moves
            move_match = re.search(r'processMove - (\w+) from:(-?\d+) to:(-?\d+) die:(\d+)', line)
            if move_match:
                player, from_pt, to_pt, die = move_match.groups()
                from_pt, to_pt, die = int(from_pt), int(to_pt), int(die)
                
                # CHECK AHEAD FOR REJECTION
                is_rejected = False
                if i + 2 < len(lines):
                    if "REJECTED" in lines[i+1] or "REJECTED" in lines[i+2]:
                        is_rejected = True
                
                self.moves_analyzed += 1
                
                if is_rejected:
                    # Just validate logic, don't update state
                    # Actually, if it's rejected, we want to know WHY.
                    # So we run analyze_move but maybe with a flag?
                    # For now, let's just NOT analyze it to avoid state corruption,
                    # OR analyze it but don't save state.
                    # Let's make analyze_move return success/fail and take a 'commit' arg.
                    pass
                else:
                    self.analyze_move(player, from_pt, to_pt, die, i + 1)
        
        return self.errors

if __name__ == '__main__':
    analyzer = BackgammonAnalyzer()
    errors = analyzer.process_log('logs/log_invalid_move.txt')
    
    print(f"Total moves analyzed: {analyzer.moves_analyzed}")
    print(f"Errors found: {len(errors)}\n")
    
    if errors:
        for error in errors[:20]:  # Show first 20 errors
            print(error)
        if len(errors) > 20:
            print(f"\n... and {len(errors) - 20} more errors")
    else:
        print("No rule violations detected!")
