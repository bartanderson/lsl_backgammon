// BACKGAMMON AI - Clean computer opponent
integer DEBUG_MODE = FALSE;
integer AI_LEVEL = 1;

// Player keys to track who is AI
key white = NULL_KEY;
key black = NULL_KEY;

// Game state storage
list BoardList = [];
list WhiteBarList = [];
list BlackBarList = [];
string currentTurn = "";
integer currentDie1 = 0;
integer currentDie2 = 0;
integer isDoubles = FALSE;
integer movesLeft = 0;

// CONTROL STATE from Menu
integer AI_WHITE_CONTROLLED = FALSE;
integer AI_BLACK_CONTROLLED = FALSE;
integer AI_CONTROL_LEVEL = 1;

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

string generateHomeBoardMove() {
    if (DEBUG_MODE) llOwnerSay("DEBUG AI: generateHomeBoardMove for " + currentTurn);
    
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
    
    if (DEBUG_MODE) llOwnerSay("DEBUG AI: No valid home board moves found");
    return "";
}

string generateBarMove() {
    if (DEBUG_MODE) llOwnerSay("DEBUG AI: generateBarMove for " + currentTurn);
    
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
                    if (DEBUG_MODE) llOwnerSay("DEBUG AI: Valid bar move found - to point: " + (string)targetPoint + " using die: " + (string)dieToUse);
                    return "PLAYER_MOVE|" + currentTurn + "|" + (string)FROM_BAR + "|" + 
                           (string)targetPoint + "|" + (string)dieToUse + "|1";
                }
            }
        }
    }
    
    if (DEBUG_MODE) llOwnerSay("DEBUG AI: No valid bar moves found");
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
                
                // Check exact match or overshoot first
                if (dieValue >= requiredDistance) {
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
                
                // Check exact match or overshoot first
                if (dieValue >= requiredDistance) {
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
    if (DEBUG_MODE) llOwnerSay("DEBUG AI: Found bear off at point " + (string)point + " with die " + (string)dieValue);
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
    if (DEBUG_MODE) llOwnerSay("DEBUG AI: generateBearOffMove for " + currentTurn);
    
    if (!mustBearOff(currentTurn)) {
        if (DEBUG_MODE) llOwnerSay("DEBUG AI: Not in bearing off phase");
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
    
    if (DEBUG_MODE) llOwnerSay("DEBUG AI: No valid bear off moves found");
    return "";
}

string generateRandomMove() {
    if (DEBUG_MODE) llOwnerSay("DEBUG AI: generateRandomMove for " + currentTurn);
    
    // ENFORCEMENT: Check if player has pieces on bar - if yes, ONLY bar moves allowed
    if (currentTurn == "white" && llGetListLength(WhiteBarList) > 0) {
        if (DEBUG_MODE) llOwnerSay("DEBUG AI: White has pieces on bar - only considering bar moves");
        string barMove = generateBarMove();
        if (barMove != "") {
             return barMove;
        } else {
            if (DEBUG_MODE) llOwnerSay("DEBUG AI: No valid bar moves found, but must move from bar - ending turn");
            return "AI_NO_MOVES|" + currentTurn;
        }
    }
    else if (currentTurn == "black" && llGetListLength(BlackBarList) > 0) {
        if (DEBUG_MODE) llOwnerSay("DEBUG AI: Black has pieces on bar - only considering bar moves");
        string barMove = generateBarMove();
        if (barMove != "") {
            return barMove;
        } else {
            if (DEBUG_MODE) llOwnerSay("DEBUG AI: No valid bar moves found, but must move from bar - ending turn");
            return "AI_NO_MOVES|" + currentTurn;
        }
    }
    
    // ENFORCEMENT: Check if player must bear off - if yes, ONLY bear off moves allowed
    if (mustBearOff(currentTurn)) {
        if (DEBUG_MODE) llOwnerSay("DEBUG AI: Player must bear off - only considering bear off moves");
        string bearOffMove = generateBearOffMove();
        if (bearOffMove != "") {
            return bearOffMove;
        } else {
            // CANNOT BEAR OFF - try to move forward in home board
            if (DEBUG_MODE) llOwnerSay("DEBUG AI: Cannot bear off - trying to move within home board");
            return generateHomeBoardMove();
        }
    }

    // Existing logic for regular moves (unchanged)
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG AI: Checking board pieces. BoardList length: " + (string)llGetListLength(BoardList));
        integer ii;
        for (ii = 0; ii < BOARD_SIZE; ii++) {
            string point = llList2String(BoardList, ii);
            llOwnerSay("DEBUG AI: Point " + (string)ii + ": '" + point + "'");
        }
    }
        
    // REVERSE the iteration order for black
    integer startPoint = 0;
    integer endPoint = BOARD_SIZE - 1;
    integer step = 1;
    
    if (currentTurn == "black") {
        // For black, iterate from high to low points to find farthest pieces first
        startPoint = BOARD_SIZE - 1;
        endPoint = 0;
        step = -1;
    }
    
    integer i = startPoint;
    while ((currentTurn == "white" && i <= endPoint) || (currentTurn == "black" && i >= endPoint)) {
        string point = llList2String(BoardList, i);
        if (point != "") {
            string playerColor;
            if (currentTurn == "white") {
                playerColor = "w";
            } else {
                playerColor = "b";
            }
            
            if (llSubStringIndex(point, playerColor) != -1) {
                if (DEBUG_MODE) llOwnerSay("DEBUG AI: Found player piece at point " + (string)i + ": " + point);
                list movesFromPoint = getValidMovesFromPoint(i);
                if (llGetListLength(movesFromPoint) > 0) {
                    string randomMove = llList2String(movesFromPoint, (integer)llFrand(llGetListLength(movesFromPoint)));
                    if (DEBUG_MODE) llOwnerSay("DEBUG AI: Selected move: " + randomMove);
                    return randomMove;
                } else {
                    if (DEBUG_MODE) llOwnerSay("DEBUG AI: No valid moves from point " + (string)i);
                }
            }
        }
        i = i + step;
    }

    if (DEBUG_MODE) llOwnerSay("DEBUG AI: No valid moves found anywhere");
    return "";
}

generateAIMove() {
    if (DEBUG_MODE) llOwnerSay("AI Level " + (string)AI_LEVEL + " generating move...");
    
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
        if (DEBUG_MODE) llOwnerSay("DEBUG AI: Executing move: " + move);
        llMessageLinked(LINK_SET, 0, move, NULL_KEY);
    } else {
        if (DEBUG_MODE) llOwnerSay("DEBUG AI: No valid moves found - ending turn");
        llMessageLinked(LINK_SET, 0, "AI_NO_MOVES|" + currentTurn, NULL_KEY);
    }
}

