// VISUAL TEST HARNESS - DUPLICATE SCANNER
// Drop this into your ROOT object.
// It will find ALL prims with the target names and try to light them ALL up.

integer state_index = 0;
list turnIndicatorLinks = [];
list whiteStatusLinks = [];
list blackStatusLinks = [];

// UUIDs
string UUID_NOT_YOUR_TURN = "3261a0eb-dfaf-97bf-c540-ea2ef20af175";
string UUID_NOT_YOUR_PIECE = "eba0c4b0-f618-74c8-ffac-c4b63b6c5443";
string UUID_NO_VALID_MOVES = "e0415315-4b10-930c-933d-47ba85ba6c92";

ScanLinkset() {
    turnIndicatorLinks = [];
    whiteStatusLinks = [];
    blackStatusLinks = [];
    
    integer numprims = llGetNumberOfPrims();
    llOwnerSay("Scanning " + (string)numprims + " total prims...");
    
    integer i;
    for(i = 1; i <= numprims; i++) {
        string rawName = llGetLinkName(i);
        string name = llStringTrim(llToLower(rawName), STRING_TRIM);
        
        if (name == "turn_indicator") {
            turnIndicatorLinks += i;
            if (rawName != "turn_indicator") llOwnerSay("WARNING: Link " + (string)i + " matches loosely: '" + rawName + "'");
        }
        else if (name == "status_display_white") {
            whiteStatusLinks += i;
            if (rawName != "status_display_white") llOwnerSay("WARNING: Link " + (string)i + " matches loosely: '" + rawName + "'");
        }
        else if (name == "status_display_black") {
            blackStatusLinks += i;
            if (rawName != "status_display_black") llOwnerSay("WARNING: Link " + (string)i + " matches loosely: '" + rawName + "'");
        }
    }
    
    llOwnerSay("Scan Results (Inclusive):");
    llOwnerSay("turn_indicator: Found " + (string)llGetListLength(turnIndicatorLinks) + " objects: " + llList2CSV(turnIndicatorLinks));
    llOwnerSay("status_display_white: Found " + (string)llGetListLength(whiteStatusLinks) + " objects: " + llList2CSV(whiteStatusLinks));
    llOwnerSay("status_display_black: Found " + (string)llGetListLength(blackStatusLinks) + " objects: " + llList2CSV(blackStatusLinks));
    
    if (llGetListLength(turnIndicatorLinks) == 0 && llGetListLength(whiteStatusLinks) == 0) {
         llOwnerSay("CRITICAL: No matches found even with fuzzy search (ignoring case/spaces). Check object names!");
    }
}

ApplyToLinks(list links, list params) {
    integer i;
    for(i=0; i<llGetListLength(links); i++) {
        integer link = llList2Integer(links, i);
        llSetLinkPrimitiveParamsFast(link, params);
        if (llListFindList(whiteStatusLinks + blackStatusLinks, [link]) != -1) {
             llSetLinkAlpha(link, 1.0, ALL_SIDES);
        }
    }
}

ApplyToLinksAlpha(list links, float alpha) {
    integer i;
    for(i=0; i<llGetListLength(links); i++) {
        integer link = llList2Integer(links, i);
        llSetLinkAlpha(link, alpha, ALL_SIDES);
    }
}

default {
    state_entry() {
        ScanLinkset();
        llOwnerSay("Touch to cycle tests on ALL found objects.");
    }

    touch_start(integer total_number) {
        state_index++;
        if (state_index > 3) state_index = 0;
        
        if (state_index == 0) {
            llOwnerSay("Test 0: Resetting/Clearing All found objects");
            if (turnIndicatorLinks != []) ApplyToLinks(turnIndicatorLinks, [PRIM_TEXTURE, ALL_SIDES, TEXTURE_BLANK, <1,1,0>, ZERO_VECTOR, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
            if (whiteStatusLinks != []) ApplyToLinks(whiteStatusLinks, [PRIM_TEXTURE, ALL_SIDES, TEXTURE_BLANK, <1,1,0>, ZERO_VECTOR, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0]);
            if (blackStatusLinks != []) ApplyToLinks(blackStatusLinks, [PRIM_TEXTURE, ALL_SIDES, TEXTURE_BLANK, <1,1,0>, ZERO_VECTOR, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0]);
             
            if (whiteStatusLinks != []) ApplyToLinksAlpha(whiteStatusLinks, 0.0);
            if (blackStatusLinks != []) ApplyToLinksAlpha(blackStatusLinks, 0.0);
        }
        else if (state_index == 1) {
            llOwnerSay("Test 1: Turn Indicator RED, Status 'Not Your Turn'");
            if (turnIndicatorLinks != []) ApplyToLinks(turnIndicatorLinks, [PRIM_COLOR, ALL_SIDES, <1,0,0>, 1.0]);
            
            if (whiteStatusLinks != []) {
                ApplyToLinks(whiteStatusLinks, [PRIM_TEXTURE, ALL_SIDES, UUID_NOT_YOUR_TURN, <1,1,0>, ZERO_VECTOR, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
            }
        }
        else if (state_index == 2) {
            llOwnerSay("Test 2: Turn Indicator BLACK, Status 'Not Your Piece'");
            if (turnIndicatorLinks != []) ApplyToLinks(turnIndicatorLinks, [PRIM_COLOR, ALL_SIDES, <0,0,0>, 1.0]);
            
            if (whiteStatusLinks != []) {
                ApplyToLinks(whiteStatusLinks, [PRIM_TEXTURE, ALL_SIDES, UUID_NOT_YOUR_PIECE, <1,1,0>, ZERO_VECTOR, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
            }
        }
        else if (state_index == 3) {
            llOwnerSay("Test 3: Turn Indicator WHITE, Status 'No Moves'");
            if (turnIndicatorLinks != []) ApplyToLinks(turnIndicatorLinks, [PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
            
            if (whiteStatusLinks != []) {
                ApplyToLinks(whiteStatusLinks, [PRIM_TEXTURE, ALL_SIDES, UUID_NO_VALID_MOVES, <1,1,0>, ZERO_VECTOR, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
            }
        }
    }
}
