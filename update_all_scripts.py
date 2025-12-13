#!/usr/bin/env python3
"""
Add logging system to all remaining LSL scripts.
This script adds the logging level constants, notecard reading, and replaces DEBUG_MODE.
"""

import re

# Template for logging constants and notecard reading
LOGGING_HEADER = """// Logging Configuration
integer LOG_LEVEL = 3;  // Default: INFO (0=OFF, 1=ERROR, 2=WARN, 3=INFO, 4=DEBUG, 5=VERBOSE)
integer LOG_OFF = 0;
integer LOG_ERROR = 1;
integer LOG_WARN = 2;
integer LOG_INFO = 3;
integer LOG_DEBUG = 4;
integer LOG_VERBOSE = 5;

// Notecard reading state
string CONFIG_NOTECARD = "debug_config";
key gConfigQueryId = NULL_KEY;
integer gConfigLine = 0;
integer gConfigReading = FALSE;
"""

def get_read_config_function(script_name):
    """Generate readDebugConfig function for a specific script."""
    return f"""
// ===== CONFIGURATION READING =====
readDebugConfig() {{
    if (llGetInventoryType(CONFIG_NOTECARD) != INVENTORY_NOTECARD) {{
        LOG_LEVEL = LOG_INFO; // Default to INFO if no config
        if (LOG_LEVEL >= LOG_INFO) {{
            llOwnerSay("[{script_name}] No debug_config notecard found - using default LOG_LEVEL=3 (INFO)");
        }}
        return;
    }}
    
    gConfigReading = TRUE;
    gConfigLine = 0;
    gConfigQueryId = llGetNotecardLine(CONFIG_NOTECARD, gConfigLine);
}}
"""

def get_dataserver_event(script_name):
    """Generate dataserver event handler for a specific script."""
    return f"""
    dataserver(key query_id, string data) {{
        if (query_id == gConfigQueryId) {{
            if (data != EOF) {{
                // Parse configuration line
                string line = llStringTrim(data, STRING_TRIM);
                
                // Skip empty lines and comments
                if (line != "" && llGetSubString(line, 0, 0) != "#") {{
                    // Parse KEY=VALUE format
                    integer eqPos = llSubStringIndex(line, "=");
                    if (eqPos != -1) {{
                        string key = llStringTrim(llGetSubString(line, 0, eqPos - 1), STRING_TRIM);
                        string value = llStringTrim(llGetSubString(line, eqPos + 1, -1), STRING_TRIM);
                        
                        // Check if this is our script's config or global
                        if (key == "{script_name}") {{
                            LOG_LEVEL = (integer)value;
                            if (LOG_LEVEL >= LOG_INFO) {{
                                llOwnerSay("[{script_name}] Loaded LOG_LEVEL=" + value + " from notecard");
                            }}
                        }} else if (key == "GLOBAL") {{
                            // Only use GLOBAL if we haven't found a script-specific setting yet
                            LOG_LEVEL = (integer)value;
                        }}
                    }}
                }}
                
                // Request next line
                gConfigLine++;
                gConfigQueryId = llGetNotecardLine(CONFIG_NOTECARD, gConfigLine);
            }} else {{
                // Finished reading notecard
                gConfigReading = FALSE;
                if (LOG_LEVEL >= LOG_INFO) {{
                    llOwnerSay("[{script_name}] Configuration loaded. Final LOG_LEVEL=" + (string)LOG_LEVEL);
                }}
            }}
        }}
    }}
"""

def update_script(filepath, script_name):
    """Update a single LSL script with logging system."""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Step 1: Replace DEBUG_MODE declaration with logging constants
    content = re.sub(
        r'integer DEBUG_MODE = (TRUE|FALSE);.*?\n',
        LOGGING_HEADER + '\n',
        content,
        flags=re.DOTALL
    )
    
    # Handle DEBUG_MODE_VERBOSE if it exists (for render script)
    content = re.sub(
        r'integer DEBUG_MODE_VERBOSE = (TRUE|FALSE);.*?\n',
        '',
        content
    )
    
    # Step 2: Replace all if (DEBUG_MODE) with if (LOG_LEVEL >= LOG_DEBUG)
    content = re.sub(r'if \(DEBUG_MODE\)', r'if (LOG_LEVEL >= LOG_DEBUG)', content)
    
    # Step 3: Replace DEBUG_MODE_VERBOSE with LOG_VERBOSE
    content = re.sub(r'if \(DEBUG_MODE_VERBOSE\)', r'if (LOG_LEVEL >= LOG_VERBOSE)', content)
    
    # Step 4: Add readDebugConfig before default state
    if 'readDebugConfig()' not in content:
        config_func = get_read_config_function(script_name)
        content = re.sub(
            r'(default \{)',
            config_func + r'\n\1',
            content
        )
    
    # Step 5: Add readDebugConfig() call to state_entry if not present
    if 'readDebugConfig();' not in content:
        content = re.sub(
            r'(state_entry\(\) \{)',
            r'\1\n        readDebugConfig(); // Load logging configuration',
            content
        )
    
    # Step 6: Add dataserver event before closing brace of default state
    if 'dataserver(key query_id' not in content:
        dataserver = get_dataserver_event(script_name)
        # Find the last closing brace (end of default state)
        content = re.sub(
            r'(\n\}\s*)$',
            dataserver + r'\1',
            content
        )
    
    # Write back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Updated {filepath} with {script_name} logging system")

# Update all remaining scripts
scripts = [
    ('backgammon_ui.lsl', 'UI'),
    ('backgammon_render.lsl', 'RENDER'),
    ('backgammon_AI.lsl', 'AI'),
    ('backgammon_menu.lsl', 'MENU'),
    ('Backgammon_persistence.lsl', 'PERSISTENCE')
]

for filepath, script_name in scripts:
    try:
        update_script(filepath, script_name)
    except Exception as e:
        print(f"Error updating {filepath}: {e}")
