// BACKGAMMON CORE - Optimized game logic
integer DEBUG_MODE = TRUE; // Reduced for production

// Game constants
integer BOARD_SIZE = 24;
integer FROM_BAR = -2;
integer BEAR_OFF = -1;
integer WHITE_HOME_START = 18;
integer WHITE_HOME_END = 23;
integer BLACK_HOME_START = 5;
integer BLACK_HOME_END = 0;

// Game state
integer gCurrentState = 0;
integer STATE_RESET = 0;
integer STATE_FIRST_ROLL = 1;
integer STATE_MAIN_GAME = 2;
integer STATE_GAME_OVER = 3;

string turn = "";
integer whiteDie;
integer whiteDie1;
integer whiteDie2;
integer blackDie;
integer blackDie1;
integer blackDie2;
integer whiteOnce = FALSE;
integer blackOnce = FALSE;
integer u1 = 0;
integer u2 = 0;
integer isDoubles = FALSE;
integer movesLeft = 0;

// Players
key white = NULL_KEY;
key black = NULL_KEY;
integer whitePresent = FALSE;
integer blackPresent = FALSE;

// Game data
list BoardList;
list WhiteBarList = [];
list BlackBarList = [];
list WhiteBorneOff = [];
list BlackBorneOff = [];

// Move deduplication
list gRecentMoveIDs = [];
integer MAX_MOVE_HISTORY = 10;

// CONTROL STATE from Menu
integer CORE_WHITE_AI = FALSE;
integer CORE_BLACK_AI = FALSE;

// ===== OPTIMIZED HELPER FUNCTIONS =====
integer getRequiredBearOffDistance(integer point, integer color) {
    if (color == 0) return 24 - point;
    return point + 1;
}

integer hasPlayerPieceAtPoint(integer point, string playerColor) {
    string pointContents = llList2String(BoardList, point);
    return (pointContents != "" && llSubStringIndex(pointContents, playerColor) != -1);
}

integer isPointBlocked(integer point, integer color) {
    if (point < 0 || point >= BOARD_SIZE) return FALSE; // Off board is not "blocked" in this sense
    
    string pointContents = llList2String(BoardList, point);
    if (pointContents == "") return FALSE;
    
    string oppColor = "b";
    if (color == 1) oppColor = "w";
    
    list pieces = llParseString2List(pointContents, [","], []);
    integer oppCount = 0;
    integer j;
    for(j=0; j<llGetListLength(pieces); j++) {
        if (llGetSubString(llList2String(pieces, j), 0, 0) == oppColor) oppCount++;
    }
    
    return (oppCount >= 2);
}

sendBarStateToRender() {
    string barStateMessage = "BAR_STATE|" + 
        llDumpList2String(WhiteBarList, "|") + "|" + 
        llDumpList2String(BlackBarList, "|");
    llMessageLinked(LINK_SET, 0, barStateMessage, NULL_KEY);
}

string MoveStone(integer from_point, integer to_point, integer color) {
    string fromPointContents = llList2String(BoardList, from_point);
    string toPointContents = llList2String(BoardList, to_point);
    
    if (DEBUG_MODE) llOwnerSay("DEBUG CORE: MoveStone " + (string)from_point + "->" + (string)to_point + " Content: '" + fromPointContents + "'");

    string playerColor = "w";
    if (color == 1) playerColor = "b";
    
    // Extract piece to move
    list fromPieces = llParseString2List(fromPointContents, [","], []);
    string pieceToMove = "";
    integer i = 0;
    integer found = FALSE;
    
    while (i < llGetListLength(fromPieces) && !found) {
        string piece = llList2String(fromPieces, i);
        if (llGetSubString(piece, 0, 0) == playerColor) {
            pieceToMove = piece;
            found = TRUE;
        }
        i++;
    }
    
    if (pieceToMove == "") {
        if (DEBUG_MODE) llOwnerSay("DEBUG CORE: No piece found for color " + playerColor);
        return "";
    }
    
    // Remove from source
    integer pieceIndex = llListFindList(fromPieces, [pieceToMove]);
    if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Found piece " + pieceToMove + " at index " + (string)pieceIndex);

    if (pieceIndex != -1) {
        fromPieces = llDeleteSubList(fromPieces, pieceIndex, pieceIndex);
    }
    string newFromContents = llDumpList2String(fromPieces, ",");
    if (DEBUG_MODE) llOwnerSay("DEBUG CORE: New From Content: '" + newFromContents + "'");
    
    list toPieces = llParseString2List(toPointContents, [","], []);
    string opponentColor = "b";
    if (color == 1) opponentColor = "w";
    
    // Check for hits
    if (toPointContents != "") {
        integer opponentCount = 0;
        string opponentPiece = "";
        integer j = 0;
        
        while (j < llGetListLength(toPieces)) {
            string piece = llList2String(toPieces, j);
            if (llGetSubString(piece, 0, 0) == opponentColor) {
                opponentCount++;
                opponentPiece = piece;
            }
            j++;
        }
        
        if (opponentCount >= 2) return "";
        
        if (opponentCount == 1) {
            integer oppIndex = llListFindList(toPieces, [opponentPiece]);
            if (oppIndex != -1) {
                toPieces = llDeleteSubList(toPieces, oppIndex, oppIndex);
            }
            
            if (opponentColor == "w") {
                WhiteBarList = WhiteBarList + [opponentPiece];
            } else {
                BlackBarList = BlackBarList + [opponentPiece];
            }
            
            llMessageLinked(LINK_SET, 0, "HIT_PIECE|" + opponentPiece + "|" + (string)to_point, NULL_KEY);
        }
    }
    
    // Add to destination
    toPieces = toPieces + [pieceToMove];
    string newToContents = llDumpList2String(toPieces, ",");
    
    BoardList = llListReplaceList(BoardList, [newFromContents], from_point, from_point);
    BoardList = llListReplaceList(BoardList, [newToContents], to_point, to_point);
    
    if (DEBUG_MODE) {
        string checkFrom = llList2String(BoardList, from_point);
        llOwnerSay("DEBUG CORE: Verify Update - Point " + (string)from_point + " is now: '" + checkFrom + "'");
    }
    
    return pieceToMove;
}

