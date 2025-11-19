# LSL Backgammon Code Evolution Analysis

## Critical Function: `isValidBearOff`

This analysis compares the `isValidBearOff` function across chronological versions to understand how the bear-off validation logic evolved and when problems were potentially introduced.

---

## Version 1: `orig/core.bak.lsl` (44,330 bytes - EARLIEST)

**Lines 394-420**

```lsl
integer isValidBearOff(integer from_point, integer die_value, integer color) {
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG isValidBearOff: Checking point " + (string)from_point + 
                  " with die " + (string)die_value + " for color " + (string)color);
    }
    
    // Check basic conditions
    if (!allPiecesInHomeBoard(color)) {
        if (DEBUG_MODE) llOwnerSay("DEBUG: Not all pieces in home board");
        return FALSE;
    }
    
    if (!isPointInHomeBoard(from_point, color)) {
        if (DEBUG_MODE) llOwnerSay("DEBUG: Point not in home board");
        return FALSE;
    }
    
    // Check exact/overshoot OR valid undershoot
    if (canBearOffExactOrOvershoot(from_point, die_value, color) || 
        canBearOffUndershoot(from_point, die_value, color)) {
        if (DEBUG_MODE) llOwnerSay("DEBUG: Bear off valid");
        return TRUE;
    }
    
    if (DEBUG_MODE) llOwnerSay("DEBUG: Bear off invalid");
    return FALSE;
}
```

**Characteristics:**
- ✅ **Most lenient** - allows both exact/overshoot AND valid undershoots
- Uses helper functions: `canBearOffExactOrOvershoot()` and `canBearOffUndershoot()`
- Detailed DEBUG logging
- **Permits undershoot** when no pieces require larger dice

---

## Version 2: `orig/backgammon_core.lsl` (46,725 bytes - Identical to Nov 1 backup)

**Lines 366-405**

```lsl
integer isValidBearOff(integer from_point, integer die_value, integer color) {
    if (!allPiecesInHomeBoard(color) || !isPointInHomeBoard(from_point, color)) return FALSE;
    
    integer requiredDistance = getRequiredBearOffDistance(from_point, color);
    string playerColor = "b";
    if(color == 0) playerColor = "w";
    
    // Check for exact matches
    integer i;
    if (color == 0) {
        for (i = WHITE_HOME_START; i <= WHITE_HOME_END; i++) {
            if (hasPlayerPieceAtPoint(i, playerColor) && die_value == getRequiredBearOffDistance(i, color)) {
                if (die_value != requiredDistance) return FALSE; // Exact match exists elsewhere
                i = WHITE_HOME_END + 1; // break
            }
        }
    } else {
        for (i = BLACK_HOME_START; i >= BLACK_HOME_END; i--) {
            if (hasPlayerPieceAtPoint(i, playerColor) && die_value == getRequiredBearOffDistance(i, color)) {
                if (die_value != requiredDistance) return FALSE; // Exact match exists elsewhere
                i = BLACK_HOME_END - 1; // break
            }
        }
    }
    
    if (die_value >= requiredDistance) return TRUE;
    
    // Check undershoot
    if (color == 0) {
        for (i = WHITE_HOME_START; i < from_point; i++) {
            if (hasPlayerPieceAtPoint(i, playerColor)) return FALSE;
        }
    } else {
        for (i = from_point + 1; i <= BLACK_HOME_START; i++) {
            if (hasPlayerPieceAtPoint(i, playerColor)) return FALSE;
        }
    }
    
    return TRUE;
}
```

**Characteristics:**
- ✅ **More restrictive** - enforces exact match priority
- ⚠️ **Complex logic** - checks if exact matches exist elsewhere before allowing move
- Still allows undershoots when no pieces require larger dice
- More efficient (single-line early returns)
- Added "exact match exists elsewhere" restriction

---

## Version 3: `backgammon_core-bkup-11-03-2025.lsl` (49,108 bytes - LARGEST, Nov 3)

**Lines 447-475**

```lsl
// Update the isValidBearOff function to be more restrictive
integer isValidBearOff(integer from_point, integer die_value, integer color) {
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG isValidBearOff: Checking point " + (string)from_point + 
                  " with die " + (string)die_value + " for color " + (string)color);
    }
    
    // Check basic conditions
    if (!allPiecesInHomeBoard(color)) {
        if (DEBUG_MODE) llOwnerSay("DEBUG: Not all pieces in home board");
        return FALSE;
    }
    
    if (!isPointInHomeBoard(from_point, color)) {
        if (DEBUG_MODE) llOwnerSay("DEBUG: Point not in home board");
        return FALSE;
    }
    
    // Calculate required bear off distance
    integer requiredDistance = calculateRequiredBearOffDistance(from_point, color);
    
    // Only allow exact match or overshoot
    if (die_value >= requiredDistance) {
        if (DEBUG_MODE) llOwnerSay("DEBUG: Bear off valid - die " + (string)die_value + " >= required " + (string)requiredDistance);
        return TRUE;
    }
    
    if (DEBUG_MODE) llOwnerSay("DEBUG: Bear off invalid - die " + (string)die_value + " < required " + (string)requiredDistance);
    return FALSE;
}
```

