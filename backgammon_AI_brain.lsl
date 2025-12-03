// BACKGAMMON AI BRAIN - Pure Logic
integer DEBUG_MODE = TRUE;
integer AI_LEVEL = 1;
integer gWhiteAILevel = 1;
integer gBlackAILevel = 1;

// Game state storage
list BoardList = [];
list WhiteBarList = [];
list BlackBarList = [];
list WhiteBorneOff = [];
list BlackBorneOff = [];
string currentTurn = "";
integer currentDie1 = 0;
integer currentDie2 = 0;
integer isDoubles = FALSE;
integer movesLeft = 0;

// AI level constants
integer LEVEL_RANDOM = 1;
integer LEVEL_TACTICAL = 2; 
integer LEVEL_STRATEGIC = 3;

// Board geometry constants
integer WHITE_HOME_START = 18;
integer WHITE_HOME_END = 23;
integer BLACK_HOME_START = 5;
integer BLACK_HOME_END = 0;
integer BOARD_SIZE = 24;
integer FROM_BAR = -2;
integer BEAR_OFF = -1;

// AI SCORING WEIGHTS
integer W_BLOT = -60;          // Penalty for leaving a blot (vulnerable single piece)
integer W_MADE_POINT = 40;     // Reward for making a point (secure stack)
integer W_PRIME_FACTOR = 30;   // Reward per point in a consecutive prime
integer W_ANCHOR = 50;         // Reward for holding an anchor in opponent's home
integer W_BAR_SELF = -80;      // Penalty for having a piece on the bar
integer W_BAR_OPP = 60;        // Reward for sending opponent to the bar (hitting)
integer W_PIP_WEIGHT = 1;      // Multiplier for pip count difference

string generateHomeBoardMove() {
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: generateHomeBoardMove for " + currentTurn);
    
    list range = getHomeBoardRange(currentTurn);
    integer homeStart = llList2Integer(range, 0);
    integer homeEnd = llList2Integer(range, 1);
    string playerColor = getPlayerColor(currentTurn);
    
    // When in bear off phase but can't bear off, move pieces toward bear off
    list diceToTry = [];
    if (isDoubles && currentDie1 > 0) {
        diceToTry = [currentDie1, currentDie1, currentDie1, currentDie1];
    } else {
        if (currentDie1 > 0) diceToTry += currentDie1;
        if (currentDie2 > 0) diceToTry += currentDie2;
    }
    
    // Try to move pieces closer to bearing off
    integer i;
    for (i = 0; i < llGetListLength(diceToTry); i++) {
        integer dieToUse = llList2Integer(diceToTry, i);
        if (dieToUse > 0) {
            if (currentTurn == "white") {
                // White: move from lower to higher points (toward 23)
                integer point;
                for (point = homeStart; point <= homeEnd; point++) {
                    string pointContents = llList2String(BoardList, point);
                    if (pointContents != "" && llSubStringIndex(pointContents, playerColor) != -1) {
                        integer toPoint = point + dieToUse;
                        if (toPoint <= homeEnd && toPoint < BOARD_SIZE) {
                            if (isValidMove(point, toPoint, dieToUse)) {
                                return "PLAYER_MOVE|" + currentTurn + "|" + (string)point + "|" + 
                                       (string)toPoint + "|" + (string)dieToUse + "|1";
                            }
                        }
                    }
                }
            } else {
                // Black: move from higher to lower points (toward 0)
                integer point;
                for (point = homeStart; point >= homeEnd; point--) {
                    string pointContents = llList2String(BoardList, point);
                    if (pointContents != "" && llSubStringIndex(pointContents, playerColor) != -1) {
                        integer toPoint = point - dieToUse;
                        if (toPoint >= homeEnd && toPoint >= 0) {
                            if (isValidMove(point, toPoint, dieToUse)) {
                                return "PLAYER_MOVE|" + currentTurn + "|" + (string)point + "|" + 
                                       (string)toPoint + "|" + (string)dieToUse + "|1";
                            }
                        }
                    }
                }
            }
        }
    }
    
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: No valid home board moves found");
    return "";
}