integer isValidBarMove(integer to_point, integer color) {
    string targetPoint = llList2String(BoardList, to_point);
    string opponentColor = "b";
    if (color == 1) opponentColor = "w";
    
    integer opponentCount = 0;
    if (targetPoint != "") {
        list pieces = llParseString2List(targetPoint, [","], []);
        integer i;
        for (i = 0; i < llGetListLength(pieces); i++) {
            string piece = llList2String(pieces, i);
            if (llGetSubString(piece, 0, 0) == opponentColor) {
                opponentCount++;
            }
        }
    }
    
    return (opponentCount < 2);
}

integer pointToInternal(integer point, integer color) {
    if (point < 0) return point;
    if (color == 0) return point - 1;
    return BOARD_SIZE - point;
}

list getHomeBoardRange(string player) {
    if (player == "white") return [WHITE_HOME_START, WHITE_HOME_END];
    return [BLACK_HOME_START, BLACK_HOME_END];
}

integer allPiecesInHomeBoard(integer color) {
    if (color == 0 && llGetListLength(WhiteBarList) > 0) return FALSE;
    if (color == 1 && llGetListLength(BlackBarList) > 0) return FALSE;
    
    integer homeStart;
    integer homeEnd;
    string searchChar;
    
    if (color == 0) {
        homeStart = WHITE_HOME_START;
        homeEnd = WHITE_HOME_END;
        searchChar = "w";
    } else {
        homeStart = BLACK_HOME_START;
        homeEnd = BLACK_HOME_END;
        searchChar = "b";
    }
    
    string outsideStr;
    if (color == 0) {
        if (homeStart > 0) {
            outsideStr = llDumpList2String(llList2List(BoardList, 0, homeStart - 1), "|");
        }
    } else {
        if (homeEnd < 23) {
            outsideStr = llDumpList2String(llList2List(BoardList, homeStart + 1, 23), "|");
        }
    }
    
    return (llSubStringIndex(outsideStr, searchChar) == -1);
}

integer isPointInHomeBoard(integer point, integer color) {
    if (color == 0) return (point >= WHITE_HOME_START && point <= WHITE_HOME_END);
    return (point <= BLACK_HOME_START && point >= BLACK_HOME_END);
}

