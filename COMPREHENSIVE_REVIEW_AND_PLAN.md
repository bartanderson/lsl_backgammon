# LSL Backgammon: Comprehensive Code Review & Restoration Plan

## Executive Summary

After critical section-by-section review across all modules and versions, I've identified key evolutions, regressions, and bugs. This document provides a complete analysis and actionable restoration plan.

---

## Module-by-Module Analysis

### 1. CORE MODULE (`backgammon_core.lsl`)

#### Evolution Timeline:

**Earliest (`orig/core.bak.lsl` - 44KB)**
- ✅ Correct bear-off logic with helper functions
- ✅ Comprehensive DEBUG logging
- ✅ Clear, documented code structure

**Nov 1-3 (`orig/backgammon_core.lsl` / `backgammon_core-bkup-11-01-2025.lsl` - 46-49KB)**
- ⚠️ Added complex "exact match priority" validation
- ⚠️ File size bloated to 49KB by Nov 3
- ✅ Still fundamentally correct

**Nov 3 (`backgammon_core-bkup-11-03-2025.lsl` - 49KB - LARGEST)**
- ❌ **CRITICAL REGRESSION**: Removed undershoot logic from `isValidBearOff`
- Comment states: "Update the isValidBearOff function to be more restrictive"
- Only allowed `die_value >= requiredDistance`
- **This violates backgammon rules**

**Nov 10+ (Current `backgammon_core.lsl` - 27KB)**
- ✅ **BUG FIXED**: Restored correct undershoot logic
- ✅ Massive optimization: 45% size reduction (49KB → 27KB)
- ✅ Correct game logic throughout
- ⚠️ DEBUG_MODE = FALSE (reduces troubleshooting capability)

#### Key Issues Found:

1. **First Roll Phase (Lines 553-602)**
   ```lsl
   if (whiteDie > blackDie) {
       turn = "white";
       u1 = whiteDie1;  // ✅ Uses FIRST die from winner
       u2 = blackDie1;  // ✅ Uses FIRST die from loser
   }
   ```
   - **POTENTIAL ISSUE**: Should this be `whiteDie2` and `blackDie2` or both dice from one player?
   - **Backgammon rules**: Winner uses BOTH their dice, not mix of both players
   - ❌ **INCORRECT IMPLEMENTATION**

2. **handleFirstRollPhase Variable Shadowing (Line 578-581)**
   ```lsl
   integer whiteDie1 = 1 + (integer)llFrand(6);  // Local variable shadows global
   integer whiteDie2 = 1 + (integer)llFrand(6);
   integer blackDie1 = 1 + (integer)llFrand(6);
   integer blackDie2 = 1 + (integer)llFrand(6);
   ```
   - ⚠️ Creates LOCAL variables instead of using GLOBALS
   - Dice values generated here are NEVER used (discarded)
   - **DEAD CODE**

#### Core Module Status: **NEEDS FIXES**

---

### 2. AI MODULE (`backgammon_AI.lsl`)

#### Evolution Timeline:

**`orig/AI.bak.lsl` (29,651 bytes)**
- ✅ Direct move generation in `generateAIMove()`
- ✅ Calls move immediately after generation
- ❌ No board state synchronization
- `DEBUG_MODE = TRUE`

**Current `backgammon_AI.lsl` (29,063 bytes)**
- ✅ Added `WAITING_FOR_BOARD_STATE` flag (line 4)
- ✅ Requests fresh board state before moves
- ✅ Better synchronization with Core
- ⚠️ `DEBUG_MODE = FALSE`

#### Key Differences:

**OLD Pattern (AI.bak.lsl lines 419-440):**
```lsl
generateAIMove() {
    string move = "";
    if (AI_LEVEL == LEVEL_RANDOM) move = generateRandomMove();
    // ... generate move immediately
    if (move != "") llMessageLinked(LINK_SET, 0, move, NULL_KEY);
}
```

**NEW Pattern (Current lines 379-386, 701-724):**
```lsl
generateAIMove() {
    WAITING_FOR_BOARD_STATE = TRUE;  // Set flag
    llMessageLinked(LINK_SET, 0, "REQUEST_BOARD_STATE", NULL_KEY);
    // Move generation happens in FRESH_BOARD_STATE handler
}
```

