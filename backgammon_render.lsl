// BACKGAMMON RENDER - Physical piece movement and rendering
list xList; list bList; list wList;
list BoardList; // Local copy of the board state
float checkerheight; float localHeight;
integer boardInitialized = FALSE;
integer DEBUG_MODE = FALSE; // Add this flag to control debug output
list WhiteBarList;
list BlackBarList;
list faceRotations;

integer silver1MarkerLink = 0;
integer silver2MarkerLink = 0;
integer goldMarkerLink = 0;
integer turnIndicatorLink = 0;
integer whiteStatusLink = 0;
integer blackStatusLink = 0;

// Extra Dice Links
integer wdie3Link = -1;
integer wdie4Link = -1;
integer bdie3Link = -1;
integer bdie4Link = -1;

integer gIsDoubles = FALSE;
integer FROM_BAR = -2;

// UUIDs for Status Images
string UUID_NOT_YOUR_TURN = "3261a0eb-dfaf-97bf-c540-ea2ef20af175";
string UUID_NOT_YOUR_PIECE = "eba0c4b0-f618-74c8-ffac-c4b63b6c5443";
string UUID_NO_VALID_MOVES = "e0415315-4b10-930c-933d-47ba85ba6c92";
string UUID_HIT = "d635a1f0-a520-cf2a-fdb7-3d8eb63433fc";
string UUID_BEAR_OFF = "abe37417-abdf-85c2-9454-9766515ecdde";

