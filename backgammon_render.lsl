// BACKGAMMON RENDER - Physical piece movement and rendering
list xList; list bList; list wList;
list BoardList; // Local copy of the board state
float checkerheight; float localHeight;
integer boardInitialized = FALSE;
integer DEBUG_MODE = TRUE; // Add this flag to control debug output
integer DEBUG_MODE_VERBOSE = FALSE; // way too much details this was all worked out previously, hope not to revisit
list WhiteBarList;
list BlackBarList;
list faceRotations;

integer silver1MarkerLink = -1;
integer silver2MarkerLink = -1;
integer FROM_BAR = -2;

integer i;
float local_surfaceHeight() {
    vector v = llGetScale();
    return v.z/2;
}
setRots() {
     faceRotations= [
        ZERO_ROTATION,                                // Face 1 
        llEuler2Rot(<-90.0 * DEG_TO_RAD, 0.0, 0.0>),  // Face 2
        llEuler2Rot(<90.0 * DEG_TO_RAD, 0.0, 0.0>),   // Face 3
        llEuler2Rot(<0.0, 90.0 * DEG_TO_RAD, 0.0>),   // Face 4  
        llEuler2Rot(<180.0 * DEG_TO_RAD, 0.0, 0.0>),  // Face 5
        llEuler2Rot(<0.0, -90.0 * DEG_TO_RAD, 0.0>)   // Face 6
    ];
}

setDiePosition(string dieName, float u, float v, integer isVisible) {
    integer linkNum = GetLinkNumber(dieName);
    if (linkNum == 0) return;
    
    // Calculate position directly without ScaledFromUV
    vector scale = llGetScale();
    float x = (u * scale.x) - (scale.x / 2);
    float y = (v * scale.y) - (scale.y / 2);
    float z;
    
    if (isVisible) {
        z = localHeight + 0.03; // On table surface + half die height
    } else {
        z = localHeight - 0.07; // Hidden below table
    }
    
    vector localPos = <x, y, z>;
    
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG: Positioning " + dieName + " at " + (string)localPos + 
                  ", visible: " + (string)isVisible);
    }
    
    llSetLinkPrimitiveParamsFast(linkNum, [PRIM_POS_LOCAL, localPos]);
}

// Reset all four dice to default positions
resetDice() {
    if (DEBUG_MODE) llOwnerSay("DEBUG: Resetting all four dice to default positions");   
    // Position white die on white side, black die on black side
    setDiePosition("wdie1", 0.55, 0.55, TRUE);  // White side - bottom right
    setDiePosition("bdie1", 0.45, 0.45, TRUE);  // Black side - top left
    
    // Hide the secondary dice
    setDiePosition("wdie2", 0.45, 0.55, FALSE);
    setDiePosition("bdie2", 0.55, 0.45, FALSE);
    
    // Reset dice rotations to show 1 pip face up for all dice
    rotateDieToValue("wdie1", 1);
    rotateDieToValue("wdie2", 1);
    rotateDieToValue("bdie1", 1);
    rotateDieToValue("bdie2", 1);
}

// Show dice for a specific player's turn
showPlayerDice(string player) {
    if (DEBUG_MODE) llOwnerSay("DEBUG: Showing dice for player: " + player);
    
    if (player == "white") {
        // Show white dice on WHITE side (bottom), hide black dice
        setDiePosition("wdie1", 0.55, 0.55, TRUE);  // Bottom right
        setDiePosition("wdie2", 0.45, 0.55, TRUE);  // Bottom left  
        setDiePosition("bdie1", 0.45, 0.45, FALSE); // Hide black dice
        setDiePosition("bdie2", 0.55, 0.45, FALSE); // Hide black dice
    } else {
        // Show black dice on BLACK side (top), hide white dice
        setDiePosition("wdie1", 0.55, 0.55, FALSE);  // Top right
        setDiePosition("wdie2", 0.45, 0.55, FALSE);  // Top left
        setDiePosition("bdie1", 0.45, 0.45, TRUE); // Hide white dice
        setDiePosition("bdie2", 0.55, 0.45, TRUE); // Hide white dice
    }
}

