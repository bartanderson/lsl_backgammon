// BACKGAMMON PERSISTENCE - Save/Load System
// Offloads memory-intensive operations from core script

integer DEBUG_MODE = TRUE;

// Communication channels
integer CORE_CHANNEL = -995832;
integer UI_CHANNEL = -995833;

// Game state storage (will receive from core)
list BoardList = [];
list WhiteBarList = [];
list BlackBarList = [];
string turn = "";
integer gCurrentState = 0;
integer u1 = 0;
integer u2 = 0;
integer isDoubles = FALSE;
integer movesLeft = 0;
integer whiteOnce = FALSE;
integer blackOnce = FALSE;
integer whiteDie1 = 0;
integer whiteDie2 = 0;
integer blackDie1 = 0;
integer blackDie2 = 0;
integer whiteDie = 0;
integer blackDie = 0;

// Corrected bit layout for game state:
// [1:0]   - gCurrentState (0-3)
// [2]     - turn (0=white, 1=black)  
// [5:3]   - u1 (0-7)
// [8:6]   - u2 (0-7)
// [9]     - isDoubles
// [13:10] - movesLeft (0-15)
// [14]    - whiteOnce
// [15]    - blackOnce
// [18:16] - whiteDie1 (0-7)
// [21:19] - whiteDie2 (0-7)
// [24:22] - blackDie1 (0-7)
// [27:25] - blackDie2 (0-7)
// [30:28] - whiteDie (0-7)
// [31]    - blackDie (uses 1 bit + reconstructed)

integer CORE_WHITE_AI = FALSE;
integer CORE_BLACK_AI = FALSE;
integer CORE_SIMULATING = FALSE;

integer encodeGameState() {
    integer StateValue = 0;
    
    StateValue = StateValue | (gCurrentState & 3);
    
    if (turn == "black") {
        StateValue = StateValue | (1 << 2);
    }
    
    StateValue = StateValue | ((u1 & 7) << 3);
    StateValue = StateValue | ((u2 & 7) << 6);
    
    if (isDoubles) {
        StateValue = StateValue | (1 << 9);
    }
    
    StateValue = StateValue | ((movesLeft & 15) << 10);
    
    // First roll state
    if (whiteOnce) StateValue = StateValue | (1 << 14);
    if (blackOnce) StateValue = StateValue | (1 << 15);
    
    // Dice values
    StateValue = StateValue | ((whiteDie1 & 7) << 16);
    StateValue = StateValue | ((whiteDie2 & 7) << 19);
    StateValue = StateValue | ((blackDie1 & 7) << 22);
    StateValue = StateValue | ((blackDie2 & 7) << 25);
    StateValue = StateValue | ((whiteDie & 7) << 28);
    
    // Store blackDie in the highest bit (we'll reconstruct from blackDie1)
    if (blackDie > 0) StateValue = StateValue | (1 << 31);
    
    return StateValue;
}

decodeGameState(integer StateValue) {
    gCurrentState = StateValue & 3;
    
    turn = "white";
    if ((StateValue >> 2) & 1) turn = "black";
    
    u1 = (StateValue >> 3) & 7;
    u2 = (StateValue >> 6) & 7;
    isDoubles = ((StateValue >> 9) & 1) == 1;
    movesLeft = (StateValue >> 10) & 15;
    
    whiteOnce = ((StateValue >> 14) & 1) == 1;
    blackOnce = ((StateValue >> 15) & 1) == 1;
    
    whiteDie1 = (StateValue >> 16) & 7;
    whiteDie2 = (StateValue >> 19) & 7;
    blackDie1 = (StateValue >> 22) & 7;
    blackDie2 = (StateValue >> 25) & 7;
    whiteDie = (StateValue >> 28) & 7;
    
    // Reconstruct blackDie
    blackDie = blackDie1;
    if (((StateValue >> 31) & 1) && blackDie == 0) blackDie = 1;
}

// New improved board encoding that preserves piece counts
integer encodeBoardFragment(integer startPoint) {
    integer fragment = 0;
    integer i;
    
    for(i = 0; i < 6; i = i + 1) {
        integer pointIndex = startPoint + i;
        if (pointIndex < 24) {
            string point = llList2String(BoardList, pointIndex);
            integer pointEncoding = 0;
            
            if (point != "") {
                // Count white and black pieces
                list pieces = llParseString2List(point, [","], []);
                integer whiteCount = 0;
                integer blackCount = 0;
                
                integer j;
                for (j = 0; j < llGetListLength(pieces); j++) {
                    string piece = llList2String(pieces, j);
                    if (llGetSubString(piece, 0, 0) == "w") {
                        whiteCount++;
                    } else if (llGetSubString(piece, 0, 0) == "b") {
                        blackCount++;
                    }
                }
                
                // Encode: [3:0] white count (0-15), [7:4] black count (0-15)
                pointEncoding = (whiteCount & 15) | ((blackCount & 15) << 4);
            }
            
            fragment = fragment | (pointEncoding << (i * 8));
        }
    }
    
    return fragment;
}