string checkSingleDieMove(integer fromPoint, integer dieValue, integer direction) {
    integer toPoint = fromPoint + (dieValue * direction);
    
    if (toPoint < 0 || toPoint >= BOARD_SIZE) {
        // Bearing off
        // FIX: Change isValidBearOffMove to isValidBearOff
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
            // Format the move to indicate it uses both dice
            move = "PLAYER_MOVE|" + currentTurn + "|" + (string)fromPoint + "|" + 
                   llList2String(llParseString2List(move, ["|"], []), 3) + "|" + 
                   (string)combinedDie + "|2";
            moves += [move];
        }
    }
    
    return moves;
}

integer isValidMove(integer fromPoint, integer toPoint, integer dieValue) {
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG AI: isValidMove checking from " + (string)fromPoint + " to " + (string)toPoint);
    }
    
    if (toPoint < 0 || toPoint >= BOARD_SIZE) {
        if (DEBUG_MODE) llOwnerSay("DEBUG AI: Invalid move - toPoint out of bounds: " + (string)toPoint);
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
        llOwnerSay("DEBUG AI: Checking move from " + (string)fromPoint + " to " + (string)toPoint + 
                   " - target: '" + target + "', opponentCount: " + (string)opponentCount + 
                   ", isValid: " + (string)isValid);
    }
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG AI: isValidMove result: " + (string)isValid + " for from " + (string)fromPoint + " to " + (string)toPoint);
    }
    return isValid;
}

string generateTacticalMove() {
    return generateRandomMove();
}

string generateStrategicMove() {
    return generateRandomMove();
}

integer isValidBearOff(integer from_point, integer die_value, integer color) {
    if (!allPiecesInHomeBoard(color)) {
        if (DEBUG_MODE) llOwnerSay("DEBUG AI: Not all pieces in home board");
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
        if (DEBUG_MODE) llOwnerSay("DEBUG AI: Point not in home board");
        return FALSE;
    }
    
    // Calculate required bear off distance
    integer requiredDistance;
    if (color == 0) { // White
        requiredDistance = 24 - from_point;  // White: 18→6, 19→5, 20→4, 21→3, 22→2, 23→1
    } else { // Black
        requiredDistance = from_point + 1;   // Black: 5→6, 4→5, 3→4, 2→3, 1→2, 0→1 
    }
    
    // Only allow exact match or overshoot
    if (die_value >= requiredDistance) {
        if (DEBUG_MODE) llOwnerSay("DEBUG AI: Bear off valid - die " + (string)die_value + " >= required " + (string)requiredDistance);
        return TRUE;
    }
    
    if (DEBUG_MODE) llOwnerSay("DEBUG AI: Bear off invalid - die " + (string)die_value + " < required " + (string)requiredDistance);
    return FALSE;
}

