# Log Analysis Tools

## analyze_log.py

**Purpose:** Tracks piece movements through a game log to detect logical errors like pieces teleporting or invalid game-over states.

**Usage:**
```bash
python .agent/tools/analyze_log.py <log_file>
```

**Example:**
```bash
python .agent/tools/analyze_log.py log4.txt
```

**What it does:**
- Tracks all 15 white and 15 black pieces through the game
- Detects when pieces move from wrong positions (ghosting/teleporting)
- Validates game-over conditions (winner must have all pieces borne off)
- Outputs detailed analysis to `analysis_results.txt`

**When to use:**
- After AI vs AI test runs
- When investigating "ghosting" bugs (pieces disappearing/reappearing)
- When validating game-over logic
- When tracking down piece position inconsistencies

---

## verify_moves_v2.py

**Purpose:** Validates that combined moves (using 2 dice) have valid intermediate positions.

**Usage:**
```bash
python verify_moves_v2.py
```
(Hardcoded to analyze `log4.txt`)

**What it does:**
- Finds all combined moves (moves_used=2)
- Checks if intermediate position was blocked
- Outputs report to `verification_report.txt`

**When to use:**
- When investigating invalid jump/combined move bugs
- After AI changes that affect move generation
