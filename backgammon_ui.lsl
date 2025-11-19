// BACKGAMMON UI - Clean user interface
integer DEBUG_MODE = TRUE;

// Game state
integer simulating = FALSE;
integer isDoubles = FALSE;
integer movesLeft = 0;
integer gDiceAnimation = FALSE;

key white = NULL_KEY; 
key black = NULL_KEY;
string turn = "";
list pointUVs = [];
integer pieceSelected = FALSE;
integer selectedPoint = -1;
key selectedPlayer = NULL_KEY;
list validMoves = [];
integer currentDie1 = 0;
integer currentDie2 = 0;

// CONTROL STATE from Menu
integer UI_SIMULATING = FALSE;

// State Constants
integer gCurrentState = 0;
integer STATE_RESET = 0;
integer STATE_FIRST_ROLL = 1;
integer STATE_MAIN_GAME = 2;
integer STATE_GAME_OVER = 3;

// Movement constants
integer BEAR_OFF = -1;
integer FROM_BAR = -2;

// Board geometry
integer BOARD_SIZE = 24;

// Essential functions
integer GetLinkNumber(string linkName) {
    integer x; 
    integer numprims = llGetNumberOfPrims();
    for(x = 1; x <= numprims; x = x + 1) {
        if(linkName == llGetLinkName(x)) return x;
    }
    return 0;
}

setUpDie(string name) {
    integer n = GetLinkNumber(name);
    string tex;
    string wtex = "2c044d5a-0d84-4104-8877-626404c97e71";
    string btex = "e798a047-17da-74ef-953e-a760ffe0d74d";
    if(llGetSubString(name, 0, 0) == "b") tex = btex;
    else if(llGetSubString(name, 0, 0) == "w") tex = wtex;
    
    llSetLinkPrimitiveParamsFast(n, [PRIM_TEXTURE, 0, tex, <.15, .9, 0>, <.585, .01, 0>, 0]);
    llSetLinkPrimitiveParamsFast(n, [PRIM_TEXTURE, 1, tex, <.15, .9, 0>, <.745, .01, 0>, 0]);
    llSetLinkPrimitiveParamsFast(n, [PRIM_TEXTURE, 3, tex, <.15, .9, 0>, <.915, .01, 0>, 0]);
    llSetLinkPrimitiveParamsFast(n, [PRIM_TEXTURE, 4, tex, <.15, .9, 0>, <.080, .01, 0>, 0]);
    llSetLinkPrimitiveParamsFast(n, [PRIM_TEXTURE, 5, tex, <.15, .9, 0>, <.245, .01, 0>, 0]);
    llSetLinkPrimitiveParamsFast(n, [PRIM_TEXTURE, 2, tex, <.15, .8, 0>, <.412, .01, 0>, 0]);
}

integer isPlayerAllowed(key avatar, string requestedColor) {
    // Always allow in simulation mode (both players NULL)
    if (white == NULL_KEY && black == NULL_KEY) {
        return (avatar == llGetOwner());
    }
    
    // Normal mode: check against stored player keys
    if (requestedColor == "white") {
        return (avatar == white);
    } else if (requestedColor == "black") {
        return (avatar == black);
    }
    
    return FALSE;
}

setDieOrientation(string name, integer value) {
    integer n = GetLinkNumber(name);
    if (n == 0) return;
    
    rotation targetRot;
    
    if (value == 1) targetRot = <0.00000, 0.00000, 0.00000, 1.00000>;
    else if (value == 2) targetRot = <-0.70711, -0.00000, 0.00000, 0.70711>;
    else if (value == 3) targetRot = <0.70711, 0.00000, 0.00000, 0.70711>;
    else if (value == 4) targetRot = <0.00000, 0.70711, 0.00000, 0.70711>;
    else if (value == 5) targetRot = <1.00000, 0.00000, 0.00000, 0.00000>;
    else if (value == 6) targetRot = <0.00000, -0.70711, 0.00000, 0.70711>;
    else targetRot = ZERO_ROTATION;

    llSetLinkPrimitiveParamsFast(n, [PRIM_ROT_LOCAL, targetRot]);   
    llSetLinkPrimitiveParamsFast(n, [PRIM_ROT_LOCAL, targetRot]);   
    llSetLinkPrimitiveParamsFast(n, [PRIM_ROT_LOCAL, targetRot]);   
    llSetLinkPrimitiveParamsFast(n, [PRIM_ROT_LOCAL, targetRot]);   
}

