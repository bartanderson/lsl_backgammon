// BACKGAMMON MENU - Menu and AI control system
integer DEBUG_MODE = FALSE;

// Menu system
integer menu_listener;
integer menu_channel;
key menu_user;
integer menu_timeout = 30;
string gMenuContext = ""; // Tracks "white", "black", or "both" for level setting

// AI Control
integer WHITE_AI_LEVEL = 1;
integer BLACK_AI_LEVEL = 1;
integer gWhiteAI = FALSE;
integer gBlackAI = FALSE;

// Pause system removed - unnecessary for turn-based game

// Game state from UI
string currentTurn = "";
integer currentDie1 = 0;
integer currentDie2 = 0;
integer simulating = FALSE;
key whitePlayer = NULL_KEY;
key blackPlayer = NULL_KEY;

// MASTER CONTROL STATE - Only this script owns these
integer MASTER_SIMULATING = FALSE;
integer MASTER_WHITE_AI = FALSE;
integer MASTER_BLACK_AI = FALSE;
integer MASTER_WHITE_AI_LEVEL = 1;
integer MASTER_BLACK_AI_LEVEL = 1;


// Broadcast master state to all scripts
broadcastControlState() {
    if (DEBUG_MODE) llOwnerSay("CONTROLLER: Broadcasting control state to all scripts");
    
    llMessageLinked(LINK_SET, 0, "CONTROL_STATE|SIMULATING|" + (string)MASTER_SIMULATING, NULL_KEY);
    llMessageLinked(LINK_SET, 0, "CONTROL_STATE|WHITE_AI|" + (string)MASTER_WHITE_AI, NULL_KEY);
    llMessageLinked(LINK_SET, 0, "CONTROL_STATE|BLACK_AI|" + (string)MASTER_BLACK_AI, NULL_KEY);
    llMessageLinked(LINK_SET, 0, "CONTROL_STATE|WHITE_AI_LEVEL|" + (string)MASTER_WHITE_AI_LEVEL, NULL_KEY);
    llMessageLinked(LINK_SET, 0, "CONTROL_STATE|BLACK_AI_LEVEL|" + (string)MASTER_BLACK_AI_LEVEL, NULL_KEY);

}

// Reset entire system to known state
masterReset() {
    if (DEBUG_MODE) llOwnerSay("CONTROLLER: Master reset initiated");
    
    MASTER_SIMULATING = FALSE;
    MASTER_WHITE_AI = FALSE;
    MASTER_BLACK_AI = FALSE;
    MASTER_WHITE_AI_LEVEL = 1;
    MASTER_BLACK_AI_LEVEL = 1;

    
    // Broadcast reset state
    broadcastControlState();
    
    // Reset the actual game
    llSleep(1.0);
    llMessageLinked(LINK_SET, 0, "RESET_GAME", NULL_KEY);
}

// Set simulating mode (AI vs AI)
setSimulatingMode(integer enable) {
    MASTER_SIMULATING = enable;
    if (enable) {
        MASTER_WHITE_AI = TRUE;
        MASTER_BLACK_AI = TRUE;
    }
    broadcastControlState();
}

string getLevelName(integer level) {
    if (level == 0) return "Off";
    if (level == 1) return "Beginner";
    if (level == 2) return "Intermediate";
    if (level == 3) return "Advanced";
    return "Unknown";
}


startAIGame() {
    llRegionSayTo(menu_user, 0, "Starting AI vs AI game...");
    
    // Ensure simulating mode is ON
    setSimulatingMode(TRUE);
    gWhiteAI = TRUE;
    gBlackAI = TRUE;
    
    // Update menu state
    whitePlayer = NULL_KEY;
    blackPlayer = NULL_KEY;
    
    llOwnerSay("DEBUG: Sending SET_PLAYER_KEYS to UI");
    llMessageLinked(LINK_SET, 0, "SET_PLAYER_KEYS|" + (string)NULL_KEY + "|" + (string)NULL_KEY, NULL_KEY);
    
    // Update core with AI players
    llMessageLinked(LINK_SET, 0, "PLAYER_JOIN|white|" + (string)NULL_KEY, NULL_KEY);
    llMessageLinked(LINK_SET, 0, "PLAYER_JOIN|black|" + (string)NULL_KEY, NULL_KEY);
    
    // Update menu state
    llMessageLinked(LINK_SET, 0, "UPDATE_GAME_STATE|" + currentTurn + "|" + (string)currentDie1 + "|" + (string)currentDie2 + "|" + (string)NULL_KEY + "|" + (string)NULL_KEY + "|" + (string)simulating, NULL_KEY);
    
    // Auto-start the game for AI vs AI
    llSleep(2.0);
    llMessageLinked(LINK_SET, 0, "START_FIRST_ROLL", NULL_KEY);
}