string generateBarMove() {
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: generateBarMove for " + currentTurn);
    
    if ((currentTurn == "white" && llGetListLength(WhiteBarList) == 0) ||
        (currentTurn == "black" && llGetListLength(BlackBarList) == 0)) {
        return "";
    }
    
    list diceToTry = [];
    
    // For doubles, we can use the same die value multiple times
    if (isDoubles && currentDie1 > 0) {
        diceToTry = [currentDie1, currentDie1, currentDie1, currentDie1];
    } else {
        // Normal roll - try each available die once
        if (currentDie1 > 0) diceToTry += currentDie1;
        if (currentDie2 > 0) diceToTry += currentDie2;
    }
    
    integer i;
    for (i = 0; i < llGetListLength(diceToTry); i++) {
        integer dieToUse = llList2Integer(diceToTry, i);
        
        if (dieToUse > 0) {
            integer targetPoint;
            
            // FIXED: Correct bar entry points
            if (currentTurn == "white") {
                // White enters counting UP: die 1→0, die 2→1, die 3→2, die 4→3, die 5→4, die 6→5
                targetPoint = dieToUse - 1;
            } else {
                // Black enters counting DOWN: die 1→23, die 2→22, die 3→21, die 4→20, die 5→19, die 6→18  
                targetPoint = 24 - dieToUse;
            }
            
            // Ensure target point is valid
            if (targetPoint >= 0 && targetPoint < BOARD_SIZE) {
                if (isValidBarMove(targetPoint)) {
                    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Valid bar move found - to point: " + (string)targetPoint + " using die: " + (string)dieToUse);
                    return "PLAYER_MOVE|" + currentTurn + "|" + (string)FROM_BAR + "|" + 
                           (string)targetPoint + "|" + (string)dieToUse + "|1";
                }
            }
        }
    }
    
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: No valid bar moves found");
    return "";
}

integer allPiecesInHomeBoard(integer color) {
    // Check bar first - if any pieces on bar, cannot be in home board
    if (color == 0 && llGetListLength(WhiteBarList) > 0) {
        if (DEBUG_MODE) llOwnerSay("DEBUG allPiecesInHomeBoard: White has pieces on bar - returning FALSE");
        return FALSE;
    }
    if (color == 1 && llGetListLength(BlackBarList) > 0) {
        if (DEBUG_MODE) llOwnerSay("DEBUG allPiecesInHomeBoard: Black has pieces on bar - returning FALSE");
         return FALSE;
    }
    
    // Define home board boundaries
    integer homeStart;
    integer homeEnd;
    string searchChar;
    
    if (color == 0) { // White
        homeStart = WHITE_HOME_START; // 18
        homeEnd = WHITE_HOME_END;     // 23
        searchChar = "w";
        if (DEBUG_MODE) llOwnerSay("DEBUG allPiecesInHomeBoard: White - checking points " + (string)(0) + " to " + (string)(homeStart - 1));
    } else { // Black  
        homeStart = BLACK_HOME_START; // 5
        homeEnd = BLACK_HOME_END;     // 0
        searchChar = "b";
        if (DEBUG_MODE) llOwnerSay("DEBUG allPiecesInHomeBoard: Black - checking points " + (string)(homeStart + 1) + " to 23");
    }
    
    // Efficient string search for pieces outside home board
    string outsideStr;
    
    if (color == 0) { // White
        // For white: check points 0-17 (everything before white home board)
        if (homeStart > 0) {
            outsideStr = llDumpList2String(llList2List(BoardList, 0, homeStart - 1), "|"); // 0-17
        }
    } else { // Black
        // For black: check points 6-23 (everything after black home board)
        if (homeEnd < 23) {
            outsideStr = llDumpList2String(llList2List(BoardList, homeStart + 1, 23), "|"); // 6-23
        }
    }
    
    // If we found the player's color in the outside string, return FALSE
    return (llSubStringIndex(outsideStr, searchChar) == -1);
}

integer playerHasPiecesOnBar(string player) {
    if (player == "white") {
        return (llGetListLength(WhiteBarList) > 0);
    } else {
        return (llGetListLength(BlackBarList) > 0);
    }
}

string getPlayerColor(string player) {
    if (player == "white") return "w";
    return "b";
}

// Get player's home board range
list getHomeBoardRange(string player) {
    if (player == "white") return [WHITE_HOME_START, WHITE_HOME_END];
    return [BLACK_HOME_START, BLACK_HOME_END];
}