showStatusIcon(string uuid) {
     if (whiteStatusLink > 0) {
         llSetLinkPrimitiveParamsFast(whiteStatusLink, [PRIM_TEXTURE, 0, uuid, <1,1,0>, ZERO_VECTOR, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
         llSetLinkAlpha(whiteStatusLink, 1.0, ALL_SIDES);
     }
     if (blackStatusLink > 0) {
         llSetLinkPrimitiveParamsFast(blackStatusLink, [PRIM_TEXTURE, 0, uuid, <1,1,0>, ZERO_VECTOR, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
         llSetLinkAlpha(blackStatusLink, 1.0, ALL_SIDES);
     }
     llSetTimerEvent(2.5);
}

// Storage Tuning
float STORAGE_U_TOP = 1.08; // Beyond right edge (top storage)
float STORAGE_U_BOTTOM = 1.08; // Beyond right edge (bottom storage)
float STORAGE_V_TOP = 0.60; // Top storage location (white pieces go here)
float STORAGE_V_BOTTOM = 0.41; // Bottom storage location (black pieces go here)
float STORAGE_SPACING = 0.02; // Gap between stored pieces
float STORAGE_SINK = 0.2;     // 1/5th sink factor
rotation STORAGE_ROT = ZERO_ROTATION; // Will be set in init

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
    STORAGE_ROT = llEuler2Rot(<90.0 * DEG_TO_RAD, 0.0, 0.0>); // Stand on edge facing X-axis (Parallel to running axis)
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
        // For hidden dice, force them to center to avoid edge popping
        x = 0.0;
        y = 0.0;
    }
    
    vector localPos = <x, y, z>;
    
    if (DEBUG_MODE != FALSE) {
        //llOwnerSay("DEBUG: Positioning " + dieName + " at " + (string)localPos + ", visible: " + (string)isVisible);
    }
    
    llSetLinkPrimitiveParamsFast(linkNum, [PRIM_POS_LOCAL, localPos]);
}

// Reset all four dice to default positions
resetDice() {
    if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG: Resetting all four dice to default positions");   
    // Position white die on white side, black die on black side
    setDiePosition("wdie1", 0.55, 0.55, TRUE);  // White side - bottom right
    setDiePosition("bdie1", 0.45, 0.45, TRUE);  // Black side - top left
    
    // Hide the secondary dice (and doubles dice)
    setDiePosition("wdie2", 0.45, 0.55, FALSE);
    setDiePosition("bdie2", 0.55, 0.45, FALSE);
    setDiePosition("wdie3", 0.0, 0.0, FALSE); 
    setDiePosition("wdie4", 0.0, 0.0, FALSE);
    setDiePosition("bdie3", 0.0, 0.0, FALSE);
    setDiePosition("bdie4", 0.0, 0.0, FALSE);
    
    // Reset dice rotations to show 1 pip face up for all dice
    rotateDieToValue("wdie1", 1);
    rotateDieToValue("wdie2", 1);
    rotateDieToValue("bdie1", 1);
    rotateDieToValue("bdie2", 1);
}

// Show dice for a specific player's turn
showPlayerDice(string player) {
    if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG: Showing dice for player: " + player);
    
    if (player == "white") {
        // Show white dice on WHITE side (bottom), hide black dice
        setDiePosition("wdie1", 0.55, 0.55, TRUE);  // Bottom right
        setDiePosition("wdie2", 0.45, 0.55, TRUE);  // Bottom left  
        setDiePosition("bdie1", 0.45, 0.45, FALSE); // Hide black dice
        setDiePosition("bdie2", 0.55, 0.45, FALSE); // Hide black dice
        
        // Ensure extra dice are hidden by default
        setDiePosition("wdie3", 0.0, 0.0, FALSE); 
        setDiePosition("wdie4", 0.0, 0.0, FALSE);
        setDiePosition("bdie3", 0.0, 0.0, FALSE);
        setDiePosition("bdie4", 0.0, 0.0, FALSE);
    } else {
        // Show black dice on BLACK side (top), hide white dice
        setDiePosition("wdie1", 0.55, 0.55, FALSE);  // Top right
        setDiePosition("wdie2", 0.45, 0.55, FALSE);  // Top left
        setDiePosition("bdie1", 0.45, 0.45, TRUE); // Hide white dice
        setDiePosition("bdie2", 0.55, 0.45, TRUE); // Hide white dice
        
        // Ensure extra dice are hidden by default
        setDiePosition("wdie3", 0.0, 0.0, FALSE); 
        setDiePosition("wdie4", 0.0, 0.0, FALSE);
        setDiePosition("bdie3", 0.0, 0.0, FALSE);
        setDiePosition("bdie4", 0.0, 0.0, FALSE);
    }
}

// Update dice to show specific values for a player
updateDiceValues(string player, integer die1, integer die2) {
    if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG: Updating dice for " + player + ": " + (string)die1 + ", " + (string)die2);
    
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
        
        if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG: Rotated " + dieName + " to show face " + (string)value);
    }
}

// Animation function ported from UI
animateDieRoll(string name, integer finalValue) {
    integer n = GetLinkNumber(name);
    if (n == 0) return;
    
    // Generate a random intermediate value DIFFERENT from finalValue
    // to ensure visible movement (shake effect)
    integer intermediate = 1 + (integer)llFrand(6.0);
    while (intermediate == finalValue) {
        intermediate = 1 + (integer)llFrand(6.0);
    }
    
    // Show intermediate value
    rotateDieToValue(name, intermediate);
    
    // Short delay for the "shake"
    llSleep(0.1);
    
    // Show final value
    rotateDieToValue(name, finalValue);
}

animateDiceRoll(string player, integer die1, integer die2) {
    if (player == "white") {
        if (die1 > 0) animateDieRoll("wdie1", die1);
        if (die2 > 0) animateDieRoll("wdie2", die2);
    } else {
        if (die1 > 0) animateDieRoll("bdie1", die1);
        if (die2 > 0) animateDieRoll("bdie2", die2);
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
    hideMarker(3);
}

integer GetLinkNumber(string linkName) {
    integer x; integer numprims = llGetNumberOfPrims();
    for(x = 1; x <= numprims; x++) {
        if(linkName == llGetLinkName(x)) return x;
    }
    return 0;
}

updateLocalBoard(string piece, integer from_point, integer to_point) {
    // Remove from source point
    if (from_point >= 0 && from_point < 24) {
        string pointStr = llList2String(BoardList, from_point);
        list pieces = llParseString2List(pointStr, [","], []);
        integer idx = llListFindList(pieces, [piece]);
        if (idx != -1) {
            pieces = llDeleteSubList(pieces, idx, idx);
            BoardList = llListReplaceList(BoardList, [llDumpList2String(pieces, ",")], from_point, from_point);
            if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: updateLocalBoard removed " + piece + " from point " + (string)from_point);
        }
    }
    
    // Add to destination point (only if not bearing off)
    if (to_point >= 0 && to_point < 24) {
        string pointStr = llList2String(BoardList, to_point);
        if (pointStr == "") pointStr = piece;
        else pointStr += "," + piece;
        BoardList = llListReplaceList(BoardList, [pointStr], to_point, to_point);
        if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: updateLocalBoard added " + piece + " to point " + (string)to_point);
    }
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
            llSetLinkPrimitiveParamsFast(linkNum, [PRIM_POSITION, localPos, PRIM_ROTATION, ZERO_ROTATION]);
        }
    }
}