showMainMenu(key user) {
    menu_user = user;
    
    string aiControlText = "Humans: Both";
    if (MASTER_WHITE_AI && MASTER_BLACK_AI) {
        aiControlText = "AI: Both";
    } else if (MASTER_WHITE_AI) {
        aiControlText = "AI: White";
    } else if (MASTER_BLACK_AI) {
        aiControlText = "AI: Black";
    }
    
    menu_channel = (integer)(llFrand(99999.0) * -1);
    menu_listener = llListen(menu_channel, "", user, "");
    
    string menuText = "Backgammon Menu\nTurn: " + currentTurn;
    menuText = menuText + "\nDice: " + (string)currentDie1 + "," + (string)currentDie2;
    menuText = menuText + "\nControl: " + aiControlText;
    
    // Show AI levels ONLY if that specific AI is active
    if (MASTER_WHITE_AI) {
        menuText += "\nWhite AI: " + getLevelName(WHITE_AI_LEVEL);
    }
    if (MASTER_BLACK_AI) {
        menuText += "\nBlack AI: " + getLevelName(BLACK_AI_LEVEL);
    }
    
    list buttons = ["AI Control", "Reset", "Cancel"];
    
    llDialog(user, menuText, buttons, menu_channel);
    llSetTimerEvent(menu_timeout);
}

showAILevelMenu(string context) {
    gMenuContext = context;
    menu_channel = (integer)(llFrand(99999.0) * -1);
    menu_listener = llListen(menu_channel, "", menu_user, "");
    
    string prompt = "Select AI Level:";
    if (context == "white") {
        prompt = "White AI Level:";
    } else if (context == "black") {
        prompt = "Black AI Level:";
    } else if (context == "both") {
        prompt = "Both AI Level:";
    }
    
    list buttons = ["Beginner", "Intermediate", "Advanced", "Back"];
    if (context == "both") {
        buttons = ["Beginner", "Intermediate", "Advanced", "Different Levels", "Back"];
    }
    
    llDialog(menu_user, prompt, buttons, menu_channel);
}

showDifferentLevelsMenu() {
    menu_channel = (integer)(llFrand(99999.0) * -1);
    menu_listener = llListen(menu_channel, "", menu_user, "");
    
    string prompt = "Set Levels Separately";
    prompt += "\nWhite: " + getLevelName(WHITE_AI_LEVEL);
    prompt += "\nBlack: " + getLevelName(BLACK_AI_LEVEL);
    
    llDialog(menu_user, prompt,
             ["White Level", "Black Level", "Start Game", "Back"],
             menu_channel);
}

showAIControlMenu() {
    string whiteStatus = "Human";
    if (whitePlayer == NULL_KEY) {
        whiteStatus = "AI";
    }
    string blackStatus = "Human";
    if (blackPlayer == NULL_KEY) {
        blackStatus = "AI";
    }
    
    menu_channel = (integer)(llFrand(99999.0) * -1);
    menu_listener = llListen(menu_channel, "", menu_user, "");
    
    string menuText = "AI Control\nWhite: " + whiteStatus + "\nBlack: " + blackStatus;
    llDialog(menu_user, menuText, 
             ["Both Human", "Both AI", "White AI", "Black AI", "Back"], menu_channel);
}

// showPauseMenu removed - pause functionality eliminated