string findBearOffMove(integer dieValue) {
    list range = getHomeBoardRange(currentTurn);
    integer homeStart = llList2Integer(range, 0);
    integer homeEnd = llList2Integer(range, 1);
    string playerColor = getPlayerColor(currentTurn);
    
    // Search from highest point to lowest point (furthest to closest)
    // This ensures we try to bear off from the furthest points first
    integer point;
    if (currentTurn == "white") {
        // White: search from 18 to 23 (furthest to closest)
        for (point = homeStart; point <= homeEnd; point++) {
            string pointContents = llList2String(BoardList, point);
            if (pointContents != "" && llSubStringIndex(pointContents, playerColor) != -1) {
                integer requiredDistance = 24 - point;
                
                // Validate using isValidBearOff to handle exact matches AND overshoots correctly
                integer color = 0; // white
                if (isValidBearOff(point, dieValue, color)) {
                    return createBearOffMove(point, dieValue);
                }
            }
        }
        
        // If no exact/overshoot found, try undershoot from closest points
        for (point = homeEnd; point >= homeStart; point--) {
            string pointContents = llList2String(BoardList, point);
            if (pointContents != "" && llSubStringIndex(pointContents, playerColor) != -1) {
                // Check if undershoot is valid (no pieces on points requiring larger dice)
                integer color = 0; // white
                if (isValidBearOff(point, dieValue, color)) {
                    return createBearOffMove(point, dieValue);
                }
            }
        }
    } else {
        // Black: search from 5 to 0 (furthest to closest)
        for (point = homeStart; point >= homeEnd; point--) {
            string pointContents = llList2String(BoardList, point);
            if (pointContents != "" && llSubStringIndex(pointContents, playerColor) != -1) {
                integer requiredDistance = point + 1;
                
                // Validate using isValidBearOff to handle exact matches AND overshoots correctly
                integer color = 1; // black
                if (isValidBearOff(point, dieValue, color)) {
                    return createBearOffMove(point, dieValue);
                }
            }
        }
        
        // If no exact/overshoot found, try undershoot from closest points
        for (point = homeEnd; point <= homeStart; point++) {
            string pointContents = llList2String(BoardList, point);
            if (pointContents != "" && llSubStringIndex(pointContents, playerColor) != -1) {
                // Check if undershoot is valid (no pieces on points requiring larger dice)
                integer color = 1; // black
                if (isValidBearOff(point, dieValue, color)) {
                    return createBearOffMove(point, dieValue);
                }
            }
        }
    }
    
    return "";
}
string createBearOffMove(integer point, integer dieValue) {
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Found bear off at point " + (string)point + " with die " + (string)dieValue);
    return "PLAYER_MOVE|" + currentTurn + "|" + (string)point + "|" + 
           (string)BEAR_OFF + "|" + (string)dieValue + "|1";
}

integer mustBearOff(string player) {
    integer color;
    if (player == "white")
        color = 0;
    else
        color = 1;
        
    integer result = allPiecesInHomeBoard(color);
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG: mustBearOff - player: " + player + ", color: " + (string)color + ", result: " + (string)result);
    }
    
    return result;
}

string generateBearOffMove() {
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: generateBearOffMove for " + currentTurn);
    
    if (!mustBearOff(currentTurn)) {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Not in bearing off phase");
        return "";
    }
    
    list diceToTry = [];
    
    if (isDoubles && currentDie1 > 0) {
        diceToTry = [currentDie1, currentDie1, currentDie1, currentDie1];
    } else {
        if (currentDie1 > 0) diceToTry += currentDie1;
        if (currentDie2 > 0) diceToTry += currentDie2;
    }
    
    integer i;
    for (i = 0; i < llGetListLength(diceToTry); i++) {
        integer dieToUse = llList2Integer(diceToTry, i);
        if (dieToUse > 0) {
            string move = findBearOffMove(dieToUse);
            if (move != "") return move;
        }
    }
    
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: No valid bear off moves found");
    return "";
}

list getAllValidMoves() {
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: getAllValidMoves for " + currentTurn);
    list allMoves = [];
    
    // ENFORCEMENT: Check if player has pieces on bar - if yes, ONLY bar moves allowed
    if (currentTurn == "white" && llGetListLength(WhiteBarList) > 0) {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: White has pieces on bar - only considering bar moves");
        string barMove = generateBarMove(); // Currently returns ONE move. Need to fix this too?
        // For now, let's assume generateBarMove returns a single valid move. 
        // Ideally it should return ALL valid bar moves.
        // But the current implementation of generateBarMove returns the FIRST valid one.
        // For AI v1, this is acceptable for bar moves (usually obvious).
        if (barMove != "") allMoves += [barMove];
        return allMoves;
    }
    else if (currentTurn == "black" && llGetListLength(BlackBarList) > 0) {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Black has pieces on bar - only considering bar moves");
        string barMove = generateBarMove();
        if (barMove != "") allMoves += [barMove];
        return allMoves;
    }
    
    // ENFORCEMENT: Check if player must bear off - if yes, ONLY bear off moves allowed
    if (mustBearOff(currentTurn)) {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Player must bear off - only considering bear off moves");
        // Same issue: generateBearOffMove returns FIRST valid move.
        // We should really refactor those too, but for now let's stick to the existing one
        // and maybe just return that one move.
        string bearOffMove = generateBearOffMove();
        if (bearOffMove != "") {
            allMoves += [bearOffMove];
            return allMoves;
        } else {
            // CANNOT BEAR OFF - try to move forward in home board
            if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Cannot bear off - trying to move within home board");
            string homeMove = generateHomeBoardMove();
            if (homeMove != "") allMoves += [homeMove];
            return allMoves;
        }
    }

    // Existing logic for regular moves
    // REVERSE the iteration order for black
    integer startPoint = 0;
    integer endPoint = BOARD_SIZE - 1;
    integer step = 1;
    
    if (currentTurn == "black") {
        startPoint = BOARD_SIZE - 1;
        endPoint = 0;
        step = -1;
    }
    
    integer i = startPoint;
    while ((currentTurn == "white" && i <= endPoint) || (currentTurn == "black" && i >= endPoint)) {
        string point = llList2String(BoardList, i);
        if (point != "") {
            string playerColor;
            if (currentTurn == "white") playerColor = "w";
            else playerColor = "b";
            
            if (llSubStringIndex(point, playerColor) != -1) {
                list movesFromPoint = getValidMovesFromPoint(i);
                if (llGetListLength(movesFromPoint) > 0) {
                    allMoves += movesFromPoint;
                }
            }
        }
        i = i + step;
    }

    return allMoves;
}

