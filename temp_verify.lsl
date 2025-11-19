// BACKGAMMON CORE - Clean game logic
integer DEBUG_MODE = TRUE;

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
integer whiteOnce = FALSE;
integer blackOnce = FALSE;
integer u1 = 0;
integer u2 = 0;
integer isDoubles = FALSE;
integer movesLeft = 0;
integer whiteDie1 = 0;
integer whiteDie2 = 0;
integer blackDie1 = 0;
integer blackDie2 = 0;
integer whiteDie = 0;
integer blackDie = 0;

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

// CONTROL STATE from Menu
integer CORE_WHITE_AI = FALSE;
integer CORE_BLACK_AI = FALSE;
integer CORE_SIMULATING = FALSE;
integer CORE_AI_LEVEL = 1;
integer CORE_GAME_PAUSED = FALSE;

// ===== BEAR OFF HELPER FUNCTIONS =====
integer getRequiredBearOffDistance(integer point, integer color) {
    if (color == 0) return 24 - point;  // White: 18→6, 19→5, etc.
    return point + 1;                   // Black: 5→6, 4→5, etc.
}

integer hasPlayerPieceAtPoint(integer point, string playerColor) {
    string pointContents = llList2String(BoardList, point);
    return (pointContents != "" && llSubStringIndex(pointContents, playerColor) != -1);
}

validateBoardState() {
    if (!DEBUG_MODE) return;
    
    integer errors = 0;
    integer i;
    
    for (i = 0; i < BOARD_SIZE; i++) {
        string pointContents = llList2String(BoardList, i);
        if (pointContents != "") {
            // More efficient duplicate checking
            list pieces = llParseString2List(pointContents, [","], []);
            integer pieceCount = llGetListLength(pieces);
            integer j;
            integer k;
            
            for (j = 0; j < pieceCount; j++) {
                string piece1 = llList2String(pieces, j);
                for (k = j + 1; k < pieceCount; k++) {
                    string piece2 = llList2String(pieces, k);
                    if (piece1 == piece2) {
                        errors++;
                        llOwnerSay("DEBUG CORE: DUPLICATE " + piece1 + " at point " + (string)i);
                        // Break early to save memory
                        k = pieceCount;
                        j = pieceCount;
                    }
                }
            }
        }
    }
    if (errors > 0) llOwnerSay("DEBUG CORE: VALIDATION FAILED - " + (string)errors + " duplicate pieces found!");

}

sendBarStateToRender() {
    string barStateMessage = "BAR_STATE|" + 
        llDumpList2String(WhiteBarList, "|") + "|" + 
        llDumpList2String(BlackBarList, "|");
    
    llMessageLinked(LINK_SET, 0, barStateMessage, NULL_KEY);
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG CORE: Sent BAR_STATE - White: " + llDumpList2String(WhiteBarList, ",") + 
                  " Black: " + llDumpList2String(BlackBarList, ","));
    }
}
// Core functions

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

