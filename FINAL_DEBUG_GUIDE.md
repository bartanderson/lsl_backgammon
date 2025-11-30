# Final Debug Setup Guide

## Files Ready for Testing

### Core Files (DEBUG_MODE = TRUE)
1. ✅ `backgammon_core.lsl` - DEBUG enabled
2. ✅ `backgammon_AI.lsl` - DEBUG enabled  

### Control Files (DEBUG_MODE = FALSE for production)
3. ✅ ` backgammon_menu.lsl` - Improved reset system, DEBUG off for clean output

## Production Reset System - IMPLEMENTED

The Menu module now handles reset with automated timing:

**User Experience:**
1. User clicks "Reset" button in menu
2. Menu orchestrates entire reset automatically
3. Single confirmation message when complete
4. No technical spam

**What Happens Behind the Scenes:**
```
1. Menu resets control flags (AI settings, pause, etc.)
2. Broadcasts new state to all modules
3. Waits 0.5s for state propagation
4. Sends RESET_GAME to all modules
5. Waits 2.5s for modules to reinitialize (state_entry completion)
6. Sends INIT_COMPLETE signal  
7. User sees: "Game reset complete"
```

**Benefits:**
- No manual timing needed
- Works reliably every time
- Handles Render module (if in child prim)
- Clean user experience

## Testing Protocol

### For Development (Finding Bugs):
1. Copy `backgammon_core.lsl` and `backgammon_AI.lsl` to SL
2. Copy `backgammon_menu.lsl` if you want improved reset
3. **Reset all scripts** (Edit → Reset Scripts in Contents)
4. Wait 3 seconds for initialization
5. Use Menu → "Reset" button
6. Set to "Both AI" mode
7. Start game and observe debug output

### For Production (End Users):
- Set `DEBUG_MODE = FALSE` in Core and AI
- Users just click "Reset" button - everything automatic
- Clean chat, no technical spam

## Debug Output Expectations

**With DEBUG_MODE = TRUE:**

**From AI module:**
- Dice values received via TRIGGER_AI_TURN
- Board state received
- Move generation decisions
- Validation checks
- "DEBUG AI:" prefix on all messages

**From Core module:**
- ⚠️ NONE - Core has no debug output even with DEBUG_MODE=TRUE
- Core was stripped of debug logging in Nov 10 refactoring

**Implication:**
- We can see AI decisions but not Core's dice management
- Enough to identify if AI is making bad moves
- May need to add Core debug later if needed

## What To Look For

### Normal Behavior:
- AI receives dice via TRIGGER_AI_TURN
- AI generates valid move
- Move executes
- AI receives new TRIGGER with updated dice
- Repeat 0-4 times per turn

### Bug Indicators:
- AI uses wrong dice values
- AI generates invalid moves repeatedly
- Dice not clearing between moves
- Turn never ends / infinite loop
- AI makes moves when dice = 0

## Quick Debugging Tips

**If game seems stuck:**
- Check if DEBUG shows AI receiving TRIGGER_AI_TURN
- Check dice values in TRIGGER message
- Look for AI_NO_MOVES being sent

**If invalid moves:**
- Note which point→point movement
- Note which die value used
- Check if piece actually exists at from_point

**If dice issues:**
- Track dice values across multiple TRIGGERs
- Should decrease as moves complete
- Should reset to new roll at turn change

## Copy to SL Checklist

✅ Required for debug session:
- [ ] `backgammon_core.lsl` (DEBUG_MODE = TRUE)
- [ ] `backgammon_AI.lsl` (DEBUG_MODE = TRUE)

✅ Optional improvements:
- [ ] `backgammon_menu.lsl` (better reset, DEBUG_MODE = FALSE)

✅ Testing steps:
- [ ] Reset all scripts in root object
- [ ] Wait 3 seconds
- [ ] Use menu reset button
- [ ] Set Both AI mode
- [ ] Observe AI vs AI game
- [ ] Share debug output

Ready to test!
