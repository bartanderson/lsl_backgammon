// VISUAL TEST HARNESS
// Drop this into your 'turn_indicator' or 'status_display' object to test parameters.
// Touch the object to cycle through states.

integer state_index = 0;

// UUIDs from backgammon_render.lsl
string UUID_NOT_YOUR_TURN = "3261a0eb-dfaf-97bf-c540-ea2ef20af175";
string UUID_NOT_YOUR_PIECE = "eba0c4b0-f618-74c8-ffac-c4b63b6c5443";
string UUID_NO_VALID_MOVES = "e0415315-4b10-930c-933d-47ba85ba6c92";

default {
    state_entry() {
        llOwnerSay("Visual Test Harness Ready.");
        llOwnerSay("Touch to cycle: White -> Black -> Red (Error) -> Icon 1 -> Icon 2 -> Icon 3");
    }

    touch_start(integer total_number) {
        state_index++;
        if (state_index > 5) state_index = 0;
        
        if (state_index == 0) {
            llOwnerSay("Test 0: Turn Indicator - WHITE <1,1,1>");
            // Exact code from Render:
            llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
        }
        else if (state_index == 1) {
            llOwnerSay("Test 1: Turn Indicator - BLACK <0,0,0>");
            // Exact code from Render:
            llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_COLOR, ALL_SIDES, <0,0,0>, 1.0]);
        }
        else if (state_index == 2) {
            llOwnerSay("Test 2: Turn Indicator - ERROR RED <1,0,0>");
            // Exact code from Render:
            llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_COLOR, ALL_SIDES, <1,0,0>, 1.0]);
        }
        else if (state_index == 3) {
            llOwnerSay("Test 3: Status Display - 'Not Your Turn'");
            // Exact code from Render (Face 0):
            llSetLinkPrimitiveParamsFast(LINK_THIS, [
                PRIM_TEXTURE, 0, UUID_NOT_YOUR_TURN, <1,1,0>, ZERO_VECTOR, 0.0, 
                PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0
            ]);
            llSetAlpha(1.0, ALL_SIDES);
        }
        else if (state_index == 4) {
            llOwnerSay("Test 4: Status Display - 'Not Your Piece'");
            // Exact code from Render (Face 0):
            llSetLinkPrimitiveParamsFast(LINK_THIS, [
                PRIM_TEXTURE, 0, UUID_NOT_YOUR_PIECE, <1,1,0>, ZERO_VECTOR, 0.0, 
                PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0
            ]);
            llSetAlpha(1.0, ALL_SIDES);
        }
        else if (state_index == 5) {
            llOwnerSay("Test 5: Status Display - 'No Valid Moves'");
            // Exact code from Render (Face 0):
            llSetLinkPrimitiveParamsFast(LINK_THIS, [
                PRIM_TEXTURE, 0, UUID_NO_VALID_MOVES, <1,1,0>, ZERO_VECTOR, 0.0, 
                PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0
            ]);
            llSetAlpha(1.0, ALL_SIDES);
        }
    }
}