string MoveStone(integer from_point, integer to_point, integer color) {
    string fromPointContents = llList2String(BoardList, from_point);
    string toPointContents = llList2String(BoardList, to_point);
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG MoveStone: from " + (string)from_point + "='" + fromPointContents + 
                  "' to " + (string)to_point + "='" + toPointContents + "' color=" + (string)color);
    }
    
    // Extract first piece of correct color using string operations
    string pieceToMove = "";
    string playerColor;
    if (color == 0) playerColor = "w";
    else playerColor = "b";
    
    // Extract the full piece name by parsing the list properly
    list fromPieces = llParseString2List(fromPointContents, [","], []);
    integer i = 0;
    integer found = FALSE;
    while (i < llGetListLength(fromPieces) && !found) {
        string piece = llList2String(fromPieces, i);
        if (llGetSubString(piece, 0, 0) == playerColor) {
            pieceToMove = piece;
            found = TRUE;
        }
        i = i + 1;
    }
    
    if (pieceToMove == "") {
        if (DEBUG_MODE) llOwnerSay("DEBUG MoveStone: No " + playerColor + " piece found to move!");
        return "";
    }
    
    // Remove the moved piece from source
    integer pieceIndex = llListFindList(fromPieces, [pieceToMove]);
    if (pieceIndex != -1) {
        fromPieces = llDeleteSubList(fromPieces, pieceIndex, pieceIndex);
    }
    string newFromContents = llDumpList2String(fromPieces, ",");
    
    list toPieces = llParseString2List(toPointContents, [","], []);
    
    // Check for hits
    string opponentColor;
    if (color == 0) opponentColor = "b";
    else opponentColor = "w";
    
    integer opponentCount = 0;
    string opponentPiece = "";
    
    if (toPointContents != "") {
        // Count opponent pieces by checking each piece
        integer i = 0;
        while (i < llGetListLength(toPieces)) {
            string piece = llList2String(toPieces, i);
            if (llGetSubString(piece, 0, 0) == opponentColor) {
                opponentCount = opponentCount + 1;
                opponentPiece = piece;
            }
            i = i + 1;
        }
        
        if (DEBUG_MODE) {
            llOwnerSay("DEBUG MoveStone: opponentCount=" + (string)opponentCount);
        }
        
        // If there are 2 or more opponent pieces, move is invalid
        if (opponentCount >= 2) {
            if (DEBUG_MODE) llOwnerSay("DEBUG MoveStone: Move blocked - 2+ opponent pieces");
            return "";
        }
        
        // If there's exactly one opponent piece, hit it
        if (opponentCount == 1) {
            if (DEBUG_MODE) llOwnerSay("DEBUG MoveStone: Hitting opponent piece: " + opponentPiece);
            
            // Remove opponent piece from destination
            integer oppIndex = llListFindList(toPieces, [opponentPiece]);
            if (oppIndex != -1) {
                toPieces = llDeleteSubList(toPieces, oppIndex, oppIndex);
            }
            
            // Send opponent piece to bar
            if (opponentColor == "w") {
                WhiteBarList = WhiteBarList + [opponentPiece];
            } else {
                BlackBarList = BlackBarList + [opponentPiece];
            }
            
            llMessageLinked(LINK_SET, 0, "HIT_PIECE|" + opponentPiece + "|" + (string)to_point, NULL_KEY);
        }
    }
    
    // Add our piece to the destination
    toPieces = toPieces + [pieceToMove];  // FIXED: Use + instead of +=
    
    string newToContents = llDumpList2String(toPieces, ",");
    
    BoardList = llListReplaceList(BoardList, [newFromContents], from_point, from_point);
    BoardList = llListReplaceList(BoardList, [newToContents], to_point, to_point);
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG MoveStone: Result - from='" + newFromContents + "' to='" + newToContents + "'");
    }
    
    return pieceToMove;
}

integer isValidBarMove(integer to_point, integer color) {
    string targetPoint = llList2String(BoardList, to_point);
    string opponentColor;
    
    if (color == 0) {
        opponentColor = "b";
    } else {
        opponentColor = "w";
    }
    
    // Count opponent pieces at target
    integer opponentCount = 0;
    if (targetPoint != "") {
        list pieces = llParseString2List(targetPoint, [","], []);
        integer i;
        for (i = 0; i < llGetListLength(pieces); i++) {
            string piece = llList2String(pieces, i);
            if (llGetSubString(piece, 0, 0) == opponentColor) {
                opponentCount = opponentCount + 1;
            }
        }
    }
    
    // Can only move to point with 0 or 1 opponent pieces
    return (opponentCount < 2);
}

integer pointToInternal(integer point, integer color) {
    if (point < 0) return point;
    if (color == 0) return point - 1;
    return BOARD_SIZE - point;
}

integer isInHomeBoard(integer point, integer color) {
    if (color == 0) {
        return (point >= 0 && point <= 5);
    } else {
        return (point >= 18 && point <= 23);
    }
}

list getHomeBoardRange(string player) {
    if (player == "white") return [WHITE_HOME_START, WHITE_HOME_END];
    return [BLACK_HOME_START, BLACK_HOME_END];
}