decodeBoardFragment(integer fragment, integer startPoint) {
    integer i;
    for(i = 0; i < 6; i = i + 1) {
        integer pointIndex = startPoint + i;
        if (pointIndex < 24) {
            // Extract 8 bits for this point (4 bits white count, 4 bits black count)
            integer pointEncoding = (fragment >> (i * 8)) & 255;
            integer whiteCount = pointEncoding & 15;
            integer blackCount = (pointEncoding >> 4) & 15;
            
            // Reconstruct the point
            string pointState = "";
            
            if (whiteCount > 0 || blackCount > 0) {
                list pieces = [];
                integer w;
                for (w = 0; w < whiteCount; w++) {
                    pieces += ["w" + (string)(pointIndex + 1) + "_" + (string)w];
                }
                integer b;
                for (b = 0; b < blackCount; b++) {
                    pieces += ["b" + (string)(pointIndex + 1) + "_" + (string)b];
                }
                pointState = llDumpList2String(pieces, ",");
            }
            
            BoardList = llListReplaceList(BoardList, [pointState], pointIndex, pointIndex);
        }
    }
}

// Improved bar encoding that preserves exact piece names
string encodeBarState() {
    // Use string encoding for bars to preserve exact piece names
    string whiteBarStr = llDumpList2String(WhiteBarList, ",");
    string blackBarStr = llDumpList2String(BlackBarList, ",");
    return whiteBarStr + "|" + blackBarStr;
}

rebuildBarsFromState(string barStateStr) {
    list barParts = llParseString2List(barStateStr, ["|"], []);
    if (llGetListLength(barParts) >= 2) {
        string whiteBarStr = llList2String(barParts, 0);
        string blackBarStr = llList2String(barParts, 1);
        
        if (whiteBarStr != "") {
            WhiteBarList = llParseString2List(whiteBarStr, [","], []);
        } else {
            WhiteBarList = [];
        }
        
        if (blackBarStr != "") {
            BlackBarList = llParseString2List(blackBarStr, [","], []);
        } else {
            BlackBarList = [];
        }
    } else {
        WhiteBarList = [];
        BlackBarList = [];
    }
}

// Main save function
// Main save function
saveGameFragments() {
    list fragments = [];
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG PERSISTENCE: Starting save");
        llOwnerSay("Board length: " + (string)llGetListLength(BoardList));
        llOwnerSay("White bar: " + llDumpList2String(WhiteBarList, ","));
        llOwnerSay("Black bar: " + llDumpList2String(BlackBarList, ","));
        llOwnerSay("Turn: " + turn + ", State: " + (string)gCurrentState);
    }
    
    // Fragment 0: Game state 
    integer gameState = encodeGameState();
    fragments = fragments + [gameState];
    
    // Fragments 1-4: Board state (6 points per fragment) - KEEP EXISTING
    fragments = fragments + [encodeBoardFragment(0)];
    fragments = fragments + [encodeBoardFragment(6)];
    fragments = fragments + [encodeBoardFragment(12)]; 
    fragments = fragments + [encodeBoardFragment(18)];
    
    // Fragment 5: Bar state (as string encoded in base64 to handle special chars)
    string barState = encodeBarState();
    fragments = fragments + [llStringToBase64(barState)];
    
    // Fragment 6: Board pieces tracking - KEEP EXISTING
    integer boardPiecesFragment = 0;
    integer i;
    for(i = 0; i < 24 && i < llGetListLength(BoardList); i++) {
        string point = llList2String(BoardList, i);
        if (point != "") {
            boardPiecesFragment = boardPiecesFragment | (1 << i);
        }
    }
    fragments += [boardPiecesFragment];
    
    // NEW: Fragments 7-9: AI/Human state
    fragments = fragments + [CORE_WHITE_AI];
    fragments = fragments + [CORE_BLACK_AI];
    fragments = fragments + [CORE_SIMULATING];
    
    // Send all fragments
    string message = "SAVE_OUTPUT";
    for(i = 0; i < llGetListLength(fragments); i++) {
        message += "|" + (string)llList2Integer(fragments, i);
    }
    
    llMessageLinked(LINK_SET, 0, message, NULL_KEY);
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG: Sent save fragments: " + message);
        llOwnerSay("DEBUG: AI State - WhiteAI:" + (string)CORE_WHITE_AI + " BlackAI:" + (string)CORE_BLACK_AI + " Simulating:" + (string)CORE_SIMULATING);
    }
}