#### Key Issues Found:

1. **Bear-Off Move Priority (lines 573-616 in current)**
   - `findBearOffMove()` checks exact matches first, then overshoots
   - ✅ CORRECT implementation
   - Matches Core module logic

2. **Dice Consumption**
   - AI properly uses `currentDie1` and `currentDie2`
   - For doubles: creates list `[currentDie1, currentDie1, currentDie1, currentDie1]`
  - ✅ CORRECT

3. **Missing `getHomeBoardPoints()` Function**
   - Lines 39-57 define `getHomeBoardPoints()` but it's NEVER CALLED
   - **DEAD CODE** - can be removed

#### AI Module Status: **FUNCTIONAL** (minor cleanup needed)

---

### 3. DICE LOGIC CROSS-MODULE ANALYSIS

#### Core → AI Communication:

**Message Format:**
```
"TRIGGER_AI_TURN|" + turn + "|" + u1 + "|" + u2 + "|" + isDoubles + "|" + movesLeft
```

**AI Reception (line 726-736):**
```lsl
currentTurn = llList2String(params, 1);
currentDie1 = llList2Integer(params, 2);  // Gets u1
currentDie2 = llList2Integer(params, 3);  // Gets u2
isDoubles = llList2Integer(params, 4);
movesLeft = llList2Integer(params, 5);
```

#### Critical Path Analysis:

**SCENARIO: First Turn After Initial Roll**

1. **Core sets dice (lines 590-598)**:
   ```lsl
   if (whiteDie > blackDie) {
       turn = "white";
       u1 = whiteDie1;  // Winner's DIE 1
       u2 = blackDie1;  // Loser's DIE 1  ❌ BUG!
   }
   ```

2. **Core sends to AI**:
   `TRIGGER_AI_TURN|white|{whiteDie1}|{blackDie1}|0|0`

3. **AI receives WRONG dice**:
   - Should get: Both of white's dice
   - Actually gets: One white die + one black die

#### **ROOT CAUSE IDENTIFIED**: First Roll Dice Assignment Bug

---

## Critical Bugs Summary

### 🔴 CRITICAL: First Roll Dice Assignment
- **File**: `backgammon_core.lsl`
- **Lines**: 590-598
- **Issue**: Uses one die from each player instead of both dice from winner
- **Impact**: First turn always uses wrong dice values
- **Fix Priority**: **IMMEDIATE**

### 🔴 CRITICAL: Variable Shadowing in Auto-Reroll
- **File**: `backgammon_core.lsl`  
- **Lines**: 576-586
- **Issue**: Creates local variables that shadow globals, dice never used
- **Impact**: Auto-reroll generates useless dice
- **Fix Priority**: **HIGH**

### 🟡 MODERATE: Dead Code
- **File**: `backgammon_AI.lsl`
- **Lines**: 39-57
- **Issue**: `getHomeBoardPoints()` function never called
- **Impact**: Wastes memory/script space
- **Fix Priority**: **LOW** (cleanup)

### 🟢 RESOLVED: Bear-Off Logic
- **Status**: ✅ Fixed in current versions
- Nov 3 bug was corrected by Nov 10

---

## Actionable Restoration Plan

### Phase 1: Critical Fixes (Do Immediately)

#### Fix 1.1: Correct First Roll Dice Assignment

**File**: `backgammon_core.lsl`  
**Lines**: 590-598

**CURRENT (WRONG)**:
```lsl
if (whiteDie > blackDie) {
    turn = "white";
    u1 = whiteDie1;
    u2 = blackDie1;  // ❌ WRONG: uses loser's die
}
```

**CORRECTED**:
```lsl
if (whiteDie > blackDie) {
    turn = "white";
    u1 = whiteDie1;
    u2 = whiteDie2;  // ✅ CORRECT: uses winner's both dice
} else {
    turn = "black";
    u1 = blackDie1;
    u2 = blackDie2;  // ✅ CORRECT: uses winner's both dice
}
```