string getPlayerColor(string player) {
    if (player == "white") return "w";
    return "b";
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

integer isPointInHomeBoard(integer point, integer color) {
    if (color == 0) { // White
        return (point >= WHITE_HOME_START && point <= WHITE_HOME_END);
    } else { // Black
        return (point <= BLACK_HOME_START && point >= BLACK_HOME_END);
    }
}


integer hasPiecesInRange(integer start, integer end, string playerColor) {
    // Ensure we're iterating in the right direction
    if (start <= end) {
        integer i;
        for (i = start; i <= end; i++) {
            string point = llList2String(BoardList, i);
            if (point != "" && llSubStringIndex(point, playerColor) != -1) {
                return TRUE;
            }
        }
    } else {
        integer i;
        for (i = start; i >= end; i--) {
            string point = llList2String(BoardList, i);
            if (point != "" && llSubStringIndex(point, playerColor) != -1) {
                return TRUE;
            }
        }
    }
    return FALSE;
}

integer isValidBearOff(integer from_point, integer die_value, integer color) {
    if (!allPiecesInHomeBoard(color) || !isPointInHomeBoard(from_point, color)) return FALSE;
    
    integer requiredDistance = getRequiredBearOffDistance(from_point, color);
    string playerColor = "b";
    if(color == 0) playerColor = "w";
    
    // Check for exact matches
    integer i;
    if (color == 0) {
        for (i = WHITE_HOME_START; i <= WHITE_HOME_END; i++) {
            if (hasPlayerPieceAtPoint(i, playerColor) && die_value == getRequiredBearOffDistance(i, color)) {
                if (die_value != requiredDistance) return FALSE; // Exact match exists elsewhere
                i = WHITE_HOME_END + 1; // break
            }
        }
    } else {
        for (i = BLACK_HOME_START; i >= BLACK_HOME_END; i--) {
            if (hasPlayerPieceAtPoint(i, playerColor) && die_value == getRequiredBearOffDistance(i, color)) {
                if (die_value != requiredDistance) return FALSE; // Exact match exists elsewhere
                i = BLACK_HOME_END - 1; // break
            }
        }
    }
    
    if (die_value >= requiredDistance) return TRUE;
    
    // Check undershoot
    if (color == 0) {
        for (i = WHITE_HOME_START; i < from_point; i++) {
            if (hasPlayerPieceAtPoint(i, playerColor)) return FALSE;
        }
    } else {
        for (i = from_point + 1; i <= BLACK_HOME_START; i++) {
            if (hasPlayerPieceAtPoint(i, playerColor)) return FALSE;
        }
    }
    
    return TRUE;
}

// Update the BearOffStone function to add more validation
string BearOffStone(integer from_point, integer color) {
    string fromPointContents = llList2String(BoardList, from_point);
    list fromPieces = llParseString2List(fromPointContents, [","], []);
    string pieceToRemove = "";
    list newFromPieces = [];
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG BearOffStone: from_point=" + (string)from_point + 
                  ", contents='" + fromPointContents + 
                  "', color=" + (string)color);
    }
    
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
    
    if (pieceToRemove == "") {
        if (DEBUG_MODE) llOwnerSay("DEBUG BearOffStone: No piece found to remove!");
        return "";
    }
    
    string newFromContents = llDumpList2String(newFromPieces, ",");
    BoardList = llListReplaceList(BoardList, [newFromContents], from_point, from_point);
    
    if (color == 0) {
        WhiteBorneOff += pieceToRemove;
        if (DEBUG_MODE) llOwnerSay("DEBUG BearOffStone: Added " + pieceToRemove + " to WhiteBorneOff, count now: " + (string)llGetListLength(WhiteBorneOff));
    } else {
        BlackBorneOff += pieceToRemove;
        if (DEBUG_MODE) llOwnerSay("DEBUG BearOffStone: Added " + pieceToRemove + " to BlackBorneOff, count now: " + (string)llGetListLength(BlackBorneOff));
    }
    
    return pieceToRemove;
}

integer isGameOver() {
    integer whiteBorneOffCount = llGetListLength(WhiteBorneOff);
    integer blackBorneOffCount = llGetListLength(BlackBorneOff);
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG isGameOver: White borne off: " + (string)whiteBorneOffCount + 
                  ", Black borne off: " + (string)blackBorneOffCount);
    }
    
    if (whiteBorneOffCount >= 15) {
        if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Game over - White wins with " + (string)whiteBorneOffCount + " borne off");
        return TRUE;
    }
    if (blackBorneOffCount >= 15) {
        if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Game over - Black wins with " + (string)blackBorneOffCount + " borne off");
        return TRUE;
    }
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

    if (DEBUG_MODE) {
        llOwnerSay("DEBUG CORE: Initialized board with " + (string)llGetListLength(BoardList) + " points");
        integer i;
        for (i = 0; i < llGetListLength(BoardList); i++) {
            llOwnerSay("Core Point " + (string)i + ": '" + llList2String(BoardList, i) + "'");
        }
    }
    
    llMessageLinked(LINK_SET, 0, "BOARD_STATE|" + llDumpList2String(BoardList, "|"), NULL_KEY);
    sendBarStateToRender();   
}