/*ArrangeStorage(integer color) {
    // Move all 15 pieces of color to storage
    // NOTE: White pieces go to TOP storage, black pieces go to BOTTOM storage
    string prefix = "b";  // White color (0) moves black pieces to top
    float uStart = STORAGE_U_TOP;
    float vStart = STORAGE_V_TOP;
    if (color == 1) {
        prefix = "w";  // Black color (1) moves white pieces to bottom
        uStart = STORAGE_U_BOTTOM;
        vStart = STORAGE_V_BOTTOM;
    }
    
    integer i;
    for (i = 1; i <= 15; i++) {
        string pieceName = prefix + (string)i;
        integer linkNum = GetLinkNumber(pieceName);
        
        if (linkNum != 0) {
            // Calculate storage position
            // Stack VERTICALLY as requested
            // White (Bottom Right): CCW -> Up (+V)
            // Black (Top Right): CW -> Down (-V)
            
            float uPos = uStart; // Fixed U
            float vPos;
            
            if (color == 0) { // White
                 vPos = vStart + (i * STORAGE_SPACING);
            } else { // Black
                 vPos = vStart - (i * STORAGE_SPACING);
            }
            
            // Sink into surface
            float zPos = localHeight - (checkerheight * STORAGE_SINK); // Sunk
            
            vector uvCoords = <uPos, vPos, zPos>;
            vector localPos = ScaledFromUV(uvCoords);
            
            // Apply rotation
            llSetLinkPrimitiveParamsFast(linkNum, [PRIM_POSITION, localPos, PRIM_ROTATION, STORAGE_ROT]);
        }
    }
}

ArrangeStoragePiece(string pieceName) {
    integer linkNum = GetLinkNumber(pieceName);
    if (linkNum == 0) return;
    
    // Parse ID from name (e.g. "w1" -> 1, "b15" -> 15)
    string prefix = llGetSubString(pieceName, 0, 0);
    integer id = (integer)llGetSubString(pieceName, 1, -1);
    
    // NOTE: White pieces (w*) go to TOP storage, black pieces (b*) go to BOTTOM storage
    integer color = 0; // Default to white
    float uStart = STORAGE_U_TOP;  // White pieces use top storage
    float vStart = STORAGE_V_TOP;
    
    if (prefix == "w") {  // If piece is white, use top storage
        color = 0; // White
        uStart = STORAGE_U_TOP;
        vStart = STORAGE_V_TOP;
    } else {  // If piece is black, use bottom storage
        color = 1; // Black
        uStart = STORAGE_U_BOTTOM;
        vStart = STORAGE_V_BOTTOM;
    }
    
    // Calculate storage position (Same logic as ArrangeStorage)
    float uPos = uStart;
    float vPos;
    
    if (color == 0) { // White
         vPos = vStart + (id * STORAGE_SPACING);
    } else { // Black
         vPos = vStart - (id * STORAGE_SPACING);
    }
    
    float zPos = localHeight - (checkerheight * STORAGE_SINK);
    
    vector uvCoords = <uPos, vPos, zPos>;
    vector localPos = ScaledFromUV(uvCoords);
    
    llSetLinkPrimitiveParamsFast(linkNum, [PRIM_POSITION, localPos, PRIM_ROTATION, STORAGE_ROT]);
}
*/
// Keep both functions but eliminate duplicate code

ArrangeStorage(integer color) {
    string prefix = "b";
    if (color == 1) prefix = "w";
    
    integer i;
    for (i = 1; i <= 15; i++) {
        positionStoragePiece(color, i, prefix + (string)i);
    }
}