animateDieRoll(string name, integer finalValue) {
    if (!gDiceAnimation) {
        setDieOrientation(name, finalValue);
        return;
    }
    
    integer n = GetLinkNumber(name);
    if (n == 0) return;
    
    llSetLinkPrimitiveParamsFast(n, [
        PRIM_OMEGA, <1, 1, 1>, PI, 1.0
    ]);
    
    integer i;
    for(i = 0; i < 8; i = i + 1) {
        integer tempValue = (integer)llFrand(6) + 1;
        
        rotation tempRot;
        if (tempValue == 1) tempRot = <0.00000, 0.00000, 0.00000, 1.00000>;
        else if (tempValue == 2) tempRot = <-0.70711, -0.00000, 0.00000,0.00000>;
        else if (tempValue == 3) tempRot = <0.00000, -0.70711, 0.00000, 0.00000>;
        else if (tempValue == 4) tempRot = <0.00000, 0.70711, 0.00000, 0.00000>;
        else if (tempValue == 5) tempRot = <0.70711, 0.00000, 0.00000, 0.00000>;
        else if (tempValue == 6) tempRot = <1.00000, 0.00000, 0.00000, 0.00000>;
        else tempRot = ZERO_ROTATION;
        
        llSetLinkPrimitiveParamsFast(n, [PRIM_ROT_LOCAL, tempRot]);
        llSleep(0.1);
    }
    
    llSetLinkPrimitiveParamsFast(n, [PRIM_OMEGA, <0, 0, 0>, 0, 0]);
    llSetLinkPrimitiveParamsFast(n, [PRIM_OMEGA, <0, 0, 0>, 0, 0]);
    
    setDieOrientation(name, finalValue);
}

animateDiceRoll(string player, integer die1, integer die2) {
    if (player == "white") {
        animateDieRoll("wdie1", die1);
        animateDieRoll("wdie2", die2);
    } else {
        animateDieRoll("bdie1", die1);
        animateDieRoll("bdie2", die2);
    }
}

ResetSeatedPlayers() {
    integer i;
    for(i = 1; i <= llGetNumberOfPrims(); i = i + 1) {
        if(llGetAgentSize(llGetLinkKey(i)) != ZERO_VECTOR) {
            vector main = llList2Vector(llGetLinkPrimitiveParams(GetLinkNumber("Backgammon"), [PRIM_POSITION]), 0);
            vector someplayer = llList2Vector(llGetLinkPrimitiveParams(i, [PRIM_POSITION]), 0);
            
            if(someplayer.y - main.y > .5) {
                llMessageLinked(LINK_ROOT, 0, "PLAYER_JOIN|white|" + (string)llGetLinkKey(i), NULL_KEY);
            }
            else if(someplayer.y - main.y < -.5) {
                llMessageLinked(LINK_ROOT, 0, "PLAYER_JOIN|black|" + (string)llGetLinkKey(i), NULL_KEY);
            }
        }
    }
}

integer GetAgentLinkNumber(key avatar) {
    integer linkNum = 1 + llGetNumberOfPrims();
    key linkKey;
    while((linkKey = llGetLinkKey(--linkNum))) {
        if(avatar == linkKey) return linkNum;
    }
    return 0x7FFFFFFF;
}

sendMessage(string message) {
    if (white != NULL_KEY) llRegionSayTo(white, 0, message);
    if (black != NULL_KEY) llRegionSayTo(black, 0, message);
    if (white == NULL_KEY && black == NULL_KEY) llOwnerSay(message);
}

initPointUVs() {
    float rightEdge = 0.991;
    float rightBar = 0.553;
    float leftBar = 0.445;
    float leftEdge = 0.006;
    
    pointUVs = [];
    
    float rightSegment = (rightEdge - rightBar) / 6;
    integer i;
    for(i = 0; i < 6; i = i + 1) {
        float center = rightEdge - (i * rightSegment) - (rightSegment / 2);
        pointUVs = pointUVs + center;
    }
    
    float leftSegment = (leftBar - leftEdge) / 6;
    for(i = 0; i < 6; i = i + 1) {
        float center = leftBar - (i * leftSegment) - (leftSegment / 2);
        pointUVs = pointUVs + center;
    }
    
    for(i = 11; i >= 0; i = i - 1) {
        pointUVs = pointUVs + llList2Float(pointUVs, i);
    }
}