string MoveStoneFromBar(integer to_point, integer color) {
    string pieceToMove = "";
    
    // Get piece from bar
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
    
    // Handle target point
    string toPointContents = llList2String(BoardList, to_point);
    list toPieces = llParseString2List(toPointContents, [","], []);
    
    // Count opponent pieces at destination
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
    
    // If there are 2 or more opponent pieces, move is invalid
    if (opponentCount >= 2) {
        // Return piece to bar since move is invalid
        if (color == 0) {
            WhiteBarList += [pieceToMove];
        } else {
            BlackBarList += [pieceToMove];
        }
        return "";
    }
    
    // If there is one opponent piece, hit it
    if (opponentCount == 1) {
        // Remove the opponent piece from toPieces
        list newToPieces = [];
        for (i = 0; i < llGetListLength(toPieces); i++) {
            string piece = llList2String(toPieces, i);
            if (piece != opponentPiece) {
                newToPieces += piece;
            }
        }
        toPieces = newToPieces;
        
        // Send opponent piece to bar
        if (llGetSubString(opponentPiece, 0, 0) == "w") {
            WhiteBarList += [opponentPiece];
        } else {
            BlackBarList += [opponentPiece];
        }
        
        llMessageLinked(LINK_SET, 0, "HIT_PIECE|" + opponentPiece + "|" + (string)to_point, NULL_KEY);
    }
    
    // Add our piece to the point
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

integer countPiecesOnBoard(integer color) {
    string searchChar = "b";
    if(color == 0) searchChar = "w";
    integer count = 0;
    integer i;
    
    for (i = 0; i < BOARD_SIZE; i++) {
        string point = llList2String(BoardList, i);
        if (point != "") {
            // Count occurrences of the character directly without parsing full list
            integer pos = 0;
            while (pos < llStringLength(point)) {
                string char = llGetSubString(point, pos, pos);
                if (char == searchChar) {
                    count++;
                }
                pos++;
            }
        }
    }
    
    return count;
}

processMove(integer from_point, integer to_point, integer die_value, integer movesUsed) {
    //temporary for problem solving
    llOwnerSay("DEBUG CORE - remove me and countPiecesOnBoard: processMove START - Turn: " + turn + 
          " From: " + (string)from_point + " To: " + (string)to_point +
          " WhiteOnBoard: " + (string)countPiecesOnBoard(0) +
          " BlackOnBoard: " + (string)countPiecesOnBoard(1));
          
    integer color;
    if (turn == "white") color = 0;
    else color = 1;
    
    // ENFORCEMENT: If player has pieces on bar, they can only move from bar
    if (color == 0 && llGetListLength(WhiteBarList) > 0 && from_point != FROM_BAR) {
        if (DEBUG_MODE) llOwnerSay("DEBUG CORE: White has pieces on bar but tried to move from point " + (string)from_point);
        llMessageLinked(LINK_SET, 0, "INVALID_MOVE|" + turn + "|12", NULL_KEY);
        return;
    }
    if (color == 1 && llGetListLength(BlackBarList) > 0 && from_point != FROM_BAR) {
        if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Black has pieces on bar but tried to move from point " + (string)from_point);
        llMessageLinked(LINK_SET, 0, "INVALID_MOVE|" + turn + "|12", NULL_KEY);
        return;
    }
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG CORE: Processing move - from: " + (string)from_point + " to: " + (string)to_point + 
                  " die: " + (string)die_value + " color: " + (string)color +
                  " movesUsed: " + (string)movesUsed +
                  " initial movesLeft: " + (string)movesLeft);
    }
    
    string movedPiece = "";
    
    // Handle different move types
    if (from_point == FROM_BAR) {
        // Moving from the bar
        if (!isValidBarMove(to_point, color)) {
            llMessageLinked(LINK_SET, 0, "INVALID_MOVE|" + turn + "|11", NULL_KEY);
            return;
        }
        
        movedPiece = MoveStoneFromBar(to_point, color);
    } else if (to_point == BEAR_OFF) {
        // Bearing off
        if (!isValidBearOff(from_point, die_value, color)) {
            llMessageLinked(LINK_SET, 0, "INVALID_MOVE|" + turn + "|10", NULL_KEY);
            return;
        }
        
        movedPiece = BearOffStone(from_point, color);
    } else {
        // Normal move
        movedPiece = MoveStone(from_point, to_point, color);
    }
    
    if (movedPiece == "") {
        llMessageLinked(LINK_SET, 0, "INVALID_MOVE|" + turn + "|9", NULL_KEY);
        return;
    }
    
    // Send board updates
    llMessageLinked(LINK_SET, 0, "BOARD_STATE|" + llDumpList2String(BoardList, "|"), NULL_KEY);
    
    if (to_point == BEAR_OFF) {
        llMessageLinked(LINK_SET, 0, "BEAR_OFF_PIECE|" + movedPiece + "|" + (string)from_point, NULL_KEY);
    } else if (from_point == FROM_BAR) {
        llMessageLinked(LINK_SET, 0, "MOVE_PIECE|" + movedPiece + "|" + (string)FROM_BAR + "|" + (string)to_point, NULL_KEY);
    } else {
        llMessageLinked(LINK_SET, 0, "MOVE_PIECE|" + movedPiece + "|" + (string)from_point + "|" + (string)to_point, NULL_KEY);
    }
    
    sendBarStateToRender();
    llSleep(2);
    validateBoardState();

    // Check for immediate game over after bearing off
    if (isGameOver()) {
        gCurrentState = STATE_GAME_OVER;
        string winner = "white";
        if (llGetListLength(BlackBorneOff) >= 15) winner = "black";
        if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Game ended immediately - " + winner + " wins!");
        llMessageLinked(LINK_SET, 0, "GAME_OVER|" + winner, NULL_KEY);
        return; // Exit immediately - don't process turn logic
    }
    
    if (!isDoubles) {
        if (movesUsed == 2) {
            // Used both dice in combination (like 5+1=6)
            u1 = 0;
            u2 = 0;
            if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Cleared both dice for combination move");
        } else if (die_value == u1) {
            u1 = 0;
        }
        else if (die_value == u2) {
            u2 = 0;
        }
    } else {
        movesLeft = movesLeft - movesUsed;
    }

    if (DEBUG_MODE) {
        llOwnerSay("DEBUG CORE: After processing move:");
        llOwnerSay("DEBUG CORE: die_value: " + (string)die_value);
        llOwnerSay("DEBUG CORE: u1: " + (string)u1 + ", u2: " + (string)u2);
        llOwnerSay("DEBUG CORE: isDoubles: " + (string)isDoubles);
        llOwnerSay("DEBUG CORE: movesLeft: " + (string)movesLeft);
    }

    integer turnOver = FALSE;
    
    if (isDoubles) {
        if (movesLeft <= 0) {
            turnOver = TRUE;
            if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Doubles turn over - no moves left");
        } else {
            turnOver = FALSE;
            if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Doubles turn continues - moves left: " + (string)movesLeft);
        }
    } else {
        if (u1 == 0 && u2 == 0) {
            turnOver = TRUE;
            if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Normal turn over - both dice used");
        } else {
            turnOver = FALSE;
            if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Normal turn continues - u1: " + (string)u1 + ", u2: " + (string)u2);
        }
    }
    if (turnOver) {
        if (isGameOver()) {
            gCurrentState = STATE_GAME_OVER;
            string winner = "white";
            if (llGetListLength(BlackBorneOff) >= 15) winner = "black";
            llMessageLinked(LINK_SET, 0, "GAME_OVER|" + winner, NULL_KEY);
        } else {
            if (turn == "white") turn = "black";
            else turn = "white";
            
            // RESET DICE VALUES FOR NEXT TURN
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
    } else {
        if (DEBUG_MODE) {
            llOwnerSay("DEBUG CORE: After move - u1: " + (string)u1 + ", u2: " + (string)u2 + 
              ", isDoubles: " + (string)isDoubles + ", movesLeft: " + (string)movesLeft +
              ", turnOver: " + (string)turnOver);
        }
        integer isAIPlayer = FALSE;
        if (turn == "white" && CORE_WHITE_AI) isAIPlayer = TRUE;
        else if (turn == "black" && CORE_BLACK_AI) isAIPlayer = TRUE;
        
        if (isAIPlayer) {
            if (DEBUG_MODE) {
                llOwnerSay("DEBUG CORE: AI continues turn with remaining dice - u1: " + (string)u1 + ", u2: " + (string)u2);
            }
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
        if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Triggering AI for turn: " + turn);
        
        // Check if we already have dice from first roll
        integer shouldRollNewDice = (u1 == 0 && u2 == 0); // Only roll if dice are empty
        
        integer die1;
        integer die2;
        
        if (shouldRollNewDice) {
            // Only roll new dice if we don't have any
            if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Rolling new dice for AI turn: " + turn);
            die1 = 1 + (integer)llFrand(6);
            die2 = 1 + (integer)llFrand(6);
            
            u1 = die1;
            u2 = die2;
            
            // Check for doubles
            if (die1 == die2) {
                isDoubles = TRUE;
                movesLeft = 4;
            } else {
                isDoubles = FALSE;
                movesLeft = 0;
            }
            
            // Send dice roll message for animation
            llMessageLinked(LINK_SET, 0, "DICE_ROLL|" + turn + "|" + (string)die1 + "|" + (string)die2, NULL_KEY);
        } else {
            // Use existing dice values
            die1 = u1;
            die2 = u2;
            
            // Check for doubles (important for first turn)
            if (die1 == die2) {
                isDoubles = TRUE;
                movesLeft = 4;
            } else {
                isDoubles = FALSE;
                movesLeft = 0;
            }
            
            if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Using existing dice: " + (string)die1 + " and " + (string)die2);
            
            // Don't send DICE_ROLL - dice are already visible from first roll
        }
        
        // Always update dice values
        llMessageLinked(LINK_SET, 0, "DICE_VALUES|" + (string)u1 + "|" + (string)u2, NULL_KEY);
        
        if (DEBUG_MODE) {
            llOwnerSay("DEBUG CORE: After setting dice - u1: " + (string)u1 + ", u2: " + (string)u2);
        }
        
        // Wait and trigger AI
        llSleep(3.0);
        llMessageLinked(LINK_SET, 0, "TRIGGER_AI_TURN|" + turn + "|" + (string)u1 + "|" + (string)u2 + "|" + (string)isDoubles + "|" + (string)movesLeft, NULL_KEY);
    }
}

handleFirstRollPhase(string player, integer die1, integer die2) {
    llOwnerSay("DEBUG CORE: Handling first roll - Player: " + player + ", Dice: " + (string)die1 + "," + (string)die2);
    
    // Set player-specific variables
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
    
    // Only proceed if both players have rolled
    if (!whiteOnce || !blackOnce) return;
    
    // COMMON RESET - Always reset these when both have rolled
    whiteOnce = FALSE;
    blackOnce = FALSE;
    
    // Handle tie case (early exit)
    if (whiteDie == blackDie) {
        llMessageLinked(LINK_SET, 0, "REROLL_FIRST", NULL_KEY);
        
        // Reset first roll state
        whiteOnce = FALSE;
        blackOnce = FALSE;
        
        // If both players are AI, automatically trigger new rolls
        if (white == NULL_KEY && black == NULL_KEY) {
            if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Auto-triggering AI reroll after tie");
            llSleep(2.0);
            
            // Trigger new AI rolls directly
            integer whiteDie1 = 1 + (integer)llFrand(6);
            integer whiteDie2 = 1 + (integer)llFrand(6);
            integer blackDie1 = 1 + (integer)llFrand(6);
            integer blackDie2 = 1 + (integer)llFrand(6);
            
            llMessageLinked(LINK_SET, 0, "DICE_ROLL|white|" + (string)whiteDie1 + "|" + (string)whiteDie2, NULL_KEY);
            llSleep(1.0);
            llMessageLinked(LINK_SET, 0, "DICE_ROLL|black|" + (string)blackDie1 + "|" + (string)blackDie2, NULL_KEY);
        }
        return;
    }
    
    // Determine winner
    if (whiteDie > blackDie) { // take winner die and losers die and that is the winners first die to use
        turn = "white";
        u1 = whiteDie1;// winner
        u2 = blackDie1;
    } else {
        turn = "black";
        u1 = blackDie1;// winner
        u2 = whiteDie1;
    }
    llOwnerSay("DEBUG CORE: First roll winner: " + turn + ", u1: " + (string)u1 + ", u2: " + (string)u2);
    llOwnerSay("DEBUG CORE: CORE_WHITE_AI: " + (string)CORE_WHITE_AI + ", CORE_BLACK_AI: " + (string)CORE_BLACK_AI);    
    // COMMON TRANSITION TO MAIN GAME
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
        list params = llParseString2List(str, ["|"], []);
        string command = llList2String(params, 0);
        
        // === CONTROL STATE from Menu ===
        if (command == "CONTROL_STATE") {
            string stateType = llList2String(params, 1);
            string stateValue = llList2String(params, 2);
            
            if (stateType == "SIMULATING") {
                CORE_SIMULATING = (integer)stateValue;
                if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Simulating = " + stateValue);
            }
            else if (stateType == "WHITE_AI") {
                CORE_WHITE_AI = (integer)stateValue;
                if (DEBUG_MODE) llOwnerSay("DEBUG CORE: White AI = " + stateValue);
                
                // Update player state if switching to AI
                if (CORE_WHITE_AI && white != NULL_KEY) {
                    white = NULL_KEY;
                    whitePresent = TRUE;
                }
            }
            else if (stateType == "BLACK_AI") {
                CORE_BLACK_AI = (integer)stateValue;
                if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Black AI = " + stateValue);
                
                // Update player state if switching to AI
                if (CORE_BLACK_AI && black != NULL_KEY) {
                    black = NULL_KEY;
                    blackPresent = TRUE;
                }
            }
            else if (stateType == "AI_LEVEL") {
                CORE_AI_LEVEL = (integer)stateValue;
                if (DEBUG_MODE) llOwnerSay("DEBUG CORE: AI Level = " + stateValue);
            }
            else if (stateType == "PAUSED") {
                CORE_GAME_PAUSED = (integer)stateValue;
                if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Paused = " + stateValue);
            }
            return;
        }
        else if (command == "START_FIRST_ROLL") {
            if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Received START_FIRST_ROLL command");
            if (gCurrentState == STATE_RESET && whitePresent && blackPresent) {
                gCurrentState = STATE_FIRST_ROLL;
                llMessageLinked(LINK_SET, 0, "START_FIRST_ROLL", NULL_KEY);
                
                // Auto-roll for AI players
                if (white == NULL_KEY && black == NULL_KEY) {
                    llSleep(2.0);
                    integer whiteDie1 = 1 + (integer)llFrand(6);
                    integer whiteDie2 = 1 + (integer)llFrand(6);
                    integer blackDie1 = 1 + (integer)llFrand(6);
                    integer blackDie2 = 1 + (integer)llFrand(6);
                    
                    llMessageLinked(LINK_SET, 0, "DICE_ROLL|white|" + (string)whiteDie1 + "|" + (string)whiteDie2, NULL_KEY);
                    llSleep(1.0);
                    llMessageLinked(LINK_SET, 0, "DICE_ROLL|black|" + (string)blackDie1 + "|" + (string)blackDie2, NULL_KEY);
                }
            }
        }
        else if (command == "PLAYER_DICE_ROLL") {
            string player = llList2String(params, 1);
            integer die1 = llList2Integer(params, 2);
            integer die2 = llList2Integer(params, 3);
            
            llOwnerSay("DEBUG CORE: PLAYER_DICE_ROLL received - Player: " + player + ", State: " + (string)gCurrentState);
            
            // First roll phase
            if (gCurrentState == STATE_RESET || gCurrentState == STATE_FIRST_ROLL) {
                if (gCurrentState == STATE_RESET) {
                    gCurrentState = STATE_FIRST_ROLL;
                    llOwnerSay("DEBUG CORE: Transitioned from RESET to FIRST_ROLL");
                }
                handleFirstRollPhase(player, die1, die2);
            }
            // Main game state
            else if (gCurrentState == STATE_MAIN_GAME && player == turn) {
                // Common variable setting for both players
                u1 = die1;
                u2 = die2;
                
                // Check for doubles
                isDoubles = (die1 == die2);
                if(isDoubles) movesLeft = 4;
                else movesLeft = 0;
                
                // Don't send DICE_ROLL back to UI - it already animated
                // Just update internal state
                llMessageLinked(LINK_SET, 0, "DICE_VALUES|" + (string)u1 + "|" + (string)u2, NULL_KEY);
                
                // Send game message
                llMessageLinked(LINK_SET, 0, "GAME_MESSAGE|" + player + " rolled " + (string)die1 + " and " + (string)die2, NULL_KEY);
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
                if (DEBUG_MODE) llOwnerSay("DEBUG: Both players present, moving to STATE_FIRST_ROLL");
                gCurrentState = STATE_FIRST_ROLL;
                llMessageLinked(LINK_SET, 0, "START_FIRST_ROLL", NULL_KEY);
                
                if (white == NULL_KEY && black == NULL_KEY) {
                    llSleep(2.0);
                    integer whiteDie1 = 1 + (integer)llFrand(6);
                    integer whiteDie2 = 1 + (integer)llFrand(6);
                    integer blackDie1 = 1 + (integer)llFrand(6);
                    integer blackDie2 = 1 + (integer)llFrand(6);
                    
                    llMessageLinked(LINK_SET, 0, "DICE_ROLL|white|" + (string)whiteDie1 + "|" + (string)whiteDie2, NULL_KEY);
                    llSleep(1.0);
                    llMessageLinked(LINK_SET, 0, "DICE_ROLL|black|" + (string)blackDie1 + "|" + (string)blackDie2, NULL_KEY);
                }
            }
        }
        else if (command == "FIRST_TURN") {
            // Add this to ensure AI gets proper first turn trigger
            if ((turn == "white" && CORE_WHITE_AI) || (turn == "black" && CORE_BLACK_AI)) {
                if (DEBUG_MODE) llOwnerSay("DEBUG CORE: First turn AI trigger for " + turn);
                llSleep(2.0);
                llMessageLinked(LINK_SET, 0, "TRIGGER_AI_TURN|" + turn + "|" + (string)u1 + "|" + (string)u2 + "|0|0", NULL_KEY);
            } else {
                triggerAIIfNeeded();
            }
        }
        else if (command == "DICE_ROLL") {
            string player = llList2String(params, 1);
            integer die1 = llList2Integer(params, 2);
            integer die2 = llList2Integer(params, 3);
            
            llOwnerSay("DEBUG CORE: DICE_ROLL received - Player: " + player + ", State: " + (string)gCurrentState);
            
            // First roll phase (RESET and FIRST_ROLL states)
            if (gCurrentState == STATE_RESET || gCurrentState == STATE_FIRST_ROLL) {
                if (gCurrentState == STATE_RESET) {
                    gCurrentState = STATE_FIRST_ROLL;
                    llOwnerSay("DEBUG CORE: Transitioned from RESET to FIRST_ROLL");
                }
                handleFirstRollPhase(player, die1, die2);
            }
            // Main game state
            else if (gCurrentState == STATE_MAIN_GAME && player == turn) {
                // Common variable setting for both players
                u1 = die1;
                u2 = die2;
                
                // Check for doubles
                isDoubles = (die1 == die2);
                if(isDoubles) movesLeft = 4;
                else movesLeft = 0;
                
                llMessageLinked(LINK_SET, 0, "DICE_VALUES|" + (string)u1 + "|" + (string)u2, NULL_KEY);
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
            
            processMove(from_point, to_point, die_value, movesUsed);
        }
        else if (command == "RESET_GAME") {
            llOwnerSay("DEBUG CORE: Resetting game");
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
            llOwnerSay("DEBUG CORE: Reset complete - State: " + (string)gCurrentState + ", Turn: '" + turn + "'");
        }
        else if (command == "REQUEST_BOARD_STATE") {
            string message = "FRESH_BOARD_STATE";
            integer i;
            for (i = 0; i < 24; i++) {
                message += "|" + llList2String(BoardList, i);
            }
            message += "|" + llDumpList2String(WhiteBarList, ",");
            message += "|" + llDumpList2String(BlackBarList, ",");
            message += "|" + llDumpList2String(WhiteBorneOff, ",");
            message += "|" + llDumpList2String(BlackBorneOff, ",");
            
            if (DEBUG_MODE) {
                llOwnerSay("DEBUG CORE: Sending FRESH_BOARD_STATE with " + (string)(llGetListLength(BoardList)) + " board points");
                llOwnerSay("DEBUG CORE: Message parameter count: " + (string)(1 + 24 + 2 + 2));
            }
            
            llMessageLinked(LINK_SET, 0, message, NULL_KEY);
        }
        else if (command == "GET_PIECE_POSITION") {
            string pieceName = llList2String(params, 1);
            key playerKey = (key)llList2String(params, 2);  // Get the player key
            integer position = -1;
            
            // Search through board points
            integer i;
            for(i = 0; i < BOARD_SIZE; i++) {
                string pointContents = llList2String(BoardList, i);
                if (pointContents != "" && llSubStringIndex(pointContents, pieceName) != -1) {
                    position = i;
                    jump found;
                }
            }
            
            // Check if piece is on bar
            if (llListFindList(WhiteBarList, [pieceName]) != -1 || llListFindList(BlackBarList, [pieceName]) != -1) {
                position = FROM_BAR;
            }
            
            @found;
            llMessageLinked(LINK_SET, 0, "PIECE_POSITION|" + pieceName + "|" + (string)position + "|" + (string)playerKey, NULL_KEY);
        }
        else if (command == "AI_NO_MOVES") {
            string player = llList2String(params, 1);
            if (player == turn) {
                if (DEBUG_MODE) {
                    llOwnerSay("DEBUG CORE: AI_NO_MOVES received for " + player);
                    llOwnerSay("DEBUG CORE: Pre-reset state - u1: " + (string)u1 + ", u2: " + (string)u2 + 
                              ", isDoubles: " + (string)isDoubles + ", movesLeft: " + (string)movesLeft);
                }
                
                // Check for game over first
                if (isGameOver()) {
                    gCurrentState = STATE_GAME_OVER;
                    string winner = "white";
                    if (llGetListLength(BlackBorneOff) >= 15) winner = "black";
                    llMessageLinked(LINK_SET, 0, "GAME_OVER|" + winner, NULL_KEY);
                    return;
                }
                
                // INTENT: Reset all turn state
                whiteOnce = FALSE;
                blackOnce = FALSE;
                isDoubles = FALSE;
                movesLeft = 0;
                u1 = 0;  // Clear any remaining dice
                u2 = 0;
                if (DEBUG_MODE) {
                    llOwnerSay("DEBUG CORE: Post-reset state - u1: " + (string)u1 + ", u2: " + (string)u2 + 
                              ", isDoubles: " + (string)isDoubles + ", movesLeft: " + (string)movesLeft);
                }

                // Change turn
                if (turn == "white") turn = "black";
                else turn = "white";
        
                llMessageLinked(LINK_SET, 0, "TURN_CHANGE|" + turn, NULL_KEY);
                
                if (DEBUG_MODE) llOwnerSay("DEBUG CORE: Turn changed to: " + turn);
                
                llSleep(2.0);
                triggerAIIfNeeded();
            }
        }
    }
}