// Update dice to show specific values for a player
updateDiceValues(string player, integer die1, integer die2) {
    if (DEBUG_MODE) llOwnerSay("DEBUG: Updating dice for " + player + ": " + (string)die1 + ", " + (string)die2);
    
    if (player == "white") {
        rotateDieToValue("wdie1", die1);
        rotateDieToValue("wdie2", die2);
    } else {
        rotateDieToValue("bdie1", die1);
        rotateDieToValue("bdie2", die2);
    }
}

rotateDieToValue(string dieName, integer value) {
    integer linkNum = GetLinkNumber(dieName);
    if (linkNum == 0) return;
    
    // Define rotations for each die face (1-6)
    // These rotations need to be calibrated for your specific die prims

    
    if (value >= 1 && value <= 6) {
        rotation rot = llList2Rot(faceRotations, value - 1);
        llSetLinkPrimitiveParamsFast(linkNum, [PRIM_ROTATION, rot]);
        
        if (DEBUG_MODE) llOwnerSay("DEBUG: Rotated " + dieName + " to show face " + (string)value);
    }
}

vector ScaledFromUV(vector UV) {
    // takes UV coordinates (which range from 0 to 1) and converts them to local object coordinates by:
    //    Scaling the X and Y values by the object's dimensions
    //    Subtracting half the scale from each to shift the origin from the center to the corner
    vector scale = llGetScale();
    UV.x *= scale.x;
    UV.y *= scale.y;
    UV.y -= scale.y/2;
    UV.x -= scale.x/2;
    return UV;
}

init_render() {
    setRots();
    // Horizontal UV coordinates
    float rightEdge = 0.991;  // Right edge
    float rightBar = 0.553;   // Right side of bar
    float leftBar = 0.445;    // Left side of bar
    float leftEdge = 0.006;   // Left edge

    // Calculate horizontal centers for the 24 points
    xList = [];
    
    // Right side points (points 1-6)
    float rightSegment = (rightEdge - rightBar) / 6;
    for(i = 0; i < 6; i++) {
        float center = rightEdge - (i * rightSegment) - (rightSegment / 2);
        xList += center;
    }
    
    // Left side points (points 7-12)
    float leftSegment = (leftBar - leftEdge) / 6;
    for(i = 0; i < 6; i++) {
        float center = leftBar - (i * leftSegment) - (leftSegment / 2);
        xList += center;
    }
    
    // For points 13-24, use the same xList values in reverse order
    for(i = 11; i >= 0; i--) {
        xList += llList2Float(xList, i);
    }
    
    // Add bar points (24 and 25) at the center
    xList += [0.5, 0.5];

    // Vertical UV coordinates with simple tip bias and spacing
    float bottomWhite = 0.60; // Base of white points
    float topWhite = 0.92;    // Tip of white points
    float bottomBlack = 0.07; // Base of black points  
    float topBlack = 0.40;    // Tip of black points

    // Apply tip bias and spacing as requested
    float tipBias = 0.1; // 0.1 offset
    float checkerSpacing = 0.06; // 0.011 spacing

    // Calculate vertical positions for white pieces
    // Start from inner edge + bias, then add spacing for each piece
    wList = [];
    float whiteStart = topWhite - tipBias; // Start position
    for(i = 0; i < 6; i++) {
        wList += whiteStart - (i * checkerSpacing);
    }

    // Calculate vertical positions for black pieces
    // Start from inner edge - bias, then subtract spacing for each piece
    bList = [];
    float blackStart = bottomBlack + tipBias; // Start position
    for(i = 0; i < 6; i++) {
        bList += blackStart + (i * checkerSpacing);
    }

    // Height calculation
    vector s = llGetScale();
    checkerheight = s.x / 160;
    localHeight = local_surfaceHeight() + checkerheight/2 - 0.223;
    hideMarker(1);
    hideMarker(2);
    if (DEBUG_MODE_VERBOSE) {
        // Debug output
        llOwnerSay("Pieces positioned with simple tip bias (0.1) and spacing (0.011)");
        llOwnerSay("White start: " + (string)whiteStart);
        llOwnerSay("Black start: " + (string)blackStart);
        llOwnerSay("wList: " + llDumpList2String(wList, ", "));
        llOwnerSay("bList: " + llDumpList2String(bList, ", "));
    }
}