integer isValidBearOff(integer from_point, integer die_value, integer color) {
    if (!allPiecesInHomeBoard(color)) {
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

integer mustBearOff(integer color) {
    return allPiecesInHomeBoard(color);
}

list calculateValidMoves(integer fromPoint, integer color) {
    if (DEBUG_MODE) llOwnerSay("DEBUG CORE: calculateValidMoves from=" + (string)fromPoint + " movesLeft=" + (string)movesLeft + " isDoubles=" + (string)isDoubles);
    list moves = [];
    
    // Special handling for bar entry
    if (fromPoint == FROM_BAR) {
        list singleDice = [];
        if (u1 > 0) singleDice += u1;
        if (u2 > 0) singleDice += u2;
        if (isDoubles && movesLeft > 0) singleDice = [u1];
        
        integer i;
        for(i = 0; i < llGetListLength(singleDice); i++) {
            integer die = llList2Integer(singleDice, i);
            integer entryPoint;
            
            // Bar entry points are different for each color
            if (color == 0) {
                // White enters on points 0-23 (die 1 = point 0, die 6 = point 5)
                entryPoint = die - 1;
            } else {
                // Black enters on points 0-23 (die 1 = point 23, die 6 = point 18)
                entryPoint = 24 - die;
            }
            
            if (entryPoint >= 0 && entryPoint < BOARD_SIZE && !isPointBlocked(entryPoint, color)) {
                if (llListFindList(moves, [entryPoint]) == -1) moves += entryPoint;
            }
        }
        
        return moves;
    }
    
    // Check if we MUST bear off (all pieces in home board)
    integer bearingOff = mustBearOff(color);
    
    integer direction = 1;
    if (color == 1) direction = -1; // Black moves down
    
    // 1. Check Single Dice Moves
    list singleDice = [];
    if (u1 > 0) singleDice += u1;
    if (u2 > 0) singleDice += u2;
    
    // If doubles, we treat the first move as a single die move of value u1
    if (isDoubles && movesLeft > 0) {
        singleDice = [u1];
    }
    
    integer i;
    for(i = 0; i < llGetListLength(singleDice); i++) {
        integer die = llList2Integer(singleDice, i);
        integer toPoint = fromPoint + (die * direction);
        
        if (toPoint < 0 || toPoint >= BOARD_SIZE) {
            if (bearingOff && isValidBearOff(fromPoint, die, color)) {
                if (llListFindList(moves, [BEAR_OFF]) == -1) moves += BEAR_OFF;
            }
        } else {
            // Check if this is a valid regular move
            if (!isPointBlocked(toPoint, color)) {
                if (llListFindList(moves, [toPoint]) == -1) moves += toPoint;
            }
            // Also check if bear-off is valid (for undershoot scenarios)
            if (bearingOff && isValidBearOff(fromPoint, die, color)) {
                if (llListFindList(moves, [BEAR_OFF]) == -1) moves += BEAR_OFF;
            }
        }
    }
    
    // 2. Check Combined/Multi-Step Moves
    // Only if we have valid single moves can we potentially go further
    
    if (isDoubles && movesLeft >= 2) {
        if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Checking combined moves for doubles");
        // Doubles Logic: Check sequential steps
        // We can move 2*die if 1*die is valid (or bearoff)
        // We can move 3*die if 2*die is valid, etc.
        
        integer die = u1;
        integer currentPoint = fromPoint;
        integer stepsPossible = 0; // How many steps of 'die' we can take
        
        integer k;
        for(k = 1; k <= movesLeft; k++) {
            integer nextPoint = currentPoint + (die * direction);
            
            integer stepValid = FALSE;
            if (nextPoint < 0 || nextPoint >= BOARD_SIZE) {
                if (bearingOff && isValidBearOff(currentPoint, die, color)) {
                    stepValid = TRUE;
                    // Once borne off, we can't move further from this piece's perspective
                    // But we record this "destination" as valid
                    if (llListFindList(moves, [BEAR_OFF]) == -1) moves += BEAR_OFF;
                    k = movesLeft + 1; // Stop checking further steps
                }
            } else {
                if (!isPointBlocked(nextPoint, color)) {
                    stepValid = TRUE;
                    currentPoint = nextPoint;
                    // This intermediate or final point is reachable
                    if (llListFindList(moves, [currentPoint]) == -1) moves += currentPoint;
                }
            }
            
            if (!stepValid) k = movesLeft + 1; // Blocked, stop checking
        }
    } 
    else if (!isDoubles && u1 > 0 && u2 > 0) {
        // Combined Logic (Non-Doubles): u1+u2
        // Valid if: (from+u1 is valid AND from+u1+u2 is valid) OR (from+u2 is valid AND from+u2+u1 is valid)
        
        integer dest1 = fromPoint + (u1 * direction);
        integer dest2 = fromPoint + (u2 * direction);
        integer destFinal = fromPoint + ((u1 + u2) * direction);
        
        integer path1Valid = FALSE; // Path via u1
        integer path2Valid = FALSE; // Path via u2
        
        // Check Path 1: from -> dest1 -> destFinal
        if (dest1 >= 0 && dest1 < BOARD_SIZE && !isPointBlocked(dest1, color)) {
            // Intermediate point valid, check final
            if (destFinal < 0 || destFinal >= BOARD_SIZE) {
                if (bearingOff && isValidBearOff(dest1, u2, color)) {
                    if (llListFindList(moves, [BEAR_OFF]) == -1) moves += BEAR_OFF;
                }
            } else {
                if (!isPointBlocked(destFinal, color)) {
                    if (llListFindList(moves, [destFinal]) == -1) moves += destFinal;
                }
            }
        }
        
        // Check Path 2: from -> dest2 -> destFinal
        if (dest2 >= 0 && dest2 < BOARD_SIZE && !isPointBlocked(dest2, color)) {
            // Intermediate point valid, check final
            if (destFinal < 0 || destFinal >= BOARD_SIZE) {
                if (bearingOff && isValidBearOff(dest2, u1, color)) {
                    if (llListFindList(moves, [BEAR_OFF]) == -1) moves += BEAR_OFF;
                }
            } else {
                if (!isPointBlocked(destFinal, color)) {
                    if (llListFindList(moves, [destFinal]) == -1) moves += destFinal;
                }
            }
        }
    }
    
    return moves;
}

string BearOffStone(integer from_point, integer color) {
    string fromPointContents = llList2String(BoardList, from_point);
    list fromPieces = llParseString2List(fromPointContents, [","], []);
    string pieceToRemove = "";
    list newFromPieces = [];
    
    integer i;
    for (i = 0; i < llGetListLength(fromPieces); i++) {
        string piece = llList2String(fromPieces, i);
        string pieceColor = llGetSubString(piece, 0, 0);
        
        if (pieceToRemove == "" && 
            ((color == 0 && pieceColor == "w") || (color == 1 && pieceColor == "b"))) {
            pieceToRemove = piece;
        } else {
            newFromPieces += piece;
        }
    }
    
    if (pieceToRemove == "") return "";
    
    string newFromContents = llDumpList2String(newFromPieces, ",");
    if (DEBUG_MODE) llOwnerSay("DEBUG CORE: BearOffStone " + (string)from_point + " Content: '" + fromPointContents + "' -> '" + newFromContents + "' Removing: " + pieceToRemove);
    BoardList = llListReplaceList(BoardList, [newFromContents], from_point, from_point);
    
    if (color == 0) {
        WhiteBorneOff += pieceToRemove;
    } else {
        BlackBorneOff += pieceToRemove;
    }
    
    return pieceToRemove;
}

integer isGameOver() {
    if (llGetListLength(WhiteBorneOff) >= 15) return TRUE;
    if (llGetListLength(BlackBorneOff) >= 15) return TRUE;
    return FALSE;
}

init_board() {
    BoardList = ["","","","","","","","","","","","","","","","","","","","","","",""];
    
    // White pieces
    AddStone("w1", 0, 1); AddStone("w2", 0, 1);
    AddStone("w3", 0, 12); AddStone("w4", 0, 12); AddStone("w5", 0, 12); 
    AddStone("w6", 0, 12); AddStone("w7", 0, 12);
    AddStone("w8", 0, 17); AddStone("w9", 0, 17); AddStone("w10", 0, 17);
    AddStone("w11", 0, 19); AddStone("w12", 0, 19); AddStone("w13", 0, 19); 
    AddStone("w14", 0, 19); AddStone("w15", 0, 19);
    
    // Black pieces
    AddStone("b1", 1, 1); AddStone("b2", 1, 1);
    AddStone("b3", 1, 12); AddStone("b4", 1, 12); AddStone("b5", 1, 12); 
    AddStone("b6", 1, 12); AddStone("b7", 1, 12);
    AddStone("b8", 1, 17); AddStone("b9", 1, 17); AddStone("b10", 1, 17);
    AddStone("b11", 1, 19); AddStone("b12", 1, 19); AddStone("b13", 1, 19); 
    AddStone("b14", 1, 19); AddStone("b15", 1, 19);

    llMessageLinked(LINK_SET, 0, "BOARD_STATE|" + llDumpList2String(BoardList, "|"), NULL_KEY);
    sendBarStateToRender();   
}

string MoveStoneFromBar(integer to_point, integer color) {
    string pieceToMove = "";
    
    if (color == 0) {
        if (llGetListLength(WhiteBarList) == 0) return "";
        pieceToMove = llList2String(WhiteBarList, 0);
        WhiteBarList = llDeleteSubList(WhiteBarList, 0, 0);
    } else {
        if (llGetListLength(BlackBarList) == 0) return "";
        pieceToMove = llList2String(BlackBarList, 0);
        BlackBarList = llDeleteSubList(BlackBarList, 0, 0);
    }
    
    if (pieceToMove == "") return "";
    
    string toPointContents = llList2String(BoardList, to_point);
    list toPieces = llParseString2List(toPointContents, [","], []);
    
    integer opponentCount = 0;
    string opponentPiece = "";
    integer i;
    for (i = 0; i < llGetListLength(toPieces); i++) {
        string piece = llList2String(toPieces, i);
        string pieceColor = llGetSubString(piece, 0, 0);
        if ((color == 0 && pieceColor == "b") || (color == 1 && pieceColor == "w")) {
            opponentCount++;
            opponentPiece = piece;
        }
    }
    
    if (opponentCount >= 2) {
        if (color == 0) WhiteBarList += [pieceToMove];
        else BlackBarList += [pieceToMove];
        return "";
    }
    
    if (opponentCount == 1) {
        list newToPieces = [];
        for (i = 0; i < llGetListLength(toPieces); i++) {
            string piece = llList2String(toPieces, i);
            if (piece != opponentPiece) newToPieces += piece;
        }
        toPieces = newToPieces;
        
        if (llGetSubString(opponentPiece, 0, 0) == "w") WhiteBarList += [opponentPiece];
        else BlackBarList += [opponentPiece];
        
        llMessageLinked(LINK_SET, 0, "HIT_PIECE|" + opponentPiece + "|" + (string)to_point, NULL_KEY);
    }
    
    toPieces += [pieceToMove];
    string newToContents = llDumpList2String(toPieces, ",");
    BoardList = llListReplaceList(BoardList, [newToContents], to_point, to_point);
    
    return pieceToMove;
}

AddStone(string name, integer color, integer position) {
    integer internalPosition = pointToInternal(position, color);
    string point = llList2String(BoardList, internalPosition);
    if(llStringLength(point) > 0) point += ",";
    point += name;
    BoardList = llListReplaceList(BoardList, [point], internalPosition, internalPosition);
}

processMove(integer from_point, integer to_point, integer die_value, integer movesUsed) {
    if (DEBUG_MODE) llOwnerSay("CORE: processMove - " + turn + " from:" + (string)from_point + " to:" + (string)to_point + " die:" + (string)die_value + " movesUsed:" + (string)movesUsed);
    
    integer color;
    if (turn == "white") color = 0;
    else color = 1;
    
    if (color == 0 && llGetListLength(WhiteBarList) > 0 && from_point != FROM_BAR) {
        llMessageLinked(LINK_SET, 0, "INVALID_MOVE|" + turn + "|12", NULL_KEY);
        return;
    }
    if (color == 1 && llGetListLength(BlackBarList) > 0 && from_point != FROM_BAR) {
        llMessageLinked(LINK_SET, 0, "INVALID_MOVE|" + turn + "|12", NULL_KEY);
        return;
    }
    
    string movedPiece = "";
    
    if (from_point == FROM_BAR) {
        if (!isValidBarMove(to_point, color)) {
            llMessageLinked(LINK_SET, 0, "INVALID_MOVE|" + turn + "|11", NULL_KEY);
            return;
        }
        movedPiece = MoveStoneFromBar(to_point, color);
    } else if (to_point == BEAR_OFF) {
        if (DEBUG_MODE) llOwnerSay("CORE: Validating bear-off from:" + (string)from_point + " die:" + (string)die_value);
        if (!isValidBearOff(from_point, die_value, color)) {
            if (DEBUG_MODE) llOwnerSay("CORE: Bear-off REJECTED - Invalid");
            llMessageLinked(LINK_SET, 0, "INVALID_MOVE|" + turn + "|10", NULL_KEY);
            return;
        }
        if (DEBUG_MODE) llOwnerSay("CORE: Bear-off ACCEPTED");
        movedPiece = BearOffStone(from_point, color);
    } else {
        movedPiece = MoveStone(from_point, to_point, color);
    }
    
    if (movedPiece == "") {
        llMessageLinked(LINK_SET, 0, "INVALID_MOVE|" + turn + "|9", NULL_KEY);
        return;
    }
    
    // STEP 1: Send move notification first (no positioning)
    if (to_point == BEAR_OFF) {
        llMessageLinked(LINK_SET, 0, "BEAR_OFF_PIECE|" + movedPiece + "|" + (string)from_point, NULL_KEY);
    } else if (from_point == FROM_BAR) {
        llMessageLinked(LINK_SET, 0, "MOVE_PIECE|" + movedPiece + "|" + (string)FROM_BAR + "|" + (string)to_point, NULL_KEY);
    } else {
        llMessageLinked(LINK_SET, 0, "MOVE_PIECE|" + movedPiece + "|" + (string)from_point + "|" + (string)to_point, NULL_KEY);
    }
    
    // STEP 2: Wait for any animations
    llSleep(1.0);
    
    // STEP 3: Send FINAL board state (only this positions pieces)
    llMessageLinked(LINK_SET, 0, "BOARD_STATE|" + llDumpList2String(BoardList, "|"), NULL_KEY);
    sendBarStateToRender();
    llSleep(2);

    // Win check - IMMEDIATE
    if (isGameOver()) {
        gCurrentState = STATE_GAME_OVER;
        string winner = "white";
        if (llGetListLength(BlackBorneOff) >= 15) winner = "black";
        llMessageLinked(LINK_SET, 0, "GAME_OVER|" + winner, NULL_KEY);
        return;
    }
    
    if (!isDoubles) {
        if (movesUsed == 2) {
            u1 = 0;
            u2 = 0;
        } else if (die_value == u1) u1 = 0;
        else if (die_value == u2) u2 = 0;
    } else movesLeft = movesLeft - movesUsed;

    // Notify UI of remaining dice
    if (!isDoubles && (u1 > 0 || u2 > 0)) {
        llMessageLinked(LINK_SET, 0, "DICE_REMAINING|" + turn + "|" + (string)u1 + "|" + (string)u2, NULL_KEY);
    } else if (isDoubles && movesLeft > 0) {
        llMessageLinked(LINK_SET, 0, "DICE_REMAINING|" + turn + "|" + (string)u1 + "|" + (string)u2 + "|" + (string)movesLeft, NULL_KEY);
    }


    integer turnOver = FALSE;
    
    if (isDoubles) {
        if (movesLeft <= 0) turnOver = TRUE;
        else turnOver = FALSE;
    } else {
        if (u1 == 0 && u2 == 0) turnOver = TRUE;
        else turnOver = FALSE;
    }
    
    // Check if player has any valid moves remaining (even if dice remain)
    if (!turnOver) {
        if (!checkAnyValidMoves(color)) {
            if (DEBUG_MODE) llOwnerSay("CORE: No valid moves remaining mid-turn - forcing turn end");
            llMessageLinked(LINK_SET, 0, "GAME_MESSAGE|No more valid moves for " + turn + ". Turn ending.", NULL_KEY);
            turnOver = TRUE;
        }
    }
    
    if (turnOver) {
        if (isGameOver()) {
            gCurrentState = STATE_GAME_OVER;
            string winner = "white";
            if (llGetListLength(BlackBorneOff) >= 15) winner = "black";
            llMessageLinked(LINK_SET, 0, "GAME_OVER|" + winner, NULL_KEY);
        } else {
            changeTurn();
        } 
    } else {
        integer isAIPlayer = FALSE;
        if (turn == "white" && CORE_WHITE_AI) isAIPlayer = TRUE;
        else if (turn == "black" && CORE_BLACK_AI) isAIPlayer = TRUE;
        
        if (isAIPlayer) {
            llSleep(1.0);
            llMessageLinked(LINK_SET, 0, "TRIGGER_AI_TURN|" + turn + "|" + (string)u1 + "|" + (string)u2 + "|" + (string)isDoubles + "|" + (string)movesLeft, NULL_KEY);
        }
    }
}

triggerAIIfNeeded() {
    integer isAIPlayer = FALSE;
    if (turn == "white" && CORE_WHITE_AI) isAIPlayer = TRUE;
    else if (turn == "black" && CORE_BLACK_AI) isAIPlayer = TRUE;
    
    if (isAIPlayer) {
        integer shouldRollNewDice = (u1 == 0 && u2 == 0);
        integer die1;
        integer die2;
        
        if (shouldRollNewDice) {
            die1 = 1 + (integer)llFrand(6);
            die2 = 1 + (integer)llFrand(6);
            u1 = die1;
            u2 = die2;
            
            if (die1 == die2) {
                isDoubles = TRUE;
                movesLeft = 4;
            } else {
                isDoubles = FALSE;
                movesLeft = 0;
            }
            
            llMessageLinked(LINK_SET, 0, "DICE_ROLL|" + turn + "|" + (string)die1 + "|" + (string)die2, NULL_KEY);
        } else {
            die1 = u1;
            die2 = u2;
            
            if (die1 == die2) {
                isDoubles = TRUE;
                movesLeft = 4;
            } else {
                isDoubles = FALSE;
                movesLeft = 0;
            }
        }
        
        llMessageLinked(LINK_SET, 0, "DICE_RESULT|" + turn + "|" + (string)u1 + "|" + (string)u2, NULL_KEY);
        llSleep(3.0);
        llMessageLinked(LINK_SET, 0, "TRIGGER_AI_TURN|" + turn + "|" + (string)u1 + "|" + (string)u2 + "|" + (string)isDoubles + "|" + (string)movesLeft, NULL_KEY);
    }
}

changeTurn() {
    if (turn == "white") turn = "black";
    else turn = "white";
    
    u1 = 0;
    u2 = 0;
    whiteOnce = FALSE;
    blackOnce = FALSE;
    isDoubles = FALSE;
    movesLeft = 0;

    llMessageLinked(LINK_SET, 0, "TURN_CHANGE|" + turn, NULL_KEY);
    llSleep(2.0);
    triggerAIIfNeeded();
}

integer checkAnyValidMoves(integer color) {
    // Check pieces on bar first
    if (color == 0 && llGetListLength(WhiteBarList) > 0) {
        if (llGetListLength(calculateValidMoves(FROM_BAR, color)) > 0) return TRUE;
        return FALSE; // Can only move from bar
    }
    if (color == 1 && llGetListLength(BlackBarList) > 0) {
        if (llGetListLength(calculateValidMoves(FROM_BAR, color)) > 0) return TRUE;
        return FALSE; // Can only move from bar
    }
    
    // Check all board points
    integer i;
    string playerColor = "w";
    if (color == 1) playerColor = "b";
    
    for(i = 0; i < 24; i++) {
        if (hasPlayerPieceAtPoint(i, playerColor)) {
            if (llGetListLength(calculateValidMoves(i, color)) > 0) return TRUE;
        }
    }
    
    return FALSE;
}

handleFirstRollPhase(string player, integer die1, integer die2) {
    if (player == "white") {
        whiteDie = die1;
        whiteDie1 = die1;
        whiteDie2 = die2;
        whiteOnce = TRUE;
    } else {
        blackDie = die1;
        blackDie1 = die1;
        blackDie2 = die2;
        blackOnce = TRUE;
    }
    
    if (!whiteOnce || !blackOnce) return;
    
    whiteOnce = FALSE;
    blackOnce = FALSE;
    
    if (whiteDie == blackDie) {
        llMessageLinked(LINK_SET, 0, "REROLL_FIRST", NULL_KEY);
        whiteOnce = FALSE;
        blackOnce = FALSE;
        
        if (white == NULL_KEY && black == NULL_KEY) {
            llSleep(2.0);
            whiteDie1 = 1 + (integer)llFrand(6);
            whiteDie2 = 1 + (integer)llFrand(6);
            blackDie1 = 1 + (integer)llFrand(6);
            blackDie2 = 1 + (integer)llFrand(6);
            
            llMessageLinked(LINK_SET, 0, "DICE_ROLL|white|" + (string)whiteDie1 + "|" + (string)whiteDie2, NULL_KEY);
            llSleep(1.0);
            llMessageLinked(LINK_SET, 0, "DICE_ROLL|black|" + (string)blackDie1 + "|" + (string)blackDie2, NULL_KEY);
        }
        return;
    }
    
    if (whiteDie > blackDie) {
        turn = "white";
        u1 = whiteDie1;
        u2 = blackDie1; // Winner uses their die + loser's die
    } else {
        turn = "black";
        u1 = blackDie1;
        u2 = whiteDie1; // Winner uses their die + loser's die
    }
    
    llSleep(3.0); // Allow time to see the second roll
    
    gCurrentState = STATE_MAIN_GAME;
    llMessageLinked(LINK_SET, 0, "FIRST_TURN|" + turn + "|" + (string)u1 + "|" + (string)u2, NULL_KEY);
}

default {
    state_entry() {
        init_board();
        gCurrentState = STATE_RESET;
        llMessageLinked(LINK_SET, 0, "GAME_READY", NULL_KEY);
        llSleep(3);
        llMessageLinked(LINK_SET, 0, "RESET_GAME", NULL_KEY);
    }
    
    link_message(integer sender, integer num, string str, key id) {
        list params = llParseStringKeepNulls(str, ["|"], []);
        string command = llList2String(params, 0);
        
        if (command == "CONTROL_STATE") {
            string stateType = llList2String(params, 1);
            string stateValue = llList2String(params, 2);
            
            if (stateType == "WHITE_AI") CORE_WHITE_AI = (integer)stateValue;
            else if (stateType == "BLACK_AI") CORE_BLACK_AI = (integer)stateValue;
        }
        else if (command == "START_FIRST_ROLL") {
            if (gCurrentState == STATE_RESET && whitePresent && blackPresent) {
                gCurrentState = STATE_FIRST_ROLL;
                llMessageLinked(LINK_SET, 0, "START_FIRST_ROLL", NULL_KEY);
                
                if (white == NULL_KEY && black == NULL_KEY) {
                    llSleep(2.0);
                    whiteDie1 = 1 + (integer)llFrand(6);
                    whiteDie2 = 0; // First roll is one die only
                    blackDie1 = 1 + (integer)llFrand(6);
                    blackDie2 = 0; // First roll is one die only
                    
                    llMessageLinked(LINK_SET, 0, "DICE_ROLL|white|" + (string)whiteDie1 + "|" + (string)whiteDie2, NULL_KEY);
                    llSleep(1.0);
                    llMessageLinked(LINK_SET, 0, "DICE_ROLL|black|" + (string)blackDie1 + "|" + (string)blackDie2, NULL_KEY);
                }
            }
        }
        else if (command == "PLAYER_DICE_ROLL" || command == "DICE_ROLL") {
            string player = llList2String(params, 1);
            integer die1 = llList2Integer(params, 2);
            integer die2 = llList2Integer(params, 3);
            
            if (gCurrentState == STATE_RESET || gCurrentState == STATE_FIRST_ROLL) {
                if (gCurrentState == STATE_RESET) gCurrentState = STATE_FIRST_ROLL;
                handleFirstRollPhase(player, die1, die2);
                return; // Exit to prevent processing in STATE_MAIN_GAME logic below
            }
            else if (gCurrentState == STATE_MAIN_GAME && player == turn) {
                u1 = die1;
                u2 = die2;
                isDoubles = (die1 == die2);
                if(isDoubles) movesLeft = 4;
                else movesLeft = 2;
                llMessageLinked(LINK_SET, 0, "DICE_RESULT|" + turn + "|" + (string)u1 + "|" + (string)u2, NULL_KEY);
                
                // Check for Human No-Moves Scenario
                integer isAIPlayer = FALSE;
                if (turn == "white" && CORE_WHITE_AI) isAIPlayer = TRUE;
                else if (turn == "black" && CORE_BLACK_AI) isAIPlayer = TRUE;
                
                if (!isAIPlayer) {
                    integer color = 0;
                    if (turn == "black") color = 1;
                    
                    if (!checkAnyValidMoves(color)) {
                        llMessageLinked(LINK_SET, 0, "GAME_MESSAGE|No valid moves for " + turn + ". Passing turn.", NULL_KEY);
                        llSleep(2.0);
                        changeTurn();
                    }
                }
            }
        }
        else if (command == "PLAYER_JOIN") {
            string player = llList2String(params, 1);
            key avatar = (key)llList2String(params, 2);
            
            if (player == "white") {
                whitePresent = TRUE;
                white = avatar;
            } else if (player == "black") {
                blackPresent = TRUE;
                black = avatar;
            }
            
            if (whitePresent && blackPresent && gCurrentState == STATE_RESET) {
                gCurrentState = STATE_FIRST_ROLL;
                llMessageLinked(LINK_SET, 0, "START_FIRST_ROLL", NULL_KEY);
                
                if (white == NULL_KEY && black == NULL_KEY) {
                    llSleep(2.0);
                    whiteDie1 = 1 + (integer)llFrand(6);
                    whiteDie2 = 0; // First roll is one die only
                    blackDie1 = 1 + (integer)llFrand(6);
                    blackDie2 = 0; // First roll is one die only
                    
                    llMessageLinked(LINK_SET, 0, "DICE_ROLL|white|" + (string)whiteDie1 + "|" + (string)whiteDie2, NULL_KEY);
                    llSleep(1.0);
                    llMessageLinked(LINK_SET, 0, "DICE_ROLL|black|" + (string)blackDie1 + "|" + (string)blackDie2, NULL_KEY);
                }
            }
        }
        else if (command == "FIRST_TURN") {
            if ((turn == "white" && CORE_WHITE_AI) || (turn == "black" && CORE_BLACK_AI)) {
                llSleep(2.0);
                llMessageLinked(LINK_SET, 0, "TRIGGER_AI_TURN|" + turn + "|" + (string)u1 + "|" + (string)u2 + "|0|0", NULL_KEY);
            } else {
                triggerAIIfNeeded();
            }
        }
        else if (command == "PLAYER_MOVE") {
            if (gCurrentState != STATE_MAIN_GAME) return;
            string player = llList2String(params, 1);
            if (player != turn) return;
            
            integer from_point = llList2Integer(params, 2);
            integer to_point = llList2Integer(params, 3);
            integer die_value = llList2Integer(params, 4);
            integer movesUsed = llList2Integer(params, 5);
            string moveID = llList2String(params, 6);
            
            // DEDUPLICATION: Check if we've seen this move ID
            if (llListFindList(gRecentMoveIDs, [moveID]) != -1) {
                if (DEBUG_MODE) llOwnerSay("CORE: Ignoring duplicate move ID: " + moveID);
                return;
            }
            
            // Track this move ID
            gRecentMoveIDs = [moveID] + gRecentMoveIDs;
            if (llGetListLength(gRecentMoveIDs) > MAX_MOVE_HISTORY) {
                gRecentMoveIDs = llList2List(gRecentMoveIDs, 0, MAX_MOVE_HISTORY - 1);
            }
            
            if (DEBUG_MODE) llOwnerSay("CORE: Processing Move ID: " + moveID);
            
            processMove(from_point, to_point, die_value, movesUsed);
            
            // ACKNOWLEDGE the move to AI
            llMessageLinked(LINK_SET, 0, "MOVE_ACKNOWLEDGED|" + moveID, NULL_KEY);
        }
        else if (command == "RESET_GAME") {
            gCurrentState = STATE_RESET;
            turn = "";
            whiteOnce = FALSE;
            blackOnce = FALSE;
            u1 = 0;
            u2 = 0;
            isDoubles = FALSE;
            movesLeft = 0;
            white = NULL_KEY;
            black = NULL_KEY;
            WhiteBarList = [];
            BlackBarList = [];
            WhiteBorneOff = [];
            BlackBorneOff = [];
            
            init_board();
            llMessageLinked(LINK_SET, 0, "GAME_RESET", NULL_KEY);
        }
        else if (command == "REQUEST_BOARD_STATE") {
            string message = "FRESH_BOARD_STATE";
            integer i;
            for (i = 0; i < 24; i++) message += "|" + llList2String(BoardList, i);
            message += "|" + llDumpList2String(WhiteBarList, ",");
            message += "|" + llDumpList2String(BlackBarList, ",");
            message += "|" + llDumpList2String(WhiteBorneOff, ",");
            message += "|" + llDumpList2String(BlackBorneOff, ",");
            message += "|CORE_SIG_" + (string)llGetUnixTime();
            llMessageLinked(LINK_SET, 0, message, NULL_KEY);
        }
        else if (command == "TRIGGER_AI_NOW") {
            if (DEBUG_MODE) llOwnerSay("CORE: Received manual AI trigger request");
            triggerAIIfNeeded();
        }

        else if (command == "GET_PIECE_POSITION") {
            string pieceName = llList2String(params, 1);
            string playerKey = llList2String(params, 2);
            
            integer found = FALSE;
            integer position = -1;
            
            // Check Bar first
            if (llListFindList(WhiteBarList, [pieceName]) != -1) {
                position = FROM_BAR;
                found = TRUE;
            } else if (llListFindList(BlackBarList, [pieceName]) != -1) {
                position = FROM_BAR;
                found = TRUE;
            }
            
            // Check Board
            if (!found) {
                integer i;
                for(i = 0; i < 24; i++) {
                    string point = llList2String(BoardList, i);
                    list pieces = llParseString2List(point, [","], []);
                    if (llListFindList(pieces, [pieceName]) != -1) {
                        position = i;
                        found = TRUE;
                        i = 24; // Break
                    }
                }
            }
            
            llMessageLinked(LINK_SET, 0, "PIECE_POSITION|" + pieceName + "|" + (string)position + "|" + playerKey, NULL_KEY);
        }
        else if (command == "REQUEST_VALID_MOVES") {
            integer point = llList2Integer(params, 1);
            string player = llList2String(params, 2);
            
            integer color = 0;
            if (player == "black") color = 1;
            
            // Check if player has pieces on bar
            if (color == 0 && llGetListLength(WhiteBarList) > 0 && point != FROM_BAR) {
                // Must move from bar first
                llMessageLinked(LINK_SET, 0, "VALID_MOVES|" + (string)point + "|BAR_ONLY", NULL_KEY);
                return;
            }
            if (color == 1 && llGetListLength(BlackBarList) > 0 && point != FROM_BAR) {
                llMessageLinked(LINK_SET, 0, "VALID_MOVES|" + (string)point + "|BAR_ONLY", NULL_KEY);
                return;
            }
            
            list moves = calculateValidMoves(point, color);
            string moveStr = llDumpList2String(moves, ",");
            llMessageLinked(LINK_SET, 0, "VALID_MOVES|" + (string)point + "|" + moveStr, NULL_KEY);
        }
        else if (command == "AI_NO_MOVES") {
            string player = llList2String(params, 1);
            if (player == turn) {
                if (isGameOver()) {
                    gCurrentState = STATE_GAME_OVER;
                    string winner = "white";
                    if (llGetListLength(BlackBorneOff) >= 15) winner = "black";
                    llMessageLinked(LINK_SET, 0, "GAME_OVER|" + winner, NULL_KEY);
                    return;
                }
                
                whiteOnce = FALSE;
                blackOnce = FALSE;
                isDoubles = FALSE;
                movesLeft = 0;
                u1 = 0;
                u2 = 0;

                changeTurn();
            }
        }
    }
}