integer findClosestPoint(vector touchUV) {
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG: Finding closest point for UV: " + (string)touchUV);
    }
    integer closestPoint = -1;
    float minDistance = 0.1;
    
    integer isTopHalf = (touchUV.y < 0.5);
    
    integer i;
    for(i = 0; i < 24; i = i + 1) {
        float pointU = llList2Float(pointUVs, i);
        float distance = llFabs(touchUV.x - pointU);
        
        if ((isTopHalf && i >= 12) || (!isTopHalf && i < 12)) {
            if(distance < minDistance) {
                minDistance = distance;
                closestPoint = i;
            }
        }
    }
    
    return closestPoint;
}

resetUIState() {
    gCurrentState = STATE_RESET;
    turn = "";
    currentDie1 = 0;
    currentDie2 = 0;
    isDoubles = FALSE;
    movesLeft = 0;
    pieceSelected = FALSE;
    selectedPoint = -1;
    selectedPlayer = NULL_KEY;
    validMoves = [];
    
    white = NULL_KEY;
    black = NULL_KEY;
    simulating = FALSE;
    
    setDieOrientation("wdie1", 1);
    setDieOrientation("wdie2", 1);
    setDieOrientation("bdie1", 1);
    setDieOrientation("bdie2", 1);
    
    llMessageLinked(LINK_SET, 0, "HIDE_MARKER|1", NULL_KEY);
    llOwnerSay("DEBUG: UI Reset Complete - State: " + (string)gCurrentState + ", Turn: '" + turn + "'");
}

