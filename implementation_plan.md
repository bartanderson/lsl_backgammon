# Implementation Plan - Dynamic AI Strategy

## Goal
Improve Level 3 AI (Strategic) behavior to prevent it from holding anchors (pieces in opponent's home) for too long when it should be racing.

## Problem Analysis
The user observed that the AI holds pieces in the opponent's home board even when the opponent is bearing off.
- **Root Cause:** The `W_ANCHOR` weight is a static `50` points.
- **Effect:** The AI sees breaking an anchor as a `-50` point penalty. Unless the move gains >50 points worth of pip advantage (which is huge, as `W_PIP_WEIGHT` is 1), the AI will refuse to break the anchor.
- **Result:** The AI gets stuck holding anchors while losing the race.

## Proposed Solution: Dynamic Anchor Weighting
We will modify `evaluateBoard` in `backgammon_AI_brain.lsl` to adjust the value of `W_ANCHOR` based on the **Pip Difference** (Race State).

### Logic
1.  **Calculate Pip Difference:** `pipDiff = oppPips - ourPips`
    - Positive `pipDiff` means we are **ahead** (winning the race).
    - Negative `pipDiff` means we are **behind** (losing the race).

2.  **Adjust Anchor Weight:**
    - **Winning Race (`pipDiff > 15`):** Reduce `W_ANCHOR` significantly (e.g., to `10` or `0`). This tells the AI: "You are winning, don't stay back. RUN!"
    - **Losing/Close Race:** Keep `W_ANCHOR` high (`50`). This tells the AI: "You are behind, hold the anchor to hit the opponent."

### Code Changes
**File:** `backgammon_AI_brain.lsl`

#### [MODIFY] `evaluateBoard` function
```lsl
    // ... existing pip calculation ...
    integer pipDiff = oppPips - ourPips;
    
    // ... existing scoring ...

    // 3. Anchor Control (Points in Opponent's Home)
    // ... existing range setup ...
    
    integer effectiveAnchorWeight = W_ANCHOR;
    
    // DYNAMIC ADJUSTMENT:
    // If we are significantly ahead in the race (lower pips), anchors are less valuable.
    // We want to break contact and race home.
    if (pipDiff > 20) {
        effectiveAnchorWeight = 10; // Drastically reduce value to encourage running
    } else if (pipDiff > 0) {
        effectiveAnchorWeight = 25; // Slightly reduce if slightly ahead
    }
    // If pipDiff <= 0 (behind), keep default W_ANCHOR (50) to play a backgame/holding game
    
    score += anchorCount * effectiveAnchorWeight; 
```

## Verification Plan
1.  **Manual Test:** Play a game against Level 3.
2.  **Scenario Test:** Set up a board state (using a temporary test script or just playing) where the AI is ahead in pips but has an anchor. Verify it chooses to run.