string checkSingleDieMove(integer fromPoint, integer dieValue, integer direction) {
    integer toPoint = fromPoint + (dieValue * direction);
    
    if (toPoint < 0 || toPoint >= BOARD_SIZE) {
        // Bearing off
        integer color;
        if (currentTurn == "white") color = 0;
        else color = 1;
        
        if (isValidBearOff(fromPoint, dieValue, color)) {
            return "PLAYER_MOVE|" + currentTurn + "|" + (string)fromPoint + "|" + 
                   (string)BEAR_OFF + "|" + (string)dieValue + "|1";
        }
    } else {
        // Normal move
        if (isValidMove(fromPoint, toPoint, dieValue)) {
            return "PLAYER_MOVE|" + currentTurn + "|" + (string)fromPoint + "|" + 
                   (string)toPoint + "|" + (string)dieValue + "|1";
        }
    }
    
    return "";
}

integer isValidBarMove(integer targetPoint) {
    string target = llList2String(BoardList, targetPoint);
    string opponentColor;
    if (currentTurn == "black") {
        opponentColor = "w";
    } else {
        opponentColor = "b";
    }
    
    integer opponentCount = 0;
    if (target != "") {
        list pieces = llParseString2List(target, [","], []);
        integer i;
        for (i = 0; i < llGetListLength(pieces); i++) {
            string piece = llList2String(pieces, i);
            if (llGetSubString(piece, 0, 0) == opponentColor) {
                opponentCount = opponentCount + 1;
            }
        }
    }
    
    return (opponentCount < 2);
}

list getValidMovesFromPoint(integer fromPoint) {
    list moves = [];
    
    // ENFORCEMENT: If must bear off, don't return any regular moves
    if (mustBearOff(currentTurn)) {
        return [];  // No regular moves allowed during bearing off
    }
    
    integer direction;
    if (currentTurn == "white") {
        direction = 1;  // White moves from low to high: 0→1→2...→23
    } else {
        direction = -1; // Black moves from high to low: 23→22→21...→0
    }
    
    if (currentDie1 > 0) {
        string move = checkSingleDieMove(fromPoint, currentDie1, direction);
        if (move != "") moves += [move];
    }
    
    if (currentDie2 > 0) {
        string move = checkSingleDieMove(fromPoint, currentDie2, direction);
        if (move != "") moves += [move];
    }
    
    // Check combined die move (if both dice are available and not doubles)
    if (!isDoubles && currentDie1 > 0 && currentDie2 > 0) {
        integer combinedDie = currentDie1 + currentDie2;
        string move = checkSingleDieMove(fromPoint, combinedDie, direction);
        
        if (move != "") {
            // Validate intermediate points for combined moves
            integer mid1 = fromPoint + (currentDie1 * direction);
            integer mid2 = fromPoint + (currentDie2 * direction);
            
            integer validPath = FALSE;
            
            // Check path 1: d1 first
            if (isValidMove(fromPoint, mid1, currentDie1)) validPath = TRUE;
            
            // Check path 2: d2 first (if path 1 invalid)
            if (!validPath && isValidMove(fromPoint, mid2, currentDie2)) validPath = TRUE;
            
            if (validPath) {
                // Format the move to indicate it uses both dice
                move = "PLAYER_MOVE|" + currentTurn + "|" + (string)fromPoint + "|" + 
                       llList2String(llParseString2List(move, ["|"], []), 3) + "|" + 
                       (string)combinedDie + "|2";
                moves += [move];
            } else {
                 if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Combined move blocked at intermediate point");
            }
        }
    }
    
    return moves;
}