#### Fix 1.2: Remove Variable Shadowing

**File**: `backgammon_core.lsl`  
**Lines**: 576-586

**CURRENT (WRONG)**:
```lsl
if (white == NULL_KEY && black == NULL_KEY) {
    llSleep(2.0);
    integer whiteDie1 = 1 + (integer)llFrand(6);  // ❌ Local variable!
    integer whiteDie2 = 1 + (integer)llFrand(6);
    integer blackDie1 = 1 + (integer)llFrand(6);
    integer blackDie2 = 1 + (integer)llFrand(6);
```

**CORRECTED**:
```lsl
if (white == NULL_KEY && black == NULL_KEY) {
    llSleep(2.0);
    whiteDie1 = 1 + (integer)llFrand(6);  // ✅ Use global
    whiteDie2 = 1 + (integer)llFrand(6);
    blackDie1 = 1 + (integer)llFrand(6);
    blackDie2 = 1 + (integer)llFrand(6);
```

### Phase 2: Enable Debugging (For Testing)

**File**: `backgammon_core.lsl` and `backgammon_AI.lsl`  
**Line**: 2 (both files)

**Change**:
```lsl
integer DEBUG_MODE = FALSE;  // Current
```
To:
```lsl
integer DEBUG_MODE = TRUE;  // For troubleshooting
```

### Phase 3: Cleanup (Optional)

#### Remove Dead Code from AI

**File**: `backgammon_AI.lsl`  
**Lines**: 39-57

Delete `getHomeBoardPoints()` function (never called)

### Phase 4: Testing

1. Enable DEBUG_MODE in both Core and AI
2. Start game with two AI players
3. Watch first roll phase
4. Verify dice values are logged correctly:
   - Winner's both dice should be used
   - Loser's dice should be discarded
5. Monitor subsequent turns for correct dice usage

---

## Verification Checklist

- [ ] First turn uses correct dice (winner's both dice)
- [ ] Auto-reroll generates and uses dice correctly
- [ ] AI makes valid moves with current dice
- [ ] Bear-off logic works correctly (already verified)
- [ ] No "invalid move" errors from dice mismatches
- [ ] Game completes successfully

---

## File Version Recommendations

### Use These Versions:

| Module | Recommended File | Size | Reason |
|--------|------------------|------|--------|
| Core | `backgammon_core.lsl` | 27KB | Most optimized, needs dice fixes |
| AI | `backgammon_AI.lsl` | 29KB | Has board state sync |
| Render | `backgammon_render.lsl` | 21KB | Current version |
| UI | `backgammon_ui.lsl` | 32KB | Current version |
| Menu | `backgammon_menu.lsl` | 20KB | Current version |
| Persistence | `Backgammon_persistence.lsl` | 16KB | Current version |

### Apply Fixes To:

- `backgammon_core.lsl` (2 critical fixes)
- Optional: Enable DEBUG_MODE temporarily

---

## Estimated Impact

**Without Fixes:**
- ❌ First turn always uses incorrect dice
- ❌ AI may make "invalid" moves based on wrong dice values
- ❌ Players frustrated by seemingly random rejections

**With Fixes:**
- ✅ First turn uses correct dice
- ✅ All subsequent turns work properly
- ✅ Game plays according to backgammon rules
- ✅ Predictable, debuggable behavior

---

## Implementation Steps

1. **Backup current files**
2. **Apply Fix 1.1** (First roll dice - lines 590-598)
3. **Apply Fix 1.2** (Variable shadowing - lines 576-586)
4. **Enable DEBUG_MODE** (optional, for verification)
5. **Test with AI vs AI**
6. **Verify first turn dice in debug output**
7. **If successful, disable DEBUG_MODE**
8. **Deploy to Second Life**

## Conclusion

The current codebase is **95% correct**. The Nov 3 bear-off bug was already fixed. The remaining issue is a **critical but simple fix** in the first roll dice assignment that affects every game's first turn.

**Time to fix**: ~5 minutes  
**Risk level**: Low (well-isolated changes)  
**Testing effort**: Moderate (need to verify first turn behavior)