integer GetLinkNumber(string linkName) {
    integer x; integer numprims = llGetNumberOfPrims();
    for(x = 1; x <= numprims; x++) {
        if(linkName == llGetLinkName(x)) return x;
    }
    return 0;
}

Arrange(integer color, integer position) {
    // Determine points list, vertical list, and horizontal position
    string points;
    list verticalList;
    float uPosition;
    
    if (position == 24 || position == 25) {
        // Handle bar points
        if (position == 24) {
            points = llDumpList2String(WhiteBarList, ",");
            verticalList = wList;
        } else {
            points = llDumpList2String(BlackBarList, ",");
            verticalList = bList;
        }
        uPosition = 0.5;
    } else {
        // Handle regular points
        points = llList2String(BoardList, position);
        if (points == "") return;
        
        if (position < 12) {
            verticalList = wList;
        } else {
            verticalList = bList;
        }
        uPosition = llList2Float(xList, position);
    }
    
    // Position each piece with efficient stacking
    list pieceNames = llParseString2List(points, [","], []);
    integer pieceCount = llGetListLength(pieceNames);
    
    integer i;
    for(i = 0; i < pieceCount; i++) {
        string pieceName = llList2String(pieceNames, i);
        integer linkNum = GetLinkNumber(pieceName);
        
        if (linkNum != 0) {       
            // Calculate stacking position using division and modulo
            integer verticalIndex = i % 5;
            integer stackLayer = i / 5;
            float stackHeight = stackLayer * checkerheight;
            float vPosition = llList2Float(verticalList, verticalIndex);
            
            // Calculate position
            vector uvCoords = <uPosition, vPosition, localHeight + stackHeight>;
            vector localPos = ScaledFromUV(uvCoords);
            
            // Position the piece
            llSetLinkPrimitiveParamsFast(linkNum, [PRIM_POS_LOCAL, localPos]);
        }
    }
}

positionMarker(integer markerType, integer color, integer position) {
    // Convert internal position to physical board coordinates
    // The board is fixed - points 1-12 on bottom, 13-24 on top
    // Internal position 0-23 corresponds to points 1-24
    
    integer xListPos;
    integer isTopPoint = (position >= 12); // Points 13-24 are top (internal 12-23)
    
    if (isTopPoint) {
        // Top points: use mirrored x-coordinates
        xListPos = 23 - position;
    } else {
        // Bottom points: use direct x-coordinates
        xListPos = position;
    }
    
    // Select appropriate vertical list based on physical position
    list verticalList;
    if (isTopPoint) {
        verticalList = bList; // Top points use black's vertical positions
    } else {
        verticalList = wList; // Bottom points use white's vertical positions
    }
    
    // Get the appropriate marker prim
    integer num;

    if (markerType == 1) num = silver1MarkerLink;
    else if (markerType == 2) num = silver2MarkerLink;
    
    // Position the marker
    llSetLinkPrimitiveParamsFast(num, [
        PRIM_POSITION, 
        ScaledFromUV(<
            llList2Float(xList, xListPos), 
            llList2Float(verticalList, 2), 
            localHeight
        >)
    ]);
}

hideMarker(integer markerType) {
    integer num;
    if(markerType == 1) num = silver1MarkerLink;
    else if(markerType == 2) num = silver2MarkerLink;
    llSetLinkPrimitiveParamsFast(num, [PRIM_POSITION, ZERO_VECTOR]);
}

refreshAllPieces() {
    if (DEBUG_MODE_VERBOSE) llOwnerSay("DEBUG: refreshAllPieces() called. BoardList length: " + (string)llGetListLength(BoardList));
    integer i;
    for (i = 0; i < 24; i++) {
        string pointState = llList2String(BoardList, i);
        if (llStringLength(pointState) > 0) {
            if (DEBUG_MODE_VERBOSE) llOwnerSay("Processing point " + (string)(i+1) + ": " + pointState);
            // Determine which color's pieces are at this point
            list pieces = llParseString2List(pointState, [","], []);
            string firstPiece = llList2String(pieces, 0);
            integer color = 0; // Default to white
            if (llGetSubString(firstPiece, 0, 0) == "b") {
                color = 1; // Black
            }
            Arrange(color, i);
        }
    }
    if (DEBUG_MODE_VERBOSE) llOwnerSay("Finished refreshAllPieces()");

}

