// BACKGAMMON MENU - Menu and AI control system
integer DEBUG_MODE = FALSE;

// Menu system
integer menu_listener;
integer menu_channel;
key menu_user;
integer menu_timeout = 30;

// AI Control
integer AI_LEVEL = 0;
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
integer MASTER_AI_LEVEL = 1;


// Broadcast master state to all scripts
broadcastControlState() {
    if (DEBUG_MODE) llOwnerSay("CONTROLLER: Broadcasting control state to all scripts");
    
    llMessageLinked(LINK_SET, 0, "CONTROL_STATE|SIMULATING|" + (string)MASTER_SIMULATING, NULL_KEY);
    llMessageLinked(LINK_SET, 0, "CONTROL_STATE|WHITE_AI|" + (string)MASTER_WHITE_AI, NULL_KEY);
    llMessageLinked(LINK_SET, 0, "CONTROL_STATE|BLACK_AI|" + (string)MASTER_BLACK_AI, NULL_KEY);
    llMessageLinked(LINK_SET, 0, "CONTROL_STATE|AI_LEVEL|" + (string)MASTER_AI_LEVEL, NULL_KEY);

}

// Reset entire system to known state
masterReset() {
    if (DEBUG_MODE) llOwnerSay("CONTROLLER: Master reset initiated");
    
    MASTER_SIMULATING = FALSE;
    MASTER_WHITE_AI = FALSE;
    MASTER_BLACK_AI = FALSE;
    MASTER_AI_LEVEL = 1;

    
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

showMainMenu(key user) {
    menu_user = user;
    
    string aiLevelText = "Off";
    if (AI_LEVEL == 1) aiLevelText = "Beginner";
    else if (AI_LEVEL == 2) aiLevelText = "Intermediate"; 
    else if (AI_LEVEL == 3) aiLevelText = "Advanced";
    
    string aiControlText = "Humans: Both";
    if (whitePlayer == NULL_KEY && blackPlayer == NULL_KEY) {
        aiControlText = "AI: Both";
    } else if (whitePlayer == NULL_KEY) {
        aiControlText = "AI: White";
    } else if (blackPlayer == NULL_KEY) {
        aiControlText = "AI: Black";
    }
    
    menu_channel = (integer)(llFrand(99999.0) * -1);
    menu_listener = llListen(menu_channel, "", user, "");
    
    string menuText = "Backgammon Menu\nTurn: " + currentTurn;
    menuText = menuText + "\nDice: " + (string)currentDie1 + "," + (string)currentDie2;
    menuText = menuText + "\nAI: " + aiLevelText;
    menuText = menuText + "\nControl: " + aiControlText;
    
    list buttons = ["Reset", "AI Level", "AI Control", "Cancel"];
    
    llDialog(user, menuText, buttons, menu_channel);
    llSetTimerEvent(menu_timeout);
}

showAILevelMenu() {
    menu_channel = (integer)(llFrand(99999.0) * -1);
    menu_listener = llListen(menu_channel, "", menu_user, "");
    llDialog(menu_user, "Select AI Level:", 
             ["AI: Off", "AI: Beginner", "AI: Intermediate", "AI: Advanced", "Back"], menu_channel);
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
        
        if (simulating) {
            llOwnerSay("DEBUG: In simulating branch for Both AI");
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
            
            llOwnerSay("DEBUG: Both players set to AI - UI keys should be NULL");
            
            // Auto-start the game for AI vs AI
            llSleep(2.0);
            llMessageLinked(LINK_SET, 0, "START_FIRST_ROLL", NULL_KEY);
        } else {
            llOwnerSay("DEBUG: In non-simulating branch for Both AI");
            
            // Update menu state
            whitePlayer = NULL_KEY;
            blackPlayer = NULL_KEY;
            
            // Send SET_PLAYER_KEYS to update UI script's player keys
            llOwnerSay("DEBUG: Sending SET_PLAYER_KEYS to UI (non-simulating)");
            llMessageLinked(LINK_SET, 0, "SET_PLAYER_KEYS|" + (string)NULL_KEY + "|" + (string)NULL_KEY, NULL_KEY);
            
            // Update core with AI players
            llMessageLinked(LINK_SET, 0, "PLAYER_JOIN|white|" + (string)NULL_KEY, NULL_KEY);
            llMessageLinked(LINK_SET, 0, "PLAYER_JOIN|black|" + (string)NULL_KEY, NULL_KEY);
            
            // Update menu state
            llMessageLinked(LINK_SET, 0, "UPDATE_GAME_STATE|" + currentTurn + "|" + (string)currentDie1 + "|" + (string)currentDie2 + "|" + (string)NULL_KEY + "|" + (string)NULL_KEY + "|" + (string)simulating, NULL_KEY);
            
            llRegionSayTo(menu_user, 0, "Both set to AI");
            
            // Auto-start the game for AI vs AI
            llSleep(2.0);
            llMessageLinked(LINK_SET, 0, "START_FIRST_ROLL", NULL_KEY);
            
            llOwnerSay("DEBUG: Both players set to AI in non-simulating mode");
        }
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
    
    // Close menu cleanly for Both AI (game auto-starts)
    // Reopen menu for other options where user may want to continue
    if (message != "Both AI") {
        showMainMenu(menu_user);
    } else {
        llListenRemove(menu_listener);
        llSetTimerEvent(0.0);
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
        showAILevelMenu();
    }
    else if (message == "AI Control") {
        showAIControlMenu();
    }

    else if (message == "AI: Off") {
        AI_LEVEL = 0;
        MASTER_AI_LEVEL = 0;
        broadcastControlState();
        llMessageLinked(LINK_SET, 0, "SET_AI_LEVEL|0", NULL_KEY);
        llRegionSayTo(menu_user, 0, "AI disabled");
        showMainMenu(menu_user);
    }
    else if (message == "AI: Beginner") {
        AI_LEVEL = 1;
        MASTER_AI_LEVEL = 1;
        broadcastControlState();
        llMessageLinked(LINK_SET, 0, "SET_AI_LEVEL|1", NULL_KEY);
        llRegionSayTo(menu_user, 0, "AI set to Beginner level");
        showMainMenu(menu_user);
    }
    else if (message == "AI: Intermediate") {
        AI_LEVEL = 2;
        MASTER_AI_LEVEL = 2;
        broadcastControlState();
        llMessageLinked(LINK_SET, 0, "SET_AI_LEVEL|2", NULL_KEY);
        llRegionSayTo(menu_user, 0, "AI set to Intermediate level");
        showMainMenu(menu_user);
    }
    else if (message == "AI: Advanced") {
        AI_LEVEL = 3;
        MASTER_AI_LEVEL = 3;
        broadcastControlState();
        llMessageLinked(LINK_SET, 0, "SET_AI_LEVEL|3", NULL_KEY);
        llRegionSayTo(menu_user, 0, "AI set to Advanced level");
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
                    if (AI_LEVEL > 0) {
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

