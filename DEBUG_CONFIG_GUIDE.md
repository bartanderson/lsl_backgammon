# Backgammon Debug Configuration Guide

## Overview

The Backgammon game now supports configurable logging levels that allow you to control how much debug information is displayed. This is useful for:
- **Normal gameplay**: Reduce clutter by showing only important messages
- **Troubleshooting**: Enable detailed logging to diagnose issues
- **Customer support**: Easily generate detailed logs when reporting bugs

## How to Configure Logging

### Step 1: Create the Configuration Notecard

1. In Second Life, right-click the Backgammon game object
2. Select "Edit" from the menu
3. Go to the "Content" tab
4. Click "New Script" dropdown and select "New Note"
5. Name the notecard exactly: `debug_config`
6. Double-click the notecard to edit it

### Step 2: Set Logging Levels

Add configuration lines to the notecard using this format:

```
# Backgammon Debug Configuration
GLOBAL=3

# Per-script overrides (optional)
#CORE=4
#UI=3
#RENDER=2
#MENU=1
#AI=4
#AI_BRAIN=4
#PERSISTENCE=2
```

### Logging Levels

| Level | Name | Description |
|-------|------|-------------|
| 0 | OFF | No logging output |
| 1 | ERROR | Only critical errors |
| 2 | WARN | Warnings and errors |
| 3 | INFO | General information (default) |
| 4 | DEBUG | Detailed debugging information |
| 5 | VERBOSE | Very detailed trace information |

### Step 3: Reset the Scripts

After editing the notecard:
1. Save the notecard
2. Right-click the Backgammon object
3. Select "Edit" → "Content" tab
4. Click "Reset Scripts" button

The new logging configuration will be loaded automatically.

## Configuration Examples

### Example 1: Clean Gameplay (Minimal Logging)

```
GLOBAL=1
```

This shows only critical errors. Perfect for normal gameplay without clutter.

### Example 2: Troubleshooting AI Issues

```
GLOBAL=2
AI=5
AI_BRAIN=5
```

This shows warnings globally, but enables very detailed logging for AI components.

### Example 3: Full Debug Mode

```
GLOBAL=5
```

This enables maximum logging for all components. Use this when reporting bugs.

### Example 4: Selective Debugging

```
GLOBAL=3
CORE=4
UI=2
RENDER=1
```

- Core game logic: DEBUG level
- UI: WARN level (less verbose)
- Rendering: ERROR only (minimal)
- Everything else: INFO level (default)

## Script Names

When configuring per-script logging, use these exact names:

- `CORE` - Core game logic (moves, rules, validation)
- `UI` - User interface (touch handling, piece selection)
- `RENDER` - Visual rendering (piece positioning, dice)
- `MENU` - Menu system
- `AI` - AI player controller
- `AI_BRAIN` - AI decision-making logic
- `PERSISTENCE` - Game save/load functionality

## Tips

- **Start with GLOBAL**: Set a baseline level for all scripts
- **Override selectively**: Only specify individual scripts when you need different levels
- **Use comments**: Lines starting with `#` are ignored
- **Case sensitive**: Script names must be UPPERCASE (CORE, not core)
- **No spaces**: Format must be `SCRIPT=LEVEL` (no spaces around `=`)

## Troubleshooting

**Q: My configuration isn't working**
- Check the notecard name is exactly `debug_config` (lowercase, no spaces)
- Verify you reset the scripts after saving the notecard
- Check for typos in script names (must be UPPERCASE)

**Q: I'm still seeing too many messages**
- Lower the GLOBAL level (try 2 or 1)
- Check if specific scripts are overridden to higher levels

**Q: I'm not seeing any debug messages**
- Increase the GLOBAL level (try 4 or 5)
- Make sure the notecard exists and is named correctly
- Verify scripts were reset after creating/editing the notecard

## Support

If you encounter issues that you can't resolve:

1. Set logging to maximum: `GLOBAL=5`
2. Reset scripts
3. Reproduce the issue
4. Copy the chat log
5. Contact support with the log and description of the problem

The detailed logs will help diagnose the issue much faster!
