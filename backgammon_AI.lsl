// BACKGAMMON AI MAIN (PUPPET) - Interface
integer DEBUG_MODE = TRUE;
integer AI_LEVEL = 1; // Fallback
integer gWhiteAILevel = 1;
integer gBlackAILevel = 1;

// Player keys to track who is AI
key white = NULL_KEY;
key black = NULL_KEY;

// CONTROL STATE from Menu
integer AI_WHITE_CONTROLLED = FALSE;
integer AI_BLACK_CONTROLLED = FALSE;
integer AI_CONTROL_LEVEL = 1;
integer AI_WHITE_LEVEL = 1;
integer AI_BLACK_LEVEL = 1;

// AI STATE MACHINE
integer AI_STATE_IDLE = 0;
integer AI_STATE_REQUESTING_BOARD = 1;
integer AI_STATE_THINKING = 2; // Waiting for Brain
integer AI_STATE_MOVE_SENT = 3;

integer gAIState = 0;  // AI_STATE_IDLE
string gCurrentMoveID = "";
string currentTurn = "";
integer currentDie1 = 0;
integer currentDie2 = 0;
integer isDoubles = FALSE;
integer movesLeft = 0;

default {
    state_entry() {
        if (DEBUG_MODE) llOwnerSay("Backgammon AI MAIN (Puppet) initialized");
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list params = llParseStringKeepNulls(str, ["|"], []);
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
            else if (stateType == "WHITE_AI_LEVEL") {
                AI_WHITE_LEVEL = (integer)stateValue;
                gWhiteAILevel = AI_WHITE_LEVEL;
                // Forward to Brain
                llMessageLinked(LINK_SET, 0, "SET_AI_LEVEL|white|" + (string)gWhiteAILevel, NULL_KEY);
            }
            else if (stateType == "BLACK_AI_LEVEL") {
                AI_BLACK_LEVEL = (integer)stateValue;
                gBlackAILevel = AI_BLACK_LEVEL;
                // Forward to Brain
                llMessageLinked(LINK_SET, 0, "SET_AI_LEVEL|black|" + (string)gBlackAILevel, NULL_KEY);
            }
            return;
        }
        else if (command == "SET_AI_LEVEL") {
            string player = llList2String(params, 1);
            integer level = llList2Integer(params, 2);
            
            if (player == "white") {
                gWhiteAILevel = level;
                if (DEBUG_MODE) llOwnerSay("DEBUG AI: White AI Level set to " + (string)level);
            } else if (player == "black") {
                gBlackAILevel = level;
                if (DEBUG_MODE) llOwnerSay("DEBUG AI: Black AI Level set to " + (string)level);
            }
        }
        else if (command == "SET_PLAYER_KEYS") {
            white = (key)llList2String(params, 1);
            black = (key)llList2String(params, 2);
        }
        else if (command == "TRIGGER_AI_TURN") {
            // RACE CONDITION FIX: Clear current move ID
            gCurrentMoveID = "";
            
            currentTurn = llList2String(params, 1);
            currentDie1 = llList2Integer(params, 2);
            currentDie2 = llList2Integer(params, 3);
            isDoubles = llList2Integer(params, 4);
            movesLeft = llList2Integer(params, 5);
            
            // Only process if we control this player
            if ((currentTurn == "white" && AI_WHITE_CONTROLLED) || 
                (currentTurn == "black" && AI_BLACK_CONTROLLED)) {
                
                if (DEBUG_MODE) llOwnerSay("DEBUG AI: Processing AI turn for " + currentTurn);
                
                // Transition to REQUESTING_BOARD state
                gAIState = AI_STATE_REQUESTING_BOARD;
                llMessageLinked(LINK_SET, 0, "REQUEST_BOARD_STATE", NULL_KEY);
            }
        }
        else if (command == "FRESH_BOARD_STATE") {
            if (gAIState == AI_STATE_REQUESTING_BOARD) {
                if (DEBUG_MODE) llOwnerSay("DEBUG AI: Received FRESH_BOARD_STATE, syncing Brain");
                
                // 1. Sync Brain with new board
                string syncMsg = "SYNC_BOARD" + llGetSubString(str, 17, -1); 
                llMessageLinked(LINK_SET, 0, syncMsg, NULL_KEY);
                
                // 2. Trigger Brain to Think
                gAIState = AI_STATE_THINKING;
                
                // Determine correct level for this turn
                integer currentLevel = gWhiteAILevel;
                if (currentTurn == "black") currentLevel = gBlackAILevel;
                
                string thinkMsg = "AI_THINK|" + currentTurn + "|" + (string)currentDie1 + "|" + 
                                  (string)currentDie2 + "|" + (string)isDoubles + "|" + (string)movesLeft + "|" + (string)currentLevel;
                llMessageLinked(LINK_SET, 0, thinkMsg, NULL_KEY);
            }
        }
        else if (command == "AI_DECISION") {
            if (gAIState == AI_STATE_THINKING) {
                string move = llDumpList2String(llList2List(params, 1, -1), "|");
                
                if (move == "NO_MOVE") {
                    if (DEBUG_MODE) llOwnerSay("DEBUG AI: Brain returned NO_MOVE");
                    gAIState = AI_STATE_IDLE;
                    llMessageLinked(LINK_SET, 0, "AI_NO_MOVES|" + currentTurn, NULL_KEY);
                } else {
                    if (DEBUG_MODE) llOwnerSay("DEBUG AI: Brain returned move: " + move);
                    
                    // Add Move ID
                    gCurrentMoveID = (string)((integer)llFrand(1000000));
                    move += "|" + gCurrentMoveID;
                    
                    gAIState = AI_STATE_MOVE_SENT;
                    llMessageLinked(LINK_SET, 0, move, NULL_KEY);
                }
            }
        }
        else if (command == "MOVE_ACKNOWLEDGED") {
            string moveID = llList2String(params, 1);
            if (moveID == gCurrentMoveID) {
                if (gAIState == AI_STATE_MOVE_SENT) {
                    if (DEBUG_MODE) llOwnerSay("DEBUG AI: Move acknowledged");
                    gAIState = AI_STATE_IDLE;
                    gCurrentMoveID = "";
                }
            }
        }
    }    
}