ArrangeStoragePiece(string pieceName) {
    string prefix = llGetSubString(pieceName, 0, 0);
    integer color = 0;
    if (prefix == "w") color = 1;
    
    integer id = (integer)llGetSubString(pieceName, 1, -1);
    positionStoragePiece(color, id, pieceName);
}

// Shared positioning logic
positionStoragePiece(integer color, integer id, string pieceName) {
    integer linkNum = GetLinkNumber(pieceName);
    if (linkNum == 0) return;
    
    float uStart;
    float vStart;
    if (color == 0) {
        uStart = STORAGE_U_TOP;
        vStart = STORAGE_V_TOP;
    } else {
        uStart = STORAGE_U_BOTTOM;
        vStart = STORAGE_V_BOTTOM;
    }
    
    float uPos = uStart;
    float vPos;
    
    if (color == 0) {
        vPos = vStart + (id * STORAGE_SPACING);
    } else {
        vPos = vStart - (id * STORAGE_SPACING);
    }
    
    float zPos = localHeight - (checkerheight * STORAGE_SINK);
    
    vector uvCoords = <uPos, vPos, zPos>;
    vector localPos = ScaledFromUV(uvCoords);
    
    llSetLinkPrimitiveParamsFast(linkNum, [PRIM_POSITION, localPos, PRIM_ROTATION, STORAGE_ROT]);
}

resetToStorage() {
    if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: Moving pieces to storage");
    ArrangeStorage(0); // White
    ArrangeStorage(1); // Black
}

positionMarker(integer markerType, integer color, integer position) {
    float uPosition;
    list verticalList;
    
    // Handle special bear-off position (-99)
    if (position == -99) {
        // Position beyond the board edge using actual UV coordinates
        // Both White and Black bear off beyond their point 1 (beyond right edge)
        if (color == 0) {
            // White bears off beyond point 0 (beyond right edge on bottom)
            uPosition = 0.991 + 0.05; // Right edge plus offset
            verticalList = bList; // Bottom list
        } else {
            // Black bears off beyond point 23 (beyond right edge on top)
            uPosition = 0.991 + 0.05; // Right edge plus offset
            verticalList = wList; // Top list
        }
    } else if (position == -2) { // FROM_BAR
        uPosition = 0.5; // Center of board
        if (color == 0) {
            // White bar (Bottom)
            verticalList = wList; 
        } else {
            // Black bar (Top)
            verticalList = bList;
        }
    } else {
        // Regular board position
        integer isTopPoint = (position >= 12);
        
        if (isTopPoint) {
            verticalList = bList;
        } else {
            verticalList = wList;
        }
        uPosition = llList2Float(xList, position);
    }
    
    // Get the appropriate marker prim
    integer num;
    if (markerType == 1) num = goldMarkerLink;
    else if (markerType == 2) num = silver1MarkerLink;
    else if (markerType == 3) num = silver2MarkerLink;
    
    // Position the marker
    llSetLinkPrimitiveParamsFast(num, [
        PRIM_POSITION, 
        ScaledFromUV(<
            uPosition, 
            llList2Float(verticalList, 2), 
            localHeight
        >)
    ]);
}

hideMarker(integer markerType) {
    integer num;
    if(markerType == 1) num = goldMarkerLink;
    else if(markerType == 2) num = silver1MarkerLink;
    else if(markerType == 3) num = silver2MarkerLink;
    llSetLinkPrimitiveParamsFast(num, [PRIM_POSITION, <0,0,-5.0>]);
}

