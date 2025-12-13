// BACKGAMMON DEBUG CONTROLLER
// Reads debug.txt notecard and broadcasts debug state to all scripts

string DEBUG_NOTECARD = "debug.txt";
integer gDebugMode = FALSE;
key gNotecardQuery;
integer gNotecardLine;

// Broadcast debug state to all scripts
broadcastDebugState() {
    llMessageLinked(LINK_SET, 0, "DEBUG_STATE|" + (string)gDebugMode, NULL_KEY);
}

default {
    state_entry() {
        // Check if debug.txt notecard exists
        if (llGetInventoryType(DEBUG_NOTECARD) == INVENTORY_NOTECARD) {
            llOwnerSay("Debug system: Found " + DEBUG_NOTECARD + ", reading...");
            gNotecardQuery = llGetNotecardLine(DEBUG_NOTECARD, 0);
        } else {
            llOwnerSay("Debug system: No " + DEBUG_NOTECARD + " found. Debug mode OFF.");
            gDebugMode = FALSE;
            broadcastDebugState();
        }
    }
    
    dataserver(key query_id, string data) {
        if (query_id == gNotecardQuery) {
            if (data == EOF) {
                llOwnerSay("Debug system: Notecard empty. Debug mode OFF.");
                gDebugMode = FALSE;
            } else {
                // Remove whitespace and convert to lowercase for easy comparison
                data = llToLower(llStringTrim(data, STRING_TRIM));
                
                if (data == "on" || data == "1" || data == "true" || data == "yes" || data == "enable") {
                    gDebugMode = TRUE;
                    llOwnerSay("Debug system: Debug mode ON");
                } else if (data == "off" || data == "0" || data == "false" || data == "no" || data == "disable") {
                    gDebugMode = FALSE;
                    llOwnerSay("Debug system: Debug mode OFF");
                } else {
                    llOwnerSay("Debug system: Invalid value in " + DEBUG_NOTECARD + ". Use 'ON' or 'OFF'. Debug mode OFF.");
                    gDebugMode = FALSE;
                }
            }
            broadcastDebugState();
        }
    }
    
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            // Notecard was added/modified, reload it
            if (llGetInventoryType(DEBUG_NOTECARD) == INVENTORY_NOTECARD) {
                llOwnerSay("Debug system: " + DEBUG_NOTECARD + " changed, reloading...");
                gNotecardQuery = llGetNotecardLine(DEBUG_NOTECARD, 0);
            } else {
                llOwnerSay("Debug system: " + DEBUG_NOTECARD + " removed. Debug mode OFF.");
                gDebugMode = FALSE;
                broadcastDebugState();
            }
        }
    }
}