integer isValidMove(integer fromPoint, integer toPoint, integer dieValue) {
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG BRAIN: isValidMove checking from " + (string)fromPoint + " to " + (string)toPoint);
    }
    
    if (toPoint < 0 || toPoint >= BOARD_SIZE) {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Invalid move - toPoint out of bounds: " + (string)toPoint);
        return FALSE;
    }
    
    string target = llList2String(BoardList, toPoint);
    string opponentColor;
    if (currentTurn == "black") {
        opponentColor = "w";
    } else {
        opponentColor = "b";
    }
    
    integer opponentCount = 0;
    if (target != "") {
        integer pos = 0;
        while (pos < llStringLength(target)) {
            string char = llGetSubString(target, pos, pos);
            if (char == opponentColor) opponentCount = opponentCount + 1;
            pos = pos + 1;
        }
    }
    
    integer isValid = (opponentCount < 2);
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG BRAIN: Checking move from " + (string)fromPoint + " to " + (string)toPoint + 
                   " - target: '" + target + "', opponentCount: " + (string)opponentCount + 
                   ", isValid: " + (string)isValid);
    }
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG BRAIN: isValidMove result: " + (string)isValid + " for from " + (string)fromPoint + " to " + (string)toPoint);
    }
    return isValid;
}

// --- HEURISTICS & SCORING ---

// Helper to simulate a move and return the new board state
list simulateMove(list currentBoard, integer fromPoint, integer toPoint, string playerColor) {
    list newBoard = currentBoard;
    string opponentColor = "b";
    if (playerColor == "b") opponentColor = "w";
    
    // 1. Remove from source
    if (fromPoint != FROM_BAR) {
        string sourceContent = llList2String(newBoard, fromPoint);
        // Remove one piece
        integer idx = llSubStringIndex(sourceContent, playerColor);
        if (idx != -1) {
            sourceContent = llDeleteSubString(sourceContent, idx, idx);
            // If empty, ensure it's empty string
            if (sourceContent == "") sourceContent = ""; 
            newBoard = llListReplaceList(newBoard, [sourceContent], fromPoint, fromPoint);
        }
    }
    
    // 2. Add to destination
    if (toPoint == BEAR_OFF) {
        // Just removed from board, nothing to add
    } else {
        string destContent = llList2String(newBoard, toPoint);
        
        // Check for hit
        if (llSubStringIndex(destContent, opponentColor) != -1) {
            // Hit! Opponent piece is removed (sent to bar - we don't track bar in simulation for scoring yet, just board)
            // Ideally we should track bar count for scoring "Hit"
            destContent = playerColor; // Replace opponent with us
        } else {
            // Add to stack
            if (destContent == "") destContent = playerColor;
            else destContent += playerColor;
        }
        newBoard = llListReplaceList(newBoard, [destContent], toPoint, toPoint);
    }
    
    return newBoard;
}

// === STRATEGIC AI HELPERS ===

integer calculatePipCount(list board, string color, list barList) {
    // Calculate total pips (distance to bear off)
    // Lower is better
    integer totalPips = 0;
    
    // Bar pieces count as 25 pips from home
    totalPips += llGetListLength(barList) * 25;
    
    integer i;
    for (i = 0; i < BOARD_SIZE; i++) {
        string content = llList2String(board, i);
        if (content != "") {
            // Count pieces of this color at this point
            integer count = 0;
            integer j;
            for (j = 0; j < llStringLength(content); j++) {
                if (llGetSubString(content, j, j) == color) count++;
            }
            
            if (count > 0) {
                // Distance calculation depends on color
                integer distance;
                if (color == "w") {
                    distance = 24 - i; // White moves toward point 23
                } else {
                    distance = i + 1;  // Black moves toward point 0
                }
                totalPips += count * distance;
            }
        }
    }
    
    return totalPips;
}

integer isMadePoint(list board, integer point, string color) {
    // Check if point has 2+ pieces of specified color
    if (point < 0 || point >= BOARD_SIZE) return FALSE;
    
    string content = llList2String(board, point);
    if (content == "") return FALSE;
    
    integer count = 0;
    integer i;
    for (i = 0; i < llStringLength(content); i++) {
        if (llGetSubString(content, i, i) == color) count++;
    }
    
    return (count >= 2);
}

integer countConsecutivePoints(list board, string color) {
    // Count longest sequence of consecutive made points
    integer maxPrime = 0;
    integer currentPrime = 0;
    
    integer i;
    for (i = 0; i < BOARD_SIZE; i++) {
        if (isMadePoint(board, i, color)) {
            currentPrime++;
            if (currentPrime > maxPrime) maxPrime = currentPrime;
        } else {
            currentPrime = 0;
        }
    }
    
    return maxPrime;
}