refreshAllPieces() {
    
    // Always update bar pieces first - they have highest priority
    Arrange(0, 24); // White bar
    Arrange(1, 25); // Black bar
    
    // Then update all board points
    integer i;
    for (i = 0; i < 24; i++) {
        string pointState = llList2String(BoardList, i);
        if (llStringLength(pointState) > 0) {
            //if (FALSE) llOwnerSay("Processing point " + (string)(i+1) + ": " + pointState);
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
}

default {
    state_entry() {
        silver1MarkerLink = GetLinkNumber("silver1");
        silver2MarkerLink = GetLinkNumber("silver2");
        goldMarkerLink = GetLinkNumber("gold");
        
        turnIndicatorLink = GetLinkNumber("turn_indicator");
        whiteStatusLink = GetLinkNumber("status_display_white");
        blackStatusLink = GetLinkNumber("status_display_black");
        
        wdie3Link = GetLinkNumber("wdie3");
        wdie4Link = GetLinkNumber("wdie4");
        bdie3Link = GetLinkNumber("bdie3");
        bdie4Link = GetLinkNumber("bdie4");
        
        if (DEBUG_MODE) {
            llOwnerSay("DEBUG RENDER LINK STATUS:");
            llOwnerSay("Turn Indicator: " + (string)turnIndicatorLink);
            llOwnerSay("White Status: " + (string)whiteStatusLink);
            llOwnerSay("Black Status: " + (string)blackStatusLink);
            llOwnerSay("Extra Dice: W3=" + (string)wdie3Link + " W4=" + (string)wdie4Link + " B3=" + (string)bdie3Link + " B4=" + (string)bdie4Link);
        }
        
        init_render();
        // Initial state: Storage
        resetToStorage();
    }
    
    timer() {
        llSetTimerEvent(0.0);
        // Clear status displays
        if (whiteStatusLink > 0) llSetLinkTexture(whiteStatusLink, TEXTURE_BLANK, ALL_SIDES); // Or hide
        if (blackStatusLink > 0) llSetLinkTexture(blackStatusLink, TEXTURE_BLANK, ALL_SIDES);
        if (whiteStatusLink > 0) llSetLinkAlpha(whiteStatusLink, 0.0, ALL_SIDES);
        if (blackStatusLink > 0) llSetLinkAlpha(blackStatusLink, 0.0, ALL_SIDES);
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list params = llParseStringKeepNulls(str, ["|"], []);
        string command = llList2String(params, 0);
        
        if (command == "BOARD_STATE") {
            integer len = llGetListLength(params);
            
            // Count actual pieces on board (not just points)
            integer whiteOnBoard = 0;
            integer blackOnBoard = 0;
            integer i;
            for (i = 0; i < 24; i++) {
                string point = llList2String(BoardList, i);
                if (point != "") {
                    list pieces = llParseString2List(point, [","], []);
                    integer j;
                    for (j = 0; j < llGetListLength(pieces); j++) {
                        string piece = llList2String(pieces, j);
                        if (llGetSubString(piece, 0, 0) == "w") whiteOnBoard++;
                        else if (llGetSubString(piece, 0, 0) == "b") blackOnBoard++;
                    }
                }
            }
            if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: BOARD_STATE received - " +
                       "WhiteOnBoard: " + (string)whiteOnBoard +
                       " BlackOnBoard: " + (string)blackOnBoard);
            
            BoardList = llList2List(params, 1, 24);
            
            // CRITICAL FIX: Don't arrange bar pieces here - wait for BAR_STATE message
            // The BAR_STATE message will handle bar piece arrangement
            
            refreshAllPieces();
            
            if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: Finished processing BOARD_STATE");
        }
        else if (command == "START_FIRST_ROLL") {
            if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: START_FIRST_ROLL received - Arranging pieces for game start");
            refreshAllPieces();
        }
        else if (command == "DEBUG_STATE") {
            DEBUG_MODE = (integer)llList2String(params, 1);
            if (DEBUG_MODE != FALSE) llOwnerSay("render: Debug mode " + (string)("ON"));
        }
        else if (command == "POSITION_DICE_FIRST_ROLL") {
            if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG: Positioning dice for first roll");        
            // Position white die and black die at corners
            setDiePosition("wdie1", 0.55, 0.55, TRUE);
            setDiePosition("bdie1", 0.45, 0.45, TRUE);
            
            // Hide the secondary dice
            setDiePosition("wdie2", 0.45, 0.55, FALSE);
            setDiePosition("bdie2", 0.55, 0.45, FALSE);
        }
        else if (command == "SHOW_PLAYER_DICE") {
            string player = llList2String(params, 1);
            if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG: Showing dice for player: " + player);
            
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
            if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG: Hiding all dice");
            
            setDiePosition("wdie1", 0.55, 0.55, FALSE);
            setDiePosition("wdie2", 0.45, 0.55, FALSE);
            setDiePosition("bdie1", 0.45, 0.45, FALSE);
            setDiePosition("bdie2", 0.55, 0.45, FALSE);
            setDiePosition("wdie3", 0.0, 0.0, FALSE);
            setDiePosition("wdie4", 0.0, 0.0, FALSE);
            setDiePosition("bdie3", 0.0, 0.0, FALSE);
            setDiePosition("bdie4", 0.0, 0.0, FALSE);
        }
        else if (command == "DICE_REMAINING") {
             string player = llList2String(params, 1);
             integer u1 = llList2Integer(params, 2);
             integer u2 = llList2Integer(params, 3);
             integer movesLeft = -1;
             if (llGetListLength(params) > 4) movesLeft = llList2Integer(params, 4);
             
             if (DEBUG_MODE) llOwnerSay("DEBUG RENDER: DICE_REMAINING - " + player + " u1:" + (string)u1 + " u2:" + (string)u2 + " moves:" + (string)movesLeft);
             
             if (gIsDoubles) {
                 if (movesLeft != -1) {
                     integer d1Alpha = 1; integer d2Alpha = 1; integer d3Alpha = 1; integer d4Alpha = 1;
                     if (movesLeft < 4) d4Alpha = 0; 
                     if (movesLeft < 3) d3Alpha = 0;
                     if (movesLeft < 2) d2Alpha = 0;
                     if (movesLeft < 1) d1Alpha = 0;
                     
                     string p = "b";
                     if (player == "white") p = "w";
                     
                     llSetLinkAlpha(GetLinkNumber(p+"die1"), d1Alpha, ALL_SIDES);
                     llSetLinkAlpha(GetLinkNumber(p+"die2"), d2Alpha, ALL_SIDES);
                     llSetLinkAlpha(GetLinkNumber(p+"die3"), d3Alpha, ALL_SIDES);
                     llSetLinkAlpha(GetLinkNumber(p+"die4"), d4Alpha, ALL_SIDES);
                 }
             } else {
                 integer d1Alpha = (u1 > 0);
                 integer d2Alpha = (u2 > 0);
                 string p = "b";
                 if (player == "white") p = "w";
                 
                 llSetLinkAlpha(GetLinkNumber(p+"die1"), d1Alpha, ALL_SIDES);
                 llSetLinkAlpha(GetLinkNumber(p+"die2"), d2Alpha, ALL_SIDES);
             }
        }
        else if (command == "VISUAL_ERROR") {
            key playerKey = (key)llList2String(params, 1);
            string error = llList2String(params, 2);
            
            if (turnIndicatorLink > 0) {
                llSetLinkPrimitiveParamsFast(turnIndicatorLink, [PRIM_COLOR, ALL_SIDES, <1,0,0>, 1.0]);
                llSetTimerEvent(1.0); 
            }
            
            string uuid = "";
            if (error == "NOT_YOUR_TURN") uuid = UUID_NOT_YOUR_TURN;
            else if (error == "NOT_YOUR_PIECE") uuid = UUID_NOT_YOUR_PIECE;
            else if (error == "NO_MOVES") uuid = UUID_NO_VALID_MOVES;
            
            if (uuid != "") showStatusIcon(uuid);
        }
        else if (command == "FIRST_TURN") {
            string player = llList2String(params, 1);
            integer d1 = llList2Integer(params, 2);
            integer d2 = llList2Integer(params, 3);
            
            // 1. Turn Indicator
            if (turnIndicatorLink > 0) {
                vector color = <1,1,1>; // White
                if (player == "black") color = <0,0,0>; // Black
                llSetLinkPrimitiveParamsFast(turnIndicatorLink, [PRIM_COLOR, ALL_SIDES, color, 1.0]);
            }
            
            // 2. Show Winner's Dice (and hide loser's)
            showPlayerDice(player);
            
            // 3. Update Dice Values
            updateDiceValues(player, d1, d2);
        }
        else if (command == "TURN_CHANGE") {
            string newTurn = llList2String(params, 1);
            
            // Show dice for the player whose turn it is
            showPlayerDice(newTurn);
            
            // Turn Indicator
            if (turnIndicatorLink > 0) {
                vector color = <1,1,1>; // White
                if (newTurn == "black") color = <0,0,0>; // Black
                llSetLinkPrimitiveParamsFast(turnIndicatorLink, [PRIM_COLOR, ALL_SIDES, color, 1.0]);
            }
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

            if (DEBUG_MODE != FALSE){
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
            
            if (DEBUG_MODE != FALSE) {
                llOwnerSay("DEBUG RENDER: MOVE_PIECE - " + piece + " from " + (string)from_point + " to " + (string)to_point);
            }
            
            // Update local BoardList immediately
            updateLocalBoard(piece, from_point, to_point);
            
            integer color;
            if(llGetSubString(piece, 0, 0) == "w") color = 0;
            else color = 1;
            
            // For bar moves, ensure bar lists are updated before refresh
            if (from_point == FROM_BAR) {
                // Remove from appropriate bar list
                if (llGetSubString(piece, 0, 0) == "w") {
                    integer index = llListFindList(WhiteBarList, [piece]);
                    if (index != -1) {
                        WhiteBarList = llDeleteSubList(WhiteBarList, index, index);
                        if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: Removed " + piece + " from WhiteBarList");
                    }
                } else {
                    integer index = llListFindList(BlackBarList, [piece]);
                    if (index != -1) {
                        BlackBarList = llDeleteSubList(BlackBarList, index, index);
                        if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: Removed " + piece + " from BlackBarList");
                    }
                }
                // Update bar display immediately
                Arrange(0, 24);
                Arrange(1, 25);
            } else {
                // For regular moves, update the source point
                Arrange(color, from_point);
                // AND update the destination point!
                Arrange(color, to_point);
            }
            
            // Force full refresh to ensure consistency
            llSleep(0.1); // Small delay to let core process
            llMessageLinked(LINK_SET, 0, "REQUEST_BOARD_STATE", NULL_KEY);
        }
        else if (command == "ARRANGE_POINT") {
            integer color = llList2Integer(params, 1);
            integer point = llList2Integer(params, 2);
            
            if (DEBUG_MODE != FALSE) {
                llOwnerSay("DEBUG: Arranging point " + (string)point + " for color " + (string)color);
            }
            
            Arrange(color, point);
        }
        else if(command == "HIT_PIECE") {
            string piece = llList2String(params, 1);
            integer from_point = llList2Integer(params, 2);
            
            if (DEBUG_MODE != FALSE) {
                llOwnerSay("DEBUG RENDER: HIT_PIECE received - " + piece + " from point " + (string)from_point);
            }
            
            // ONLY update bar lists - BOARD_STATE will handle actual piece movement
            if (llGetSubString(piece, 0, 0) == "w") {
                WhiteBarList += [piece];
                if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: Added " + piece + " to WhiteBarList");
            } else {
                BlackBarList += [piece];
                if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: Added " + piece + " to BlackBarList");
            }
            
            showStatusIcon(UUID_HIT);
        }
        else if(command == "BEAR_OFF_PIECE") {
            string piece = llList2String(params, 1);
            integer from_point = llList2Integer(params, 2);
            
            if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: Bear off piece " + piece + " from " + (string)from_point);
            
            // Update local BoardList immediately (to_point = -1 for bear-off)
            updateLocalBoard(piece, from_point, -1);
            
            // MOVE TO STORAGE
            ArrangeStoragePiece(piece);
            
            integer color;
            if(llGetSubString(piece, 0, 0) == "w") color = 0;
            else color = 1;
            
            Arrange(color, from_point);
            
            showStatusIcon(UUID_BEAR_OFF);
        }
        else if (command == "DICE_ROLL") {
            string player = llList2String(params, 1);
            integer die1 = llList2Integer(params, 2);
            integer die2 = llList2Integer(params, 3);
            
            if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG: Animating dice roll for " + player + ": " + (string)die1 + ", " + (string)die2);
            
            animateDiceRoll(player, die1, die2);
        }
        else if (command == "DICE_RESULT") {
            string player = llList2String(params, 1);
            integer die1 = llList2Integer(params, 2);
            integer die2 = llList2Integer(params, 3);
            
            if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG: Showing dice result for " + player + ": " + (string)die1 + ", " + (string)die2);
            
            // Check for Doubles
            gIsDoubles = (die1 == die2);
            
            if (player == "white") {
                // Show white dice, hide black dice
                setDiePosition("wdie1", 0.55, 0.55, TRUE);
                setDiePosition("wdie2", 0.45, 0.55, TRUE);
                llSetLinkAlpha(GetLinkNumber("wdie1"), 1.0, ALL_SIDES); // Reset Alpha
                llSetLinkAlpha(GetLinkNumber("wdie2"), 1.0, ALL_SIDES);
                
                if (gIsDoubles) {
                    setDiePosition("wdie3", 0.65, 0.65, TRUE); // Placeholder positions
                    setDiePosition("wdie4", 0.35, 0.35, TRUE);
                    rotateDieToValue("wdie3", die1);
                    rotateDieToValue("wdie4", die1);
                    llSetLinkAlpha(GetLinkNumber("wdie3"), 1.0, ALL_SIDES);
                    llSetLinkAlpha(GetLinkNumber("wdie4"), 1.0, ALL_SIDES);
                } else {
                     setDiePosition("wdie3", 0.5, 0.5, FALSE);
                     setDiePosition("wdie4", 0.5, 0.5, FALSE);
                }
                
                setDiePosition("bdie1", 0.45, 0.45, FALSE);
                setDiePosition("bdie2", 0.55, 0.45, FALSE);
                setDiePosition("bdie3", 0.5, 0.5, FALSE);
                setDiePosition("bdie4", 0.5, 0.5, FALSE);
                
            } else {
                // Black
                setDiePosition("bdie1", 0.45, 0.45, TRUE);
                setDiePosition("bdie2", 0.55, 0.45, TRUE);
                llSetLinkAlpha(GetLinkNumber("bdie1"), 1.0, ALL_SIDES);
                llSetLinkAlpha(GetLinkNumber("bdie2"), 1.0, ALL_SIDES);
                
                if (gIsDoubles) {
                    setDiePosition("bdie3", 0.65, 0.35, TRUE); 
                    setDiePosition("bdie4", 0.35, 0.65, TRUE);
                    rotateDieToValue("bdie3", die1);
                    rotateDieToValue("bdie4", die1);
                    llSetLinkAlpha(GetLinkNumber("bdie3"), 1.0, ALL_SIDES);
                    llSetLinkAlpha(GetLinkNumber("bdie4"), 1.0, ALL_SIDES);
                } else {
                     setDiePosition("bdie3", 0.5, 0.5, FALSE);
                     setDiePosition("bdie4", 0.5, 0.5, FALSE);
                }
                
                setDiePosition("wdie1", 0.55, 0.55, FALSE);
                setDiePosition("wdie2", 0.45, 0.55, FALSE);
                setDiePosition("wdie3", 0.5, 0.5, FALSE);
                setDiePosition("wdie4", 0.5, 0.5, FALSE);
            }
            
            updateDiceValues(player, die1, die2);
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
            
            // Clear status displays
            if (whiteStatusLink > 0) {
                llSetLinkTexture(whiteStatusLink, TEXTURE_BLANK, ALL_SIDES);
                llSetLinkAlpha(whiteStatusLink, 0.0, ALL_SIDES);
            }
            if (blackStatusLink > 0) {
                llSetLinkTexture(blackStatusLink, TEXTURE_BLANK, ALL_SIDES);
                llSetLinkAlpha(blackStatusLink, 0.0, ALL_SIDES);
            }
            // Reset turn indicator (e.g. to neutral or white)
            if (turnIndicatorLink > 0) {
                llSetLinkPrimitiveParamsFast(turnIndicatorLink, [PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
            }

            llSleep(0.5); // Small delay to ensure BOARD_STATE is processed
            refreshAllPieces(); // Force immediate refresh on reset
            
            // Also hide any markers
            hideMarker(1);
            hideMarker(2);
            hideMarker(3);
            
            resetDice();
            if (DEBUG_MODE != FALSE) {
                llOwnerSay("DEBUG: Render state reset and refreshed");
            }
            // Move to storage on reset
            resetToStorage();
        }
        else if (command == "GAME_OVER") {
             if (DEBUG_MODE != FALSE) llOwnerSay("DEBUG RENDER: Game Over received - waiting 2s then storage");
             llSleep(2.0);
             resetToStorage();
        }
    }
}