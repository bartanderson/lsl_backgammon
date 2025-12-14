// VISUAL DEBUG - TOUCH IDENTIFIER
// Drop this in the ROOT object.
// Touch any part of the linkset to identify it.

integer turnIndicatorLink = 0;
integer whiteStatusLink = 0;
integer blackStatusLink = 0;

ScanLinkset() {
    integer numprims = llGetNumberOfPrims();
    integer i;
    for(i = 1; i <= numprims; i++) {
        string name = llGetLinkName(i);
        if(name == "turn_indicator") turnIndicatorLink = i;
        else if(name == "status_display_white") whiteStatusLink = i;
        else if(name == "status_display_black") blackStatusLink = i;
    }
    llOwnerSay("Script sees: Turn=" + (string)turnIndicatorLink + ", WhiteStatus=" + (string)whiteStatusLink + ", BlackStatus=" + (string)blackStatusLink);
}

default {
    state_entry() {
        ScanLinkset();
        llOwnerSay("TOUCH IDENTIFIER READY.");
        llOwnerSay("Touch the visual objects (Sphere, Displays) to see if they match the script's targets.");
    }

    touch_start(integer total_number) {
        integer link = llDetectedLinkNumber(0);
        string name = llGetLinkName(link);
        
        llOwnerSay("You Touched: Link " + (string)link + " | Name: '" + name + "'");
        
        string match = "";
        if (link == turnIndicatorLink) match = "MATCHES turn_indicator";
        else if (link == whiteStatusLink) match = "MATCHES status_display_white";
        else if (link == blackStatusLink) match = "MATCHES status_display_black";
        
        if (match != "") {
            llOwnerSay(">> SUCCESS: This object " + match + "! (Try the color test again?)");
            // Flash it just to be sure
            llSetLinkPrimitiveParamsFast(link, [PRIM_FULLBRIGHT, ALL_SIDES, TRUE, PRIM_GLOW, ALL_SIDES, 0.5]);
            llSleep(0.5);
            llSetLinkPrimitiveParamsFast(link, [PRIM_FULLBRIGHT, ALL_SIDES, FALSE, PRIM_GLOW, ALL_SIDES, 0.0]);
        } else {
            llOwnerSay(">> FAIL: This object is NOT targeted by the script. Name it correctly!");
            llOwnerSay("Expected names: 'turn_indicator', 'status_display_white', 'status_display_black'");
        }
    }
}
