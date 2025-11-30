# Bear-Off Strategy Bug Analysis

## Issue
AI is moving pieces forward within home board instead of bearing off when exact die matches are available.

## Current AI Logic (backgammon_AI.lsl)

### generateRandomMove (line 354-365)
```lsl
if (mustBearOff(currentTurn)) {
    if (DEBUG_MODE) llOwnerSay("DEBUG AI: Player must bear off - only considering bear off moves");
    string bearOffMove = generateBearOffMove();
    if (bearOffMove != "") {
        return bearOffMove;
    } else {
        // CANNOT BEAR OFF - try to move forward in home board
        if (DEBUG_MODE) llOwnerSay("DEBUG AI: Cannot bear off - trying to move within home board");
        return generateHomeBoardMove();
    }
}
```

### The Problem
When `generateBearOffMove()` returns `""` (no valid bear-off found), the AI falls back to `generateHomeBoardMove()`.

**But the fallback shouldn't happen if there ARE valid bear-off moves!**

### Possible Causes
1. **AI's isValidBearOff rejects valid moves** - The AI has its own `isValidBearOff` function (line 580) that might be more restrictive than Core's
2. **findBearOffMove searches in wrong order** - It searches from furthest to closest, which is correct for strategy
3. **Dice already consumed** - If `currentDie1` or `currentDie2` are 0, the AI won't find moves

## Need Log File
Once you paste the log into `test_output_bearoff_bug2.txt`, I can see:
- What dice were rolled
- What bear-off moves the AI tried
- Why it chose home board moves instead
- Whether the dice values were correct when AI was triggered