default {
    state_entry() {
        silver1MarkerLink = GetLinkNumber("silver1");
        silver2MarkerLink = GetLinkNumber("silver2");
        init_render();
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list params = llParseStringKeepNulls(str, ["|"], []);
        string command = llList2String(params, 0);
        
        if (command == "BOARD_STATE") {
            integer len = llGetListLength(params);
            //remove me -
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
            llOwnerSay("DEBUG RENDER: BOARD_STATE received - " +
                       "WhiteOnBoard: " + (string)whiteOnBoard +
                       " BlackOnBoard: " + (string)blackOnBoard);
            //- when fix is done
            
            if (DEBUG_MODE_VERBOSE) llOwnerSay("DEBUG: Received BOARD_STATE message: " + str + (string)(len));
            
            BoardList = llList2List(params, 1, 24);
            
            // CRITICAL FIX: Don't arrange bar pieces here - wait for BAR_STATE message
            // The BAR_STATE message will handle bar piece arrangement
            
            refreshAllPieces();
            
            llOwnerSay("DEBUG RENDER: Finished processing BOARD_STATE");
        }
        else if (command == "POSITION_DICE_FIRST_ROLL") {
            if (DEBUG_MODE) llOwnerSay("DEBUG: Positioning dice for first roll");        
            // Position white die and black die at corners
            setDiePosition("wdie1", 0.55, 0.55, TRUE);
            setDiePosition("bdie1", 0.45, 0.45, TRUE);
            
            // Hide the secondary dice
            setDiePosition("wdie2", 0.45, 0.55, FALSE);
            setDiePosition("bdie2", 0.55, 0.45, FALSE);
        }
        else if (command == "SHOW_PLAYER_DICE") {
            string player = llList2String(params, 1);
            if (DEBUG_MODE) llOwnerSay("DEBUG: Showing dice for player: " + player);
            
            if (player == "white") {
                // Show white dice, hide black dice
                setDiePosition("wdie1", 0.55, 0.55, TRUE);
                setDiePosition("wdie2", 0.45, 0.55, TRUE);
                setDiePosition("bdie1", 0.45, 0.45, FALSE);
                setDiePosition("bdie2", 0.55, 0.45, FALSE);
            } else {
                // Show black dice, hide white dice
                setDiePosition("wdie1", 0.55, 0.55, FALSE);
                setDiePosition("wdie2", 0.45, 0.55, FALSE);
                setDiePosition("bdie1", 0.45, 0.45, TRUE);
                setDiePosition("bdie2", 0.55, 0.45, TRUE);

            }
        }
        else if (command == "HIDE_ALL_DICE") {
            if (DEBUG_MODE) llOwnerSay("DEBUG: Hiding all dice");
            
            setDiePosition("wdie1", 0.55, 0.55, FALSE);
            setDiePosition("wdie2", 0.45, 0.55, FALSE);
            setDiePosition("bdie1", 0.45, 0.45, FALSE);
            setDiePosition("bdie2", 0.55, 0.45, FALSE);
        }
        else if (command == "TURN_CHANGE") {
            string newTurn = llList2String(params, 1);
            
            // Show dice for the player whose turn it is
            showPlayerDice(newTurn);
        }
        else if(command == "BAR_STATE") {
            // The bar pieces are all parameters after the first one
            list allBarPieces = llList2List(params, 1, -1);
            
            // Separate white and black pieces for game logic
            WhiteBarList = [];
            BlackBarList = [];
            
            integer i;
            for(i = 0; i < llGetListLength(allBarPieces); i++) {
                string piece = llList2String(allBarPieces, i);
                if(llGetSubString(piece, 0, 0) == "w") {
                    WhiteBarList += piece;
                } else {
                    BlackBarList += piece;
                }
            }

            if (DEBUG_MODE) {
                llOwnerSay("DEBUG RENDER: BAR_STATE received - White: " + llDumpList2String(WhiteBarList, ",") + 
                          " Black: " + llDumpList2String(BlackBarList, ","));
            }
            
            // Arrange the bar pieces
            Arrange(0, 24); // Arrange white bar
            Arrange(1, 25); // Arrange black bar
        }
        else if(command == "BOARD_INIT_DONE") {
            // Only refresh if we haven't already
            if (!boardInitialized) {
                refreshAllPieces();
                boardInitialized = TRUE;
            }
        }
        else if(command == "MOVE_PIECE") {
            string piece = llList2String(params, 1);
            integer from_point = llList2Integer(params, 2);
            integer to_point = llList2Integer(params, 3);
            
            if (DEBUG_MODE) {
                llOwnerSay("DEBUG RENDER: MOVE_PIECE - " + piece + " from " + (string)from_point + " to " + (string)to_point);
            }
            
            integer color;
            if(llGetSubString(piece, 0, 0) == "w") color = 0;
            else color = 1;
            
            // For bar moves, the piece is already removed from bar lists
            if (from_point != FROM_BAR) {
                Arrange(color, from_point);  // Remove from source point
            }
            
            // For the destination point, let BOARD_STATE handle the positioning
            // DO NOT call Arrange for to_point here - this causes the bar transition
            
            if (DEBUG_MODE) {
                llOwnerSay("DEBUG RENDER: MOVE_PIECE processed - only arranged source point");
            }
        }
        else if (command == "ARRANGE_POINT") {
            integer color = llList2Integer(params, 1);
            integer point = llList2Integer(params, 2);
            
            if (DEBUG_MODE) {
                llOwnerSay("DEBUG: Arranging point " + (string)point + " for color " + (string)color);
            }
            
            Arrange(color, point);
        }
        else if(command == "HIT_PIECE") {
            string piece = llList2String(params, 1);
            integer from_point = llList2Integer(params, 2);
            
            if (DEBUG_MODE) {
                llOwnerSay("DEBUG RENDER: HIT_PIECE received - " + piece + " from point " + (string)from_point);
            }
            
            // ONLY update bar lists - BOARD_STATE will handle actual piece movement
            if (llGetSubString(piece, 0, 0) == "w") {
                WhiteBarList += [piece];
                if (DEBUG_MODE) llOwnerSay("DEBUG RENDER: Added " + piece + " to WhiteBarList");
            } else {
                BlackBarList += [piece];
                if (DEBUG_MODE) llOwnerSay("DEBUG RENDER: Added " + piece + " to BlackBarList");
            }
            
            // DO NOT call Arrange here - let BOARD_STATE handle the piece positioning
            // The bar lists are now updated for when BOARD_STATE processes the bar positions
        }
        else if(command == "BEAR_OFF") {
            string piece = llList2String(params, 1);
            integer from_point = llList2Integer(params, 2);
            
            integer color;
            if(llGetSubString(piece, 0, 0) == "w") color = 0;
            else color = 1;
            
            Arrange(color, from_point);
        }
        else if (command == "DICE_RESULT") {
            string player = llList2String(params, 1);
            integer die1 = llList2Integer(params, 2);
            integer die2 = llList2Integer(params, 3);
            
            if (DEBUG_MODE) llOwnerSay("DEBUG: Showing dice result for " + player + ": " + (string)die1 + ", " + (string)die2);
            
            // Show the appropriate player's dice
            showPlayerDice(player);
            
            // Update the dice to show the correct values
            updateDiceValues(player, die1, die2);
        }
        else if(command == "SHOW_MARKER") {
            integer markerType = llList2Integer(params, 1);
            integer color = llList2Integer(params, 2);
            integer position = llList2Integer(params, 3);
            positionMarker(markerType, color, position);
        }
        else if(command == "HIDE_MARKER") {
            integer markerType = llList2Integer(params, 1);
            hideMarker(markerType);
        }
        else if(command == "GAME_RESET") {
            boardInitialized = FALSE;
            WhiteBarList = [];
            BlackBarList = [];

            llSleep(0.5); // Small delay to ensure BOARD_STATE is processed
            refreshAllPieces(); // Force immediate refresh on reset
            
            // Also hide any markers
            hideMarker(1);
            hideMarker(2);
            
            resetDice();
            if (DEBUG_MODE) {
                llOwnerSay("DEBUG: Render state reset and refreshed");
            }
        }
    }
}