default {
    state_entry() {
        setUpDie("wdie1");
        setUpDie("wdie2");
        setUpDie("bdie1");
        setUpDie("bdie2");
        
        setDieOrientation("wdie1", 1);
        setDieOrientation("wdie2", 1);
        setDieOrientation("bdie1", 1);
        setDieOrientation("bdie2", 1);
        
        ResetSeatedPlayers();
        initPointUVs();
    }
    
    changed(integer change) {
        if (change & CHANGED_LINK) {
            key av = llAvatarOnSitTarget();
            if (av != NULL_KEY) {
                integer linkNum = GetAgentLinkNumber(av);
                string linkName = llGetLinkName(linkNum);
                
                if (linkName == "white" && white == NULL_KEY) {
                    white = av;
                    llMessageLinked(LINK_ROOT, 0, "PLAYER_JOIN|white|" + (string)av, NULL_KEY);
                    sendMessage(llKey2Name(av) + " is playing white.");
                    simulating = FALSE;
                }
                else if (linkName == "black" && black == NULL_KEY) {
                    black = av;
                    llMessageLinked(LINK_ROOT, 0, "PLAYER_JOIN|black|" + (string)av, NULL_KEY);
                    sendMessage(llKey2Name(av) + " is playing black.");
                    simulating = FALSE;
                }
            }
            else {
                if (GetAgentLinkNumber(white) == 0) {
                    llMessageLinked(LINK_ROOT, 0, "PLAYER_LEAVE|white", NULL_KEY);
                    sendMessage("White player left the game.");
                    white = NULL_KEY;
                }
                if (GetAgentLinkNumber(black) == 0) {
                    llMessageLinked(LINK_ROOT, 0, "PLAYER_LEAVE|black", NULL_KEY);
                    sendMessage("Black player left the game.");
                    black = NULL_KEY;
                }
            }
        }
    }
    
    touch_start(integer total_number) {
        // DEBUG: Show current state and turn
        llOwnerSay("DEBUG: Touch detected - State: " + (string)gCurrentState + ", Turn: '" + turn + "'");
        
        integer detLinkNumber = llDetectedLinkNumber(0);
        key detLinkKey = llDetectedKey(0);
        string linkName = llGetLinkName(detLinkNumber);
        
        llOwnerSay("DEBUG: Touched: " + linkName + ", Key: " + (string)detLinkKey);
        
        if (linkName == "MENU") {
            llMessageLinked(LINK_SET, 0, "SHOW_MAIN_MENU|" + (string)detLinkKey, NULL_KEY);
            return;
        }
        
        if (linkName == "Backgammon") {
            if (DEBUG_MODE) llOwnerSay("DEBUG: Board touched, checking pieceSelected state");
            vector touchUV = llDetectedTouchUV(0);
            integer internalPoint = findClosestPoint(touchUV);

            if (DEBUG_MODE) {
                llOwnerSay("DEBUG: Board touched at UV " + (string)touchUV + 
                  ", internal point: " + (string)internalPoint +
                  ", pieceSelected: " + (string)pieceSelected +
                  ", selectedPoint: " + (string)selectedPoint);
            }

            if (DEBUG_MODE && pieceSelected) {
                llOwnerSay("DEBUG: pieceSelected is TRUE - checking keys...");
                llOwnerSay("DEBUG: detLinkKey: " + (string)detLinkKey);
                llOwnerSay("DEBUG: selectedPlayer: " + (string)selectedPlayer);
                llOwnerSay("DEBUG: Keys match: " + (string)(detLinkKey == selectedPlayer));
                llOwnerSay("DEBUG: Current turn: " + turn);
            }
        
            if (pieceSelected) {
                // In simulation mode, allow the move regardless of selectedPlayer match
                integer allowMove = FALSE;
                if (UI_SIMULATING || (white == NULL_KEY && black == NULL_KEY)) {
                    allowMove = TRUE; // Simulation mode - no specific player validation needed
                    if (DEBUG_MODE) llOwnerSay("DEBUG: Simulation mode - move allowed without player key check");
                } else {
                    allowMove = (detLinkKey == selectedPlayer);
                    if (DEBUG_MODE) llOwnerSay("DEBUG: Normal mode - player key match: " + (string)allowMove);
                }
                
                if (allowMove) {
                    if (DEBUG_MODE) {
                        llOwnerSay("DEBUG: Entering pieceSelected move validation");
                        llOwnerSay("DEBUG: selectedPoint: " + (string)selectedPoint + ", turn: " + turn);
                        llOwnerSay("DEBUG: currentDie1: " + (string)currentDie1 + ", currentDie2: " + (string)currentDie2);
                    }
                    if (DEBUG_MODE) {
                        llOwnerSay("DEBUG: Entering move validation - keys match!");
                        llOwnerSay("DEBUG: Moving from " + (string)selectedPoint + " to " + (string)internalPoint);
                    }
                    integer distance;
                    integer direction = 1;
                    if (turn == "black") direction = -1;
                    
                    if (selectedPoint == FROM_BAR) {
                        if (DEBUG_MODE) llOwnerSay("DEBUG: Moving from BAR to point " + (string)internalPoint);
                        if (turn == "white") {
                            distance = internalPoint + 1;
                        } else {
                            distance = 24 - internalPoint;
                        }
                    } else {
                        if (turn == "white") {
                            // White moves from low to high points
                            distance = internalPoint - selectedPoint;
                        } else {
                            // Black moves from high to low points  
                            distance = selectedPoint - internalPoint;
                        }
                        
                        if (DEBUG_MODE) {
                            llOwnerSay("DEBUG: Calculating distance - from " + (string)selectedPoint + 
                                      " to " + (string)internalPoint + 
                                      ", turn: " + turn +
                                      ", distance: " + (string)distance);
                        }
                    }
                    
                    integer die_value = 0;
                    integer moves_used = 1;
                    integer foundValidMove = FALSE;
                    
                    if (isDoubles) {
                        integer dieValue = currentDie1;
                        if (distance == dieValue) {
                            die_value = dieValue;
                            moves_used = 1;
                            foundValidMove = TRUE;
                        } else if (distance == dieValue * 2) {
                            die_value = distance;
                            moves_used = 2;
                            foundValidMove = TRUE;
                        } else if (distance == dieValue * 3) {
                            die_value = distance;
                            moves_used = 3;
                            foundValidMove = TRUE;
                        } else if (distance == dieValue * 4) {
                            die_value = distance;
                            moves_used = 4;
                            foundValidMove = TRUE;
                        }
                    } else {
                        if (currentDie1 > 0 && distance == currentDie1) {
                            die_value = currentDie1;
                            moves_used = 1;
                            foundValidMove = TRUE;
                        } else if (currentDie2 > 0 && distance == currentDie2) {
                            die_value = currentDie2;
                            moves_used = 1;
                            foundValidMove = TRUE;
                        } else if (distance == (currentDie1 + currentDie2) && currentDie1 > 0 && currentDie2 > 0) {
                            die_value = currentDie1 + currentDie2;
                            moves_used = 2;
                            foundValidMove = TRUE;
                        }
                    }
                    
                    if (foundValidMove) {
                        if (DEBUG_MODE) {
                            llOwnerSay("DEBUG: Valid move found - distance: " + (string)distance + 
                                      ", die_value: " + (string)die_value + 
                                      ", moves_used: " + (string)moves_used);
                        }
                        
                        llMessageLinked(LINK_SET, 0, "PLAYER_MOVE|" + turn + "|" + 
                                       (string)selectedPoint + "|" + (string)internalPoint + 
                                       "|" + (string)die_value + "|" + (string)moves_used, NULL_KEY);
                        
                        if (isDoubles) {
                            movesLeft = movesLeft - moves_used;
                            if (movesLeft > 0) {
                                sendMessage("Move completed. " + (string)movesLeft + " moves remaining.");
                            }
                        }
                        
                        llMessageLinked(LINK_SET, 0, "HIDE_MARKER|1", NULL_KEY);
                        pieceSelected = FALSE;
                        selectedPoint = -1;
                        selectedPlayer = NULL_KEY;
                    } else {
                        sendMessage("Invalid move distance " + (string)distance + 
                                   ". Available dice: " + (string)currentDie1 + ", " + (string)currentDie2);
                        if (DEBUG_MODE) {
                            llOwnerSay("DEBUG: Invalid move - distance: " + (string)distance + 
                                      ", currentDie1: " + (string)currentDie1 + 
                                      ", currentDie2: " + (string)currentDie2 +
                                      ", isDoubles: " + (string)isDoubles);
                        }
                    }
                } else {
                    sendMessage("You can only move your own selected pieces.");
                }
                return;
            }
        }        
        if ((llGetSubString(linkName, 0, 0) == "w" || llGetSubString(linkName, 0, 0) == "b") && 
            llSubStringIndex(linkName, "die") == -1) {
            
            string player;
            string pieceColor = llGetSubString(linkName, 0, 0);
            
            if (pieceColor == "w") player = "white";
            else if (pieceColor == "b") player = "black";
            else return;
            
            // FIRST ROLL: No piece selection allowed
            if (gCurrentState == STATE_FIRST_ROLL) {
                sendMessage("Please roll the dice first to determine who starts.");
                return;
            }
            
            // MAIN GAME: Normal turn and permission checks
            if (player != turn) {
                sendMessage("Not your turn.");
                return;
            }
            
            if (currentDie1 == 0 && currentDie2 == 0) {
                sendMessage("You must roll the dice before moving pieces.");
                return;
            }
            
            if (!isPlayerAllowed(detLinkKey, player)) {
                sendMessage("You can only select your own pieces.");
                return;
            }
            
            llMessageLinked(LINK_SET, 0, "GET_PIECE_POSITION|" + linkName + "|" + (string)detLinkKey, NULL_KEY);
            return;
        }
        
        if (linkName == "wdie1" || linkName == "wdie2" || linkName == "bdie1" || linkName == "bdie2") {
            string player;
            string dieColor = llGetSubString(linkName, 0, 0);
            
            if (dieColor == "w") player = "white";
            else if (dieColor == "b") player = "black";
            else return;
            
            llOwnerSay("DEBUG: Dice touched - Player: " + player + ", State: " + (string)gCurrentState + ", Turn: '" + turn + "'");
            
            // TEMPORARY FIX: Allow dice rolling in both RESET and FIRST_ROLL states
            if (gCurrentState == STATE_RESET || gCurrentState == STATE_FIRST_ROLL) {
                llOwnerSay("DEBUG: Allowing roll in reset/first_roll state");
                if (isPlayerAllowed(detLinkKey, player)) {
                    integer die1 = 1 + (integer)llFrand(6);
                    integer die2 = 1 + (integer)llFrand(6);
                    // ANIMATE IMMEDIATELY + send to core only
                    animateDiceRoll(player, die1, die2);
                    llMessageLinked(LINK_SET, 0, "PLAYER_DICE_ROLL|" + player + "|" + (string)die1 + "|" + (string)die2, NULL_KEY);
                }
                return;
            }
            
            // MAIN GAME: Check turn and permissions
            if (player != turn) {
                sendMessage("Not your turn. It's currently " + turn + "'s turn.");
                return;
            }
        
            if (!isPlayerAllowed(detLinkKey, player)) {
                sendMessage("You can only roll for your own color.");
                return;
            }
            
            // Check if already rolled
            if (currentDie1 > 0 || currentDie2 > 0) {
                sendMessage("You've already rolled this turn. Make your moves.");
                return;
            }
            
            // Roll the dice
            integer die1 = 1 + (integer)llFrand(6);
            integer die2 = 1 + (integer)llFrand(6);
            // ANIMATE IMMEDIATELY + send to core only  
            animateDiceRoll(player, die1, die2);
            llMessageLinked(LINK_SET, 0, "PLAYER_DICE_ROLL|" + player + "|" + (string)die1 + "|" + (string)die2, NULL_KEY);
            return;
        }
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list params = llParseString2List(str, ["|"], []);
        string command = llList2String(params, 0);
        
        // === CONTROL STATE from Menu ===
        if (command == "CONTROL_STATE") {
            string stateType = llList2String(params, 1);
            string stateValue = llList2String(params, 2);
            
            if (stateType == "SIMULATING") {
                UI_SIMULATING = (integer)stateValue;
                if (DEBUG_MODE) llOwnerSay("DEBUG UI: Simulating = " + stateValue);
            }
            return;
        }
        else if (command == "SET_PLAYER_KEYS") {
            white = (key)llList2String(params, 1);
            black = (key)llList2String(params, 2);
        }
        else if (command == "GAME_READY") {
            sendMessage("Backgammon game ready. Please sit at white and black positions.");
        }
        else if (command == "START_FIRST_ROLL") {
            gCurrentState = STATE_FIRST_ROLL;
            llMessageLinked(LINK_SET, 0, "POSITION_DICE_FIRST_ROLL", NULL_KEY);
            sendMessage("Both players seated. Please click your dice to roll for first turn.");
        }
        else if (command == "REROLL_FIRST") {
            sendMessage("Roll again, tied values.");
        }
        else if (command == "FIRST_TURN") {
            gCurrentState = STATE_MAIN_GAME;
            turn = llList2String(params, 1);
            currentDie1 = llList2Integer(params, 2);
            currentDie2 = llList2Integer(params, 3);
            
            llMessageLinked(LINK_SET, 0, "SHOW_PLAYER_DICE|" + turn, NULL_KEY);
            if (turn == "white") {
                setDieOrientation("wdie1", currentDie1);
                setDieOrientation("wdie2", currentDie2);
            } else {
                setDieOrientation("bdie1", currentDie1);
                setDieOrientation("bdie2", currentDie2);
            }
            
            sendMessage(turn + " wins the first roll and will play first with " + 
                        (string)currentDie1 + " and " + (string)currentDie2);
        }
        else if (command == "GAME_MESSAGE") {
            string message = llList2String(params, 1);
            sendMessage(message);
        }
        else if (command == "DICE_VALUES") {
            currentDie1 = llList2Integer(params, 1);
            currentDie2 = llList2Integer(params, 2);
        }
        else if (command == "DICE_RESULT") {
            string player = llList2String(params, 1);
            currentDie1 = llList2Integer(params, 2);
            currentDie2 = llList2Integer(params, 3);
            sendMessage(player + " rolled " + (string)currentDie1 + " and " + (string)currentDie2);
        }
        else if (command == "TURN_CHANGE") {
            gCurrentState = STATE_MAIN_GAME;
            turn = llList2String(params, 1);
            currentDie1 = 0;
            currentDie2 = 0;
            isDoubles = FALSE;
            movesLeft = 0;
            
            llMessageLinked(LINK_SET, 0, "HIDE_MARKER|1", NULL_KEY);
            pieceSelected = FALSE;
            selectedPoint = -1;
            selectedPlayer = NULL_KEY;
            
            // Reset all dice to 1 visually
            setDieOrientation("wdie1", 1);
            setDieOrientation("wdie2", 1);
            setDieOrientation("bdie1", 1);
            setDieOrientation("bdie2", 1);
            
            llMessageLinked(LINK_SET, 0, "SHOW_PLAYER_DICE|" + turn, NULL_KEY);
            
            sendMessage("Turn changed to: " + turn);
        }
        else if (command == "INVALID_MOVE") {
            string player = llList2String(params, 1);
            integer errorCode = llList2Integer(params, 2);
            string message = "Invalid move, " + player + ". Try again.";
            
            if (errorCode == 12) {
                message = "You have pieces on the bar. You must move them first.";
            }
            
            sendMessage(message);
            if (pieceSelected) {
                llMessageLinked(LINK_SET, 0, "HIDE_MARKER|1", NULL_KEY);
                pieceSelected = FALSE;
                selectedPoint = -1;
                selectedPlayer = NULL_KEY;
            }
        }
        else if (command == "GAME_OVER") {
            gCurrentState = STATE_GAME_OVER;
            string winner = llList2String(params, 1);
            sendMessage("Game over! " + winner + " wins!");
        }
        else if (command == "GAME_RESET") {
            resetUIState();
            gCurrentState = STATE_RESET;
            white = NULL_KEY;
            black = NULL_KEY;
            simulating = FALSE;
            sendMessage("Game reset. Please sit at white and black positions.");
        }
        else if (command == "PIECE_POSITION") {
            string pieceName = llList2String(params, 1);
            integer position = llList2Integer(params, 2);
            key playerKey = (key)llList2String(params, 3);  // Get the passed player key
            
            // Extract piece color from piece name
            string pieceColor = llGetSubString(pieceName, 0, 0);
            
            if (DEBUG_MODE) {
                llOwnerSay("DEBUG UI: PIECE_POSITION - " + pieceName + " at position " + (string)position + 
                          ", playerKey: " + (string)playerKey + ", pieceColor: " + pieceColor + 
                          ", currentTurn: " + turn);
            }
            
            if ((turn == "white" && pieceColor != "w") || (turn == "black" && pieceColor != "b")) {
                sendMessage("You can only select your own pieces.");
                return;
            }
            
            if(position == FROM_BAR) {
                if (DEBUG_MODE) llOwnerSay("DEBUG UI: Piece is on bar - setting selectedPoint to FROM_BAR");
                
                // In simulation mode, we need to handle player key differently
                if (UI_SIMULATING || (white == NULL_KEY && black == NULL_KEY)) {
                    // Simulation mode: use the current player's expected key
                    if (turn == "white") {
                        selectedPlayer = white;
                    } else {
                        selectedPlayer = black;
                    }
                    if (DEBUG_MODE) llOwnerSay("DEBUG UI: Simulation mode - selectedPlayer set to: " + (string)selectedPlayer);
                } else {
                    // Normal mode: use the passed player key
                    selectedPlayer = playerKey;
                }
                
                pieceSelected = TRUE;
                selectedPoint = FROM_BAR;
                sendMessage("Piece is on the bar. Select a destination point to enter the board.");
            } else if(position == -1) {
                sendMessage("Piece not found on board.");
                return;
            } else {
                // Normal board piece
                integer color;
                if (turn == "white") color = 0;
                else color = 1;
                
                llMessageLinked(LINK_SET, 0, "SHOW_MARKER|1|" + (string)color + "|" + (string)position, NULL_KEY);
                
                // Same player key handling for simulation mode
                if (UI_SIMULATING || (white == NULL_KEY && black == NULL_KEY)) {
                    if (turn == "white") {
                        selectedPlayer = white;
                    } else {
                        selectedPlayer = black;
                    }
                } else {
                    selectedPlayer = playerKey;
                }
                
                pieceSelected = TRUE;
                selectedPoint = position;
                
                if (DEBUG_MODE) {
                    llOwnerSay("DEBUG UI: Piece selected at position " + (string)position + 
                              ", selectedPlayer: " + (string)selectedPlayer);
                }
            }
        }
        else if (command == "DOUBLES_ROLLED") {
            string player = llList2String(params, 1);
            integer dieValue = llList2Integer(params, 2);
            if (player == turn) {
                isDoubles = TRUE;
                movesLeft = 4;
            }
            sendMessage(player + " rolled doubles! " + (string)dieValue + " - " + (string)dieValue + 
                        ". Four moves of " + (string)dieValue + " available.");
        }
        else if (command == "DICE_ROLL") {
            string player = llList2String(params, 1);
            integer die1 = llList2Integer(params, 2);
            integer die2 = llList2Integer(params, 3);
            
            // Only animate for AI rolls, not manual rolls
            if ((player == "white" && white == NULL_KEY) || (player == "black" && black == NULL_KEY)) {
                // This is an AI roll - animate it
                animateDiceRoll(player, die1, die2);
            }
            // Manual rolls are already animated, so skip animation here
            
            // Update current dice values
            currentDie1 = die1;
            currentDie2 = die2;
            
            sendMessage(player + " rolled " + (string)die1 + " and " + (string)die2);
        }
    }
}