integer evaluateBoard(list board, string playerColor) {
    integer score = 0;
    string opponentColor = "b";
    if (playerColor == "b") opponentColor = "w";
    
    // === BASIC HEURISTICS ===
    integer i;
    for (i = 0; i < BOARD_SIZE; i++) {
        string content = llList2String(board, i);
        integer len = llStringLength(content);
        
        if (len > 0) {
            string p = llGetSubString(content, 0, 0);
            if (p == playerColor) {
                // Own piece
                if (len == 1) score += W_BLOT; // Blot (Vulnerable)
                else if (len >= 2) score += W_MADE_POINT; // Made Point
            }
        }
    }
    
    // === STRATEGIC HEURISTICS ===
    
    // 1. Pip Count (Race Position)
    list ourBarList = WhiteBarList;
    list oppBarList = BlackBarList;
    if (playerColor == "b") {
        ourBarList = BlackBarList;
        oppBarList = WhiteBarList;
    }
    
    integer ourPips = calculatePipCount(board, playerColor, ourBarList);
    integer oppPips = calculatePipCount(board, opponentColor, oppBarList);
    integer pipDiff = oppPips - ourPips;
    // Positive pipDiff means we are ahead (our pips < opp pips)
    if (pipDiff > 0) score += (pipDiff * W_PIP_WEIGHT) / 2; // Winning race
    else score += (pipDiff * W_PIP_WEIGHT) / 3; // Losing race (less penalty)
    
    // 2. Prime Building (Consecutive Points)
    integer primeLength = countConsecutivePoints(board, playerColor);
    score += primeLength * W_PRIME_FACTOR; // Strong primes block opponent
    
    // 3. Anchor Control (Points in Opponent's Home)
    string oppTurnName;
    if (opponentColor == "w") {
        oppTurnName = "white";
    } else {
        oppTurnName = "black";
    }
    list oppHomeRange = getHomeBoardRange(oppTurnName);
    integer oppHomeStart = llList2Integer(oppHomeRange, 0);
    integer oppHomeEnd = llList2Integer(oppHomeRange, 1);
    
    integer anchorCount = 0;
    if (opponentColor == "w") {
        // Check white's home (18-23)
        for (i = oppHomeStart; i <= oppHomeEnd; i++) {
            if (isMadePoint(board, i, playerColor)) anchorCount++;
        }
    } else {
        // Check black's home (0-5)
        for (i = oppHomeEnd; i <= oppHomeStart; i++) {
            if (isMadePoint(board, i, playerColor)) anchorCount++;
        }
    }
    score += anchorCount * W_ANCHOR; // Defensive anchors
    
    // 4. Bar Penalty
    score += llGetListLength(ourBarList) * W_BAR_SELF; // Heavy penalty for being on bar
    score += llGetListLength(oppBarList) * W_BAR_OPP; // Reward for hitting opponent
    
    return score;
}

string generateRandomMove() {
    list moves = getAllValidMoves();
    if (llGetListLength(moves) == 0) return "";
    return llList2String(moves, (integer)llFrand(llGetListLength(moves)));
}

string pickBestMove(integer level) {
    list moves = getAllValidMoves();
    integer count = llGetListLength(moves);
    
    if (count == 0) return "";
    if (count == 1) return llList2String(moves, 0);
    
    string bestMove = "";
    integer bestScore = -99999;
    
    string playerColor = "w";
    if (currentTurn == "black") playerColor = "b";
    
    integer i;
    for (i = 0; i < count; i++) {
        string moveStr = llList2String(moves, i);
        // Parse move to get from/to
        list parts = llParseString2List(moveStr, ["|"], []);
        // Format: PLAYER_MOVE|color|from|to|die|...
        integer fromP = llList2Integer(parts, 2);
        integer toP = llList2Integer(parts, 3);
        
        // Simulate
        list nextBoard = simulateMove(BoardList, fromP, toP, playerColor);
        
        // Score
        integer score = evaluateBoard(nextBoard, playerColor);
        
        // Add randomness for variety if scores are equal?
        // Or add small random weight
        if (level == LEVEL_TACTICAL) {
             // Tactical specific bonuses could be added here
        }
        
        if (score > bestScore) {
            bestScore = score;
            bestMove = moveStr;
        }
    }
    
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Best move score: " + (string)bestScore);
    return bestMove;
}

generateAIMove() {
    if (DEBUG_MODE) llOwnerSay("BRAIN Level " + (string)AI_LEVEL + " generating move...");
    
    string move = "";
    
    if (AI_LEVEL == LEVEL_RANDOM) {
        move = generateRandomMove();
    }
    else if (AI_LEVEL == LEVEL_TACTICAL) {
        move = generateTacticalMove();
    }
    else if (AI_LEVEL == LEVEL_STRATEGIC) {
        move = generateStrategicMove();
    }
    
    if (move != "") {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Decision made: " + move);
        llMessageLinked(LINK_SET, 0, "AI_DECISION|" + move, NULL_KEY);
    } else {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: No valid moves found");
        llMessageLinked(LINK_SET, 0, "AI_DECISION|NO_MOVE", NULL_KEY);
    }
}