default {
    state_entry() {
        if (DEBUG_MODE) llOwnerSay("Backgammon AI initialized - Level " + (string)AI_LEVEL);
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list params = llParseString2List(str, ["|"], []);
        string command = llList2String(params, 0);
        
        // === CONTROL STATE from Menu ===
        if (command == "CONTROL_STATE") {
            string stateType = llList2String(params, 1);
            string stateValue = llList2String(params, 2);
            
            if (stateType == "WHITE_AI") {
                AI_WHITE_CONTROLLED = (integer)stateValue;
                if (DEBUG_MODE) llOwnerSay("DEBUG AI: White controlled = " + stateValue);
            }
            else if (stateType == "BLACK_AI") {
                AI_BLACK_CONTROLLED = (integer)stateValue;
                if (DEBUG_MODE) llOwnerSay("DEBUG AI: Black controlled = " + stateValue);
            }
            else if (stateType == "AI_LEVEL") {
                AI_CONTROL_LEVEL = (integer)stateValue;
                AI_LEVEL = AI_CONTROL_LEVEL;
                if (DEBUG_MODE) llOwnerSay("DEBUG AI: Level set to " + stateValue);
            }
            return;
        }
        else if (command == "SET_AI_LEVEL") {
            AI_LEVEL = llList2Integer(params, 1);
            if (DEBUG_MODE) llOwnerSay("AI level set to: " + (string)AI_LEVEL);
        }
        else if (command == "SET_PLAYER_KEYS") {
            white = (key)llList2String(params, 1);
            black = (key)llList2String(params, 2);
            if (DEBUG_MODE) llOwnerSay("DEBUG AI: Player keys set - white: " + (string)white + ", black: " + (string)black);
        }
        else if (command == "AI_REQUEST_MOVE") {
            if (DEBUG_MODE) llOwnerSay("DEBUG AI: Requesting fresh board state from core");
            
            llMessageLinked(LINK_SET, 0, "REQUEST_BOARD_STATE", NULL_KEY);
            
            currentTurn = llList2String(params, 1);
            currentDie1 = llList2Integer(params, 2);
            currentDie2 = llList2Integer(params, 3);
            isDoubles = llList2Integer(params, 4);
            movesLeft = llList2Integer(params, 5);
            
            if (DEBUG_MODE) {
                llOwnerSay("DEBUG AI: Received AI_REQUEST_MOVE - turn: " + currentTurn + ", dice: " + (string)currentDie1 + "," + (string)currentDie2);
            }
        }
        else if (command == "FRESH_BOARD_STATE") {
            if (DEBUG_MODE) llOwnerSay("DEBUG AI: Received fresh board state");
            
            // remove me - 
            integer whiteOnBoard = 0;
            integer blackOnBoard = 0;
            integer i;
            for (i = 0; i < 24; i++) {
                string point = llList2String(BoardList, i);
                if (point != "") {
                    if (llSubStringIndex(point, "w") != -1) whiteOnBoard++;
                    if (llSubStringIndex(point, "b") != -1) blackOnBoard++;
                }
            }
            llOwnerSay("DEBUG AI: FRESH_BOARD_STATE - " +
                       "WhiteOnBoard: " + (string)whiteOnBoard +
                       " BlackOnBoard: " + (string)blackOnBoard);
            // - when fixed
            
            list params = llParseStringKeepNulls(str, ["|"], []);                
            
            if (llGetListLength(params) != 29) {
                if (DEBUG_MODE) llOwnerSay("DEBUG AI: ERROR - Expected 29 parameters, got " + (string)llGetListLength(params));
                return;
            }
            
            BoardList = llList2List(params, 1, 24);
            
            string whiteBar = llList2String(params, 25);
            string blackBar = llList2String(params, 26);
            
            string whiteBorneOff = llList2String(params, 27);
            string blackBorneOff = llList2String(params, 28);
            
            WhiteBarList = llParseString2List(whiteBar, [","], []);
            BlackBarList = llParseString2List(blackBar, [","], []);
            
            if (DEBUG_MODE) {
                llOwnerSay("DEBUG AI: BoardList length: " + (string)llGetListLength(BoardList));
                llOwnerSay("DEBUG AI: WhiteBarList: " + llDumpList2String(WhiteBarList, ","));
                llOwnerSay("DEBUG AI: BlackBarList: " + llDumpList2String(BlackBarList, ","));
                llOwnerSay("DEBUG AI: WhiteBorneOff: " + whiteBorneOff);
                llOwnerSay("DEBUG AI: BlackBorneOff: " + blackBorneOff);
            }
            
            generateAIMove();
        }
        else if (command == "TRIGGER_AI_TURN") {
            currentTurn = llList2String(params, 1);
            currentDie1 = llList2Integer(params, 2);
            currentDie2 = llList2Integer(params, 3);
            isDoubles = llList2Integer(params, 4);
            movesLeft = llList2Integer(params, 5);
            
            if (DEBUG_MODE) {
                llOwnerSay("DEBUG AI: Received TRIGGER_AI_TURN - turn: " + currentTurn + 
                          ", dice: " + (string)currentDie1 + "," + (string)currentDie2);
            }
            
            // Only process if we control this player
            if ((currentTurn == "white" && AI_WHITE_CONTROLLED) || 
                (currentTurn == "black" && AI_BLACK_CONTROLLED)) {
                
                if (DEBUG_MODE) llOwnerSay("DEBUG AI: Processing AI turn for " + currentTurn);
                llMessageLinked(LINK_SET, 0, "REQUEST_BOARD_STATE", NULL_KEY);
            } else {
                if (DEBUG_MODE) llOwnerSay("DEBUG AI: Ignoring turn - not controlled by AI");
            }
        }
    }    
}