// Main load function  
// Main load function  
loadGameFragments(string fragmentStr) {
    list fragments = llParseString2List(fragmentStr, ["|"], []);
    
    if (llGetListLength(fragments) < 7) {
        llOwnerSay("ERROR: Not enough fragments: " + (string)llGetListLength(fragments));
        return;
    }
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG: Loading " + (string)llGetListLength(fragments) + " fragments");
    }
    
    // Decode game state
    integer gameStateFragment = llList2Integer(fragments, 0);
    decodeGameState(gameStateFragment);
    
    // Initialize empty board
    BoardList = [];
    integer i;
    for(i = 0; i < 24; i++) {
        BoardList = BoardList + [""];
    }
    
    // Get the board pieces fragment (fragment 6)
    integer boardPiecesFragment = llList2Integer(fragments, 6);
    
    // Decode board fragments with piece reconstruction
    decodeBoardFragment(llList2Integer(fragments, 1), 0);
    decodeBoardFragment(llList2Integer(fragments, 2), 6);
    decodeBoardFragment(llList2Integer(fragments, 3), 12);
    decodeBoardFragment(llList2Integer(fragments, 4), 18);
    
    // Rebuild bars from base64 encoded string
    string barStateBase64 = (string)llList2Integer(fragments, 5);
    string barStateStr = llBase64ToString(barStateBase64);
    rebuildBarsFromState(barStateStr);
    
    // NEW: Load AI/human state if available (fragments 7-9)
    CORE_WHITE_AI = FALSE;
    CORE_BLACK_AI = FALSE;
    CORE_SIMULATING = FALSE;
    
    if (llGetListLength(fragments) >= 10) {
        CORE_WHITE_AI = llList2Integer(fragments, 7);
        CORE_BLACK_AI = llList2Integer(fragments, 8);
        CORE_SIMULATING = llList2Integer(fragments, 9);
    }
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG: Loaded board length: " + (string)llGetListLength(BoardList));
        llOwnerSay("DEBUG: Loaded white bar: " + llDumpList2String(WhiteBarList, ","));
        llOwnerSay("DEBUG: Loaded black bar: " + llDumpList2String(BlackBarList, ","));
        llOwnerSay("DEBUG: Loaded turn: " + turn + ", state: " + (string)gCurrentState);
        llOwnerSay("DEBUG: Loaded AI State - WhiteAI:" + (string)CORE_WHITE_AI + " BlackAI:" + (string)CORE_BLACK_AI + " Simulating:" + (string)CORE_SIMULATING);
    }
    
    // Send updates to core system
    llMessageLinked(LINK_SET, 0, "LOADED_BOARD_STATE|" + llDumpList2String(BoardList, "|"), NULL_KEY);
    llMessageLinked(LINK_SET, 0, "LOADED_BAR_STATE|" + llDumpList2String(WhiteBarList, "|") + "|" + llDumpList2String(BlackBarList, "|"), NULL_KEY);
    llMessageLinked(LINK_SET, 0, "LOADED_GAME_STATE|" + turn + "|" + (string)gCurrentState + "|" + (string)u1 + "|" + (string)u2 + "|" + (string)isDoubles + "|" + (string)movesLeft, NULL_KEY);
    llMessageLinked(LINK_SET, 0, "LOADED_FIRST_ROLL|" + (string)whiteOnce + "|" + (string)blackOnce + "|" + (string)whiteDie1 + "|" + (string)whiteDie2 + "|" + (string)blackDie1 + "|" + (string)blackDie2 + "|" + (string)whiteDie + "|" + (string)blackDie, NULL_KEY);
    
    // NEW: Send AI/human state
    llMessageLinked(LINK_SET, 0, "LOADED_PLAYER_TYPES|" + (string)CORE_WHITE_AI + "|" + (string)CORE_BLACK_AI + "|" + (string)CORE_SIMULATING, NULL_KEY);
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG: Load completed successfully");
    }
}

default {
    state_entry() {
        if (DEBUG_MODE) llOwnerSay("Persistence system ready");
    }
    
    link_message(integer sender, integer num, string msg, key id) {
        list params = llParseString2List(msg, ["|"], []);
        string cmd = llList2String(params, 0);
        
        if (cmd == "PERSISTENCE_SAVE") {
            // Receive full game state from core
            if (DEBUG_MODE) llOwnerSay("DEBUG: Received PERSISTENCE_SAVE command");
            
            string boardStateStr = llList2String(params, 1);
            BoardList = llParseStringKeepNulls(boardStateStr, ["|"], []);  // Use | as delimiter
            
            WhiteBarList = llParseString2List(llList2String(params, 2), [","], []);
            BlackBarList = llParseString2List(llList2String(params, 3), [","], []);
            turn = llList2String(params, 4);
            gCurrentState = llList2Integer(params, 5);
            u1 = llList2Integer(params, 6);
            u2 = llList2Integer(params, 7);
            isDoubles = llList2Integer(params, 8);
            movesLeft = llList2Integer(params, 9);
            whiteOnce = llList2Integer(params, 10);
            blackOnce = llList2Integer(params, 11);
            whiteDie1 = llList2Integer(params, 12);
            whiteDie2 = llList2Integer(params, 13);
            blackDie1 = llList2Integer(params, 14);
            blackDie2 = llList2Integer(params, 15);
            whiteDie = llList2Integer(params, 16);
            blackDie = llList2Integer(params, 17);
            
            saveGameFragments();
        }
        else if (cmd == "PERSISTENCE_LOAD") {
            if (DEBUG_MODE) llOwnerSay("DEBUG: Received PERSISTENCE_LOAD command");
            
            // Reconstruct the full fragment string from all parameters after the first
            string fragmentStr = llDumpList2String(llList2List(params, 1, -1), "|");
            loadGameFragments(fragmentStr);
        }
    }
}