// === TACTICAL AI HELPERS ===

list filterHittingMoves(list moves) {
    // Return moves that would hit an opponent piece (send to bar)
    list hittingMoves = [];
    string opponentColor = "b";
    if (currentTurn == "black") opponentColor = "w";
    
    integer i;
    for (i = 0; i < llGetListLength(moves); i++) {
        string move = llList2String(moves, i);
        list parts = llParseStringKeepNulls(move, ["|"], []);
        // Format: PLAYER_MOVE|color|from|to|die|movesUsed
        integer toPoint = llList2Integer(parts, 3);
        
        // Check if destination has exactly 1 opponent piece (a blot)
        if (toPoint >= 0 && toPoint < BOARD_SIZE) {
            string pointContents = llList2String(BoardList, toPoint);
            if (pointContents != "") {
                list pieces = llParseStringKeepNulls(pointContents, [","], []);
                integer oppCount = 0;
                integer j;
                for (j = 0; j < llGetListLength(pieces); j++) {
                    string piece = llList2String(pieces, j);
                    if (llGetSubString(piece, 0, 0) == opponentColor) oppCount++;
                }
                if (oppCount == 1) {
                    hittingMoves += [move];
                }
            }
        }
    }
    
    return hittingMoves;
}

list filterPointMakingMoves(list moves) {
    // Return moves that would create a point (2+ pieces on same spot)
    list pointMakingMoves = [];
    string playerColor = getPlayerColor(currentTurn);
    
    integer i;
    for (i = 0; i < llGetListLength(moves); i++) {
        string move = llList2String(moves, i);
        list parts = llParseStringKeepNulls(move, ["|"], []);
        integer toPoint = llList2Integer(parts, 3);
        
        // Check if destination already has exactly 1 of our pieces
        if (toPoint >= 0 && toPoint < BOARD_SIZE) {
            string pointContents = llList2String(BoardList, toPoint);
            if (pointContents != "") {
                list pieces = llParseStringKeepNulls(pointContents, [","], []);
                integer ourCount = 0;
                integer j;
                for (j = 0; j < llGetListLength(pieces); j++) {
                    string piece = llList2String(pieces, j);
                    if (llGetSubString(piece, 0, 0) == playerColor) ourCount++;
                }
                if (ourCount == 1) {
                    pointMakingMoves += [move];
                }
            }
        }
    }
    
    return pointMakingMoves;
}

list filterRunningMoves(list moves) {
    // Return moves from the furthest back third of the board
    // White: prioritize from points 0-7, Black: prioritize from points 16-23
    list runningMoves = [];
    
    integer i;
    for (i = 0; i < llGetListLength(moves); i++) {
        string move = llList2String(moves, i);
        list parts = llParseStringKeepNulls(move, ["|"], []);
        integer fromPoint = llList2Integer(parts, 2);
        
        // Skip bar moves (FROM_BAR = -2)
        if (fromPoint != FROM_BAR) {
            if (currentTurn == "white") {
                // White runs from low points (0-7)
                if (fromPoint >= 0 && fromPoint <= 7) {
                    runningMoves += [move];
                }
            } else {
                // Black runs from high points (16-23)
                if (fromPoint >= 16 && fromPoint <= 23) {
                    runningMoves += [move];
                }
            }
        }
    }
    
    return runningMoves;
}

string generateTacticalMove() {
    // Tactical: Prioritize Hitting > Point-Making > Running
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Generating Tactical move");
    
    list allMoves = getAllValidMoves();
    if (llGetListLength(allMoves) == 0) return "";
    
    // Priority 1: Hitting
    list hittingMoves = filterHittingMoves(allMoves);
    if (llGetListLength(hittingMoves) > 0) {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Tactical - Choosing hitting move");
        return llList2String(hittingMoves, (integer)llFrand(llGetListLength(hittingMoves)));
    }
    
    // Priority 2: Point-Making
    list pointMakingMoves = filterPointMakingMoves(allMoves);
    if (llGetListLength(pointMakingMoves) > 0) {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Tactical - Choosing point-making move");
        return llList2String(pointMakingMoves, (integer)llFrand(llGetListLength(pointMakingMoves)));
    }
    
    // Priority 3: Running
    list runningMoves = filterRunningMoves(allMoves);
    if (llGetListLength(runningMoves) > 0) {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Tactical - Choosing running move");
        return llList2String(runningMoves, (integer)llFrand(llGetListLength(runningMoves)));
    }
    
    // Fallback: Random
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Tactical - Fallback to random");
    return generateRandomMove();
}