handleAIControlResponse(string message) {
    llOwnerSay("DEBUG: handleAIControlResponse: " + message + ", simulating: " + (string)simulating);
    
    if (message == "Both Human") {
        setSimulatingMode(FALSE);
        MASTER_WHITE_AI = FALSE;
        MASTER_BLACK_AI = FALSE;
        broadcastControlState();
        
        if (simulating) {
            gWhiteAI = FALSE;
            gBlackAI = FALSE;
            llRegionSayTo(menu_user, 0, "You play both sides");
        } else {
            llMessageLinked(LINK_SET, 0, "PLAYER_LEAVE|white", NULL_KEY);
            llMessageLinked(LINK_SET, 0, "PLAYER_LEAVE|black", NULL_KEY);
            llRegionSayTo(menu_user, 0, "Both set to Human - please sit");
        }
    }
    else if (message == "Both AI") {
        setSimulatingMode(TRUE);
        llRegionSayTo(menu_user, 0, "AI vs AI mode activated");
        
        setSimulatingMode(TRUE);
        // Don't start yet - ask for levels first
        showAILevelMenu("both");
    }
    else if (message == "White AI") {
        MASTER_WHITE_AI = TRUE;
        broadcastControlState();
        
        if (simulating) {
            gWhiteAI = TRUE;
            gBlackAI = FALSE;
            llRegionSayTo(menu_user, 0, "White set to AI, you are playing Black");
            
            if (currentTurn == "white") {
                llMessageLinked(LINK_SET, 0, "TRIGGER_AI_NOW", NULL_KEY);
            }
        } else {
            llMessageLinked(LINK_SET, 0, "PLAYER_JOIN|white|" + (string)NULL_KEY, NULL_KEY);
            llRegionSayTo(menu_user, 0, "White set to AI");
        }
    }
    else if (message == "Black AI") {
        MASTER_BLACK_AI = TRUE;
        broadcastControlState();
        
        if (simulating) {
            gWhiteAI = FALSE;
            gBlackAI = TRUE;
            llRegionSayTo(menu_user, 0, "Black set to AI, you are playing White");
            
            if (currentTurn == "black") {
                llMessageLinked(LINK_SET, 0, "TRIGGER_AI_NOW", NULL_KEY);
            }
        } else {
            llMessageLinked(LINK_SET, 0, "PLAYER_JOIN|black|" + (string)NULL_KEY, NULL_KEY);
            llRegionSayTo(menu_user, 0, "Black set to AI");
        }
    }
    else if (message == "Back") {
        showMainMenu(menu_user);
        return;
    }
    
    // Show AI level menu based on selection
    if (message == "Both AI") {
        // Already handled above
    } else if (message == "White AI") {
        // Show White AI level menu
        showAILevelMenu("white");
    } else if (message == "Black AI") {
        // Show Black AI level menu
        showAILevelMenu("black");
    } else if (message == "Both Human") {
        // No AI levels needed
        showMainMenu(menu_user);
    }
}

// handlePauseMenuResponse removed - pause functionality eliminated

handleMenuResponse(string message) {
    llListenRemove(menu_listener);
    llSetTimerEvent(0.0);
    
    if (message == "Reset") {
        masterReset();
        llRegionSayTo(menu_user, 0, "Game resetting...");
        return;
    }
    else if (message == "Save") {
        llMessageLinked(LINK_SET, 0, "SAVE_GAME_REQUEST", NULL_KEY);
    }
    else if (message == "Load") {
        menu_channel = 0;
        menu_listener = llListen(menu_channel, "", menu_user, "");
        llRegionSayTo(menu_user, 0, "Please type: /loadgame [SAVE_CODE]");
        llRegionSayTo(menu_user, 0, "Or paste the entire save code in chat.");
        llSetTimerEvent(60.0);
    }
    else if (message == "AI Level") {
        // Deprecated button, but if hit, show for both? 
        // Or just remove this block if button is gone.
        // Keeping for safety, default to both
        showAILevelMenu("both");
    }
    else if (message == "AI Control") {
        showAIControlMenu();
    }
    
    // Level Selection Handlers
    else if (message == "Beginner" || message == "Intermediate" || message == "Advanced") {
        integer newLevel = 1;
        if (message == "Intermediate") newLevel = 2;
        if (message == "Advanced") newLevel = 3;
        
        if (gMenuContext == "white" || gMenuContext == "both") {
            WHITE_AI_LEVEL = newLevel;
            MASTER_WHITE_AI_LEVEL = newLevel;
            llMessageLinked(LINK_SET, 0, "SET_AI_LEVEL|white|" + (string)newLevel, NULL_KEY);
            llRegionSayTo(menu_user, 0, "White AI set to " + message);
        }
        
        if (gMenuContext == "black" || gMenuContext == "both") {
            BLACK_AI_LEVEL = newLevel;
            MASTER_BLACK_AI_LEVEL = newLevel;
            llMessageLinked(LINK_SET, 0, "SET_AI_LEVEL|black|" + (string)newLevel, NULL_KEY);
            llRegionSayTo(menu_user, 0, "Black AI set to " + message);
        }
        
        broadcastControlState();
        
        if (MASTER_SIMULATING) {
            if (gMenuContext == "both") {
                // "Both AI" mode, simple selection -> Start
                startAIGame();
            } else {
                // "Different Levels" flow in AI vs AI
                showDifferentLevelsMenu();
            }
        }
        else {
            // Human vs AI mode - just return to main menu
            showMainMenu(menu_user);
        }
    }
    else if (message == "Different Levels") {
        showDifferentLevelsMenu();
    }
    else if (message == "White Level") {
        showAILevelMenu("white");
    }
    else if (message == "Black Level") {
        showAILevelMenu("black");
    }
    else if (message == "Start Game") {
        startAIGame();
    }
    
    // Legacy handlers removal (AI: Off etc) - replaced by above generic handler
    else if (message == "AI: Off") {
        // ... legacy code removal ...
        WHITE_AI_LEVEL = 0; BLACK_AI_LEVEL = 0;
        MASTER_WHITE_AI_LEVEL = 0; MASTER_BLACK_AI_LEVEL = 0;
        broadcastControlState();
        llMessageLinked(LINK_SET, 0, "SET_AI_LEVEL|white|0", NULL_KEY);
        llMessageLinked(LINK_SET, 0, "SET_AI_LEVEL|black|0", NULL_KEY);
        showMainMenu(menu_user);
    }
    else if (message == "Cancel") {
        return;
    }
    else {
        showMainMenu(menu_user);
    }
    
    if (message != "Cancel") {
        llSetTimerEvent(menu_timeout);
    }
}