**Characteristics:**
- ❌ **TOO RESTRICTIVE** - comment says "more restrictive" 
- ❌ **Removed undershoot logic** entirely
- Only allows exact match or overshoot: `die_value >= requiredDistance`
- **THIS IS A BUG** - backgammon rules allow using smaller dice to bear off from innermost point
- DEBUG logging retained
- Simpler but **INCORRECT** implementation

---

## Version 4: `backgammon_core.lsl` (27,036 bytes - CURRENT, Nov 10+ refactoring)

**Lines 215-272**

```lsl
integer isValidBearOff(integer from_point, integer die_value, integer color) {
    if (!allPiecesInHomeBoard(color)) {
        return FALSE;
    }
    
    // Check if point is in player's home board
    integer inHomeBoard = FALSE;
    if (color == 0) { // White
        if (from_point >= WHITE_HOME_START && from_point <= WHITE_HOME_END) {
            inHomeBoard = TRUE;
        }
    } else { // Black
        if (from_point <= BLACK_HOME_START && from_point >= BLACK_HOME_END) {
            inHomeBoard = TRUE;
        }
    }
    
    if (!inHomeBoard) {
        return FALSE;
    }
    
    // Calculate required bear off distance
    integer requiredDistance;
    if (color == 0) { // White
        requiredDistance = 24 - from_point;
    } else { // Black
        requiredDistance = from_point + 1;
    }
    
    // Exact match or overshoot is always valid
    if (die_value >= requiredDistance) {
        return TRUE;
    }
    
    // For undershoot: check if there are pieces requiring larger dice
    string playerColor = "w";
    if (color == 1) playerColor = "b";
    
    if (color == 0) { // White
        integer i;
        for (i = WHITE_HOME_START; i < from_point; i++) {
            string point = llList2String(BoardList, i);
            if (point != "" && llSubStringIndex(point, playerColor) != -1) {
                return FALSE;
            }
        }
    } else { // Black
        integer i;
        for (i = from_point + 1; i <= BLACK_HOME_START; i++) {
            string point = llList2String(BoardList, i);
            if (point != "" && llSubStringIndex(point, playerColor) != -1) {
                return FALSE;
            }
        }
    }
    
    return TRUE;
}
```

**Characteristics:**
- ✅ **CORRECT** - Fixed the Nov 3 bug by re-adding undershoot logic
- ✅ Allows undershoots when no pieces require larger dice
- No DEBUG logging (DEBUG_MODE = FALSE at top)
- Inline calculations for efficiency (no helper function calls)
- More verbose home board checking (not using helper)
- **This is similar to Version 1 but optimized**

---

## Analysis Summary

### Timeline of Changes:

1. **Earliest (core.bak.lsl)**: ✅ Correct bear-off logic with helper functions
2. **Nov 1-3 (orig/backgammon_core.lsl)**: ⚠️ Added complex "exact match priority" logic
3. **Nov 3 (11-03 backup)**: ❌ **BROKE LOGIC** - removed undershoot completely
4. **Nov 10+ (current)**: ✅ **FIXED** - restored undershoot logic, optimized implementation

### Critical Bug Introduced on Nov 3:

The Nov 3 version **removed undershoot logic entirely**, making it impossible to bear off with dice that are smaller than the exact distance EVEN when no pieces require larger dice. This violates backgammon rules.

**Example of bug:**
- White has a piece on point 23 (requires die of 1)
- White has a piece on point 21 (requires die of 3)
- White rolls a 2
- **Nov 3 version**: ❌ Cannot use 2 to bear off from point 21
- **Correct version**: ✅ Can use 2 to bear off from point 21 (no pieces further back)

### Nov 10 Major Refactoring:

The file size dropped from **49,108 bytes to 27,036 bytes** (45% reduction). Changes include:

1. ✅ **Fixed `isValidBearOff`** bug introduced on Nov 3
2. Removed DEBUG logging (set `DEBUG_MODE = FALSE`)
3. Inlined many helper functions for efficiency
4. Simplified code structure
5. Removed complex "exact match exists elsewhere" checks from Nov 1-3
6. Returned to simpler, more correct logic similar to earliest version

---

## Recommendation

**The current version (`backgammon_core.lsl`) has the correct bear-off logic.** 

The bug was introduced on Nov 3 and fixed by Nov 10. If you're experiencing bear-off issues, ensure you're using the current version, not the Nov 3 backup.