string generateStrategicMove() {
    // Strategic: Full board evaluation with scoring
    if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Generating Strategic move");
    return pickBestMove(LEVEL_STRATEGIC);
}

integer isValidBearOff(integer from_point, integer die_value, integer color) {
    if (!allPiecesInHomeBoard(color)) {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Not all pieces in home board");
        return FALSE;
    }
    
    // Check if point is in player's home board
    integer inHomeBoard = FALSE;
    if (color == 0) { // White
        if (from_point >= WHITE_HOME_START && from_point <= WHITE_HOME_END) {
            inHomeBoard = TRUE;
        }
    } else { // Black
        if (from_point <= BLACK_HOME_START && from_point >= BLACK_HOME_END) {
            inHomeBoard = TRUE;
        }
    }
    
    if (!inHomeBoard) {
        if (DEBUG_MODE) llOwnerSay("DEBUG BRAIN: Point not in home board");
        return FALSE;
    }
    
    // Calculate required bear off distance
    integer requiredDistance;
    if (color == 0) { // White
        requiredDistance = 24 - from_point;
    } else { // Black
        requiredDistance = from_point + 1;
    }
    
    // Exact match is always valid
    if (die_value == requiredDistance) {
        return TRUE;
    }
    
    // Overshoot: Die is larger than required.
    // Valid ONLY if there are no pieces at points further away from the bear-off edge.
    if (die_value > requiredDistance) {
        string playerColor = "w";
        if (color == 1) playerColor = "b";
        
        if (color == 0) { // White (Home 18-23)
            // Check points further away: from WHITE_HOME_START (18) up to from_point - 1
            integer i;
            for (i = WHITE_HOME_START; i < from_point; i++) {
                string point = llList2String(BoardList, i);
                if (point != "" && llSubStringIndex(point, playerColor) != -1) {
                    return FALSE; // Found a piece further away
                }
            }
            return TRUE;
        } else { // Black (Home 5-0)
            // Check points further away: from from_point + 1 up to BLACK_HOME_START (5)
            integer i;
            for (i = from_point + 1; i <= BLACK_HOME_START; i++) {
                string point = llList2String(BoardList, i);
                if (point != "" && llSubStringIndex(point, playerColor) != -1) {
                    return FALSE; // Found a piece further away
                }
            }
            return TRUE;
        }
    }
    
    // Undershoot: Die is smaller than required.
    // Never valid for bear-off (must move forward within board).
    return FALSE;
}

default {
    state_entry() {
        if (DEBUG_MODE) llOwnerSay("Backgammon AI BRAIN initialized");
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list params = llParseStringKeepNulls(str, ["|"], []);
        string command = llList2String(params, 0);
        
        if (command == "SET_AI_LEVEL") {
            string player = llList2String(params, 1);
            integer level = llList2Integer(params, 2);
            
            if (player == "white") gWhiteAILevel = level;
            else if (player == "black") gBlackAILevel = level;
        }
        else if (command == "AI_THINK") {
            currentTurn = llList2String(params, 1);
            currentDie1 = llList2Integer(params, 2);
            currentDie2 = llList2Integer(params, 3);
            isDoubles = llList2Integer(params, 4);
            movesLeft = llList2Integer(params, 5);
            AI_LEVEL = llList2Integer(params, 6);
            
            generateAIMove();
        }
        else if (command == "SYNC_BOARD") {
            // Reconstruct board from params
            // Format: SYNC_BOARD|p0|p1|...|p23|whiteBar|blackBar|whiteOff|blackOff
            list newBoard = [];
            integer idx = 1;
            integer i;
            for (i = 0; i < 24; i++) {
                newBoard += llList2String(params, idx);
                idx++;
            }
            BoardList = newBoard;
            
            // Update bar and borne off lists - handle empty strings correctly
            string whiteBarStr = llList2String(params, idx); idx++;
            if (whiteBarStr == "") WhiteBarList = [];
            else WhiteBarList = llParseString2List(whiteBarStr, [","], []);
            
            string blackBarStr = llList2String(params, idx); idx++;
            if (blackBarStr == "") BlackBarList = [];
            else BlackBarList = llParseString2List(blackBarStr, [","], []);
            
            string whiteOffStr = llList2String(params, idx); idx++;
            if (whiteOffStr == "") WhiteBorneOff = [];
            else WhiteBorneOff = llParseString2List(whiteOffStr, [","], []);
            
            string blackOffStr = llList2String(params, idx); idx++;
            if (blackOffStr == "") BlackBorneOff = [];
            else BlackBorneOff = llParseString2List(blackOffStr, [","], []);
        }
    }    
}