default {
    state_entry() {
        if (DEBUG_MODE) {
            llOwnerSay("Menu system ready - MASTER CONTROLLER");
        }
        // Initialize control state
        broadcastControlState();
    }
    
    listen(integer channel, string name, key id, string message) {
        if (channel == menu_channel) {
            if (message == "Back") {
                showMainMenu(menu_user);
            }
            else if (message == "Debug Test") {
                llMessageLinked(LINK_SET, 0, "RUN_TESTS", NULL_KEY);
                llRegionSayTo(id, 0, "Starting comprehensive data transfer tests...");
            }
            else if (message == "Run Tests") {
                llMessageLinked(LINK_SET, 0, "RUN_DATA_DRIVEN_TESTS|COMPREHENSIVE_DATA_FLOW", NULL_KEY);
                llRegionSayTo(id, 0, "Starting data-driven comprehensive tests...");
                return;
            }
            else if (llListFindList(["Both Human", "Both AI", "White AI", "Black AI", "Swap"], [message]) != -1) {
                handleAIControlResponse(message);
            }

            else {
                handleMenuResponse(message);
            }
        }
        else if (channel == 0) {
            if (llGetSubString(message, 0, 9) == "/loadgame ") {
                string savedState = llGetSubString(message, 10, -1);
                llMessageLinked(LINK_SET, 0, "LOAD_GAME_STATE|" + savedState, NULL_KEY);
                llRegionSayTo(menu_user, 0, "Loading game state...");
                llListenRemove(menu_listener);
                llSetTimerEvent(0.0);
            }
            else if (llGetSubString(message, 0, 13) == "GAME_FRAGMENTS:") {
                llMessageLinked(LINK_SET, 0, "LOAD_GAME_STATE|" + message, NULL_KEY);
                llRegionSayTo(menu_user, 0, "Loading game state...");
                llListenRemove(menu_listener);
                llSetTimerEvent(0.0);
            }
        }
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list params = llParseString2List(str, ["|"], []);
        string command = llList2String(params, 0);
        
        if (command == "SHOW_MAIN_MENU") {
            menu_user = (key)llList2String(params, 1);
            showMainMenu(menu_user);
        }
        else if (command == "UPDATE_GAME_STATE") {
            currentTurn = llList2String(params, 1);
            currentDie1 = llList2Integer(params, 2);
            currentDie2 = llList2Integer(params, 3);
            whitePlayer = (key)llList2String(params, 4);
            blackPlayer = (key)llList2String(params, 5);
            simulating = llList2Integer(params, 6);
        }
        else if (command == "CHECK_AI_FOR_TURN") {
            string checkTurn = llList2String(params, 1);
            
            if (simulating) {
                if ((checkTurn == "white" && gWhiteAI) || (checkTurn == "black" && gBlackAI)) {
                    integer currentLevel = 0;
                    if (checkTurn == "white") currentLevel = WHITE_AI_LEVEL;
                    else if (checkTurn == "black") currentLevel = BLACK_AI_LEVEL;
                    
                    if (currentLevel > 0) {
                        llSleep(2.0);
                        llMessageLinked(LINK_SET, 0, "AI_REQUEST_MOVE", NULL_KEY);
                    }
                }
            }
        }
        else if (command == "CHECK_PAUSE_STATE") {
            if ((currentTurn == "white" && (whitePlayer == NULL_KEY || gWhiteAI)) || 
                (currentTurn == "black" && (blackPlayer == NULL_KEY || gBlackAI))) {
                llSleep(2.0);
                llMessageLinked(LINK_SET, 0, "AI_REQUEST_MOVE", NULL_KEY);
            }
        }
    }
    
    timer() {
        llSetTimerEvent(0.0);
        llListenRemove(menu_listener);
        if (menu_user != NULL_KEY) {
            llRegionSayTo(menu_user, 0, "Menu timed out.");
        }
    }
}

