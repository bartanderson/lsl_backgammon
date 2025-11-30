import re

def parse_log(file_path):
    # Initialize Board
    white_pieces = {} # ID -> Location (0-23, -1=BearOff, -2=Bar)
    black_pieces = {}
    
    def init_board():
        white_pieces.clear()
        black_pieces.clear()
        # Init White
        for i in range(1, 3): white_pieces[f"w{i}"] = 0
        for i in range(3, 8): white_pieces[f"w{i}"] = 11
        for i in range(8, 11): white_pieces[f"w{i}"] = 16
        for i in range(11, 16): white_pieces[f"w{i}"] = 18
        
        # Init Black
        for i in range(1, 3): black_pieces[f"b{i}"] = 23
        for i in range(3, 8): black_pieces[f"b{i}"] = 12
        for i in range(8, 11): black_pieces[f"b{i}"] = 7
        for i in range(11, 16): black_pieces[f"b{i}"] = 5

    init_board()
    white_borne_off = 0
    black_borne_off = 0
    
    errors = []
    
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    with open("analysis_results.txt", "w", encoding="utf-8") as out:
        out.write(f"Analyzing {len(lines)} lines...\n")

        for line_num, line in enumerate(lines):
            if "Game reset" in line:
                out.write(f"--- RESET DETECTED at Line {line_num} ---\n")
                init_board()
                white_borne_off = 0
                black_borne_off = 0
                continue

            # 1. Track Moves
            move_match = re.search(r"DEBUG RENDER: MOVE_PIECE - (w\d+|b\d+) from (-?\d+) to (-?\d+)", line)
            if move_match:
                piece = move_match.group(1)
                src = int(move_match.group(2))
                dst = int(move_match.group(3))
                
                is_white = piece.startswith('w')
                pieces = white_pieces if is_white else black_pieces
                
                if piece not in pieces:
                    # errors.append(f"Line {line_num}: Unknown piece {piece} moved.")
                    continue
                    
                current_pos = pieces[piece]
                
                # Verify source
                if current_pos != src:
                    out.write(f"WARNING: Line {line_num}: Piece {piece} moved from {src} but tracked at {current_pos}\n")
                    # errors.append(f"Line {line_num}: Piece {piece} moved from {src} but tracked at {current_pos}")

                # Update position
                pieces[piece] = dst
                
                # Check for Bear Off
                if dst == -1:
                    if is_white: white_borne_off += 1
                    else: black_borne_off += 1

            # 2. Track Bear Offs explicitly if different log
            bear_match = re.search(r"DEBUG RENDER: Bear off piece (w\d+|b\d+) from (\d+)", line)
            if bear_match:
                piece = bear_match.group(1)
                src = int(bear_match.group(2))
                
                is_white = piece.startswith('w')
                pieces = white_pieces if is_white else black_pieces
                
                if piece not in pieces:
                    # errors.append(f"Line {line_num}: Unknown piece {piece} borne off.")
                    continue
                
                pieces[piece] = -1 # Bear Off
                if is_white: white_borne_off += 1
                else: black_borne_off += 1
                
            # 3. Track Hits
            hit_match = re.search(r"DEBUG RENDER: HIT_PIECE received - (w\d+|b\d+) from point (\d+)", line)
            if hit_match:
                piece = hit_match.group(1)
                src = int(hit_match.group(2))
                
                is_white = piece.startswith('w')
                pieces = white_pieces if is_white else black_pieces
                
                pieces[piece] = -2 # Bar

            # 4. Check Game Over
            if "Game over!" in line:
                out.write(f"\n--- GAME OVER DETECTED at Line {line_num} ---\n")
                out.write(f"White Borne Off: {white_borne_off}\n")
                out.write(f"Black Borne Off: {black_borne_off}\n")
                
                w_on_board = [p for p, pos in white_pieces.items() if pos >= 0]
                b_on_board = [p for p, pos in black_pieces.items() if pos >= 0]
                
                out.write(f"White Pieces on Board: {len(w_on_board)} ({', '.join(w_on_board)})\n")
                out.write(f"Black Pieces on Board: {len(b_on_board)} ({', '.join(b_on_board)})\n")
                
                if len(w_on_board) > 0 and "white wins" in line:
                     errors.append("GAME OVER INVALID: White won but has pieces on board.")
                if len(b_on_board) > 0 and "black wins" in line:
                     errors.append("GAME OVER INVALID: Black won but has pieces on board.")

        out.write("\n--- FINAL ANALYSIS ---\n")
        if errors:
            for e in errors: out.write(e + "\n")
        else:
            out.write("No logical errors found in move sequence.\n")

        out.write("\nFinal State:\n")
        out.write(f"White Borne Off: {white_borne_off}/15\n")
        out.write(f"Black Borne Off: {black_borne_off}/15\n")
        
        # List pieces not borne off
        w_left = [p for p, pos in white_pieces.items() if pos != -1]
        b_left = [p for p, pos in black_pieces.items() if pos != -1]
        
        if w_left: out.write(f"White Left: {w_left}\n")
        if b_left: out.write(f"Black Left: {b_left}\n")

if __name__ == "__main__":
    parse_log("c:\\Users\\bartl\\dev\\lsl_backgammon\\log.txt")
