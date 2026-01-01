# AI Plays Pokemon

An AI-controlled Pokemon emulator that lets Claude Code (or other AI assistants) play Pokemon games autonomously through file-based communication with the mGBA emulator.

## How It Works

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Claude Code   │     │   File System    │     │      mGBA       │
│                 │     │                  │     │                 │
│  Reads screen   │◄────│  screenshot.png  │◄────│  Lua bridge     │
│  Decides action │     │  game_state.json │     │  captures game  │
│  Writes command │────►│  command.txt     │────►│  executes input │
└─────────────────┘     └──────────────────┘     └─────────────────┘
        │                                                 │
        └─────────────── Loop every ~0.5 sec ─────────────┘
```

The system uses a simple file-based IPC (Inter-Process Communication):
1. A Lua script runs inside mGBA, capturing screenshots and reading commands
2. Claude Code views the screenshot, analyzes game state, and writes commands
3. The bridge executes commands and updates the screenshot
4. Repeat until the game is complete

## Supported Games

| Platform | Games |
|----------|-------|
| Game Boy | Red, Blue, Yellow |
| Game Boy Color | Gold, Silver, Crystal |
| Game Boy Advance | Ruby, Sapphire, **Emerald**, FireRed, LeafGreen |

## Requirements

- [mGBA](https://mgba.io/) emulator with Lua scripting support
- Python 3.6+
- [Claude Code](https://claude.ai/claude-code) CLI (or any AI that can read/write files)
- A legally obtained Pokemon ROM file

## Installation

### 1. Install mGBA

```bash
# macOS
brew install mgba

# Ubuntu/Debian
sudo apt install mgba-qt

# Windows
# Download from https://mgba.io/downloads.html
```

### 2. Clone the repository

```bash
git clone git@github.com:jofftiquez/pokemon-ai-player.git
cd pokemon-ai-player
```

### 3. Add your ROM

Place your legally obtained Pokemon ROM in the project directory (e.g., `pokemon_emerald.gba`).

## Usage

### Start the bridge

```bash
python3 bridge.py pokemon_emerald.gba
```

This launches mGBA with the Lua bridge script loaded.

### Load the script manually (if not auto-loaded)

In mGBA: **Tools > Scripting** > Click **Load** > Select `bridge.lua`

### Run Claude Code with the prompt

```bash
claude --prompt Prompt.md
```

Claude Code will start playing automatically - viewing screenshots, making decisions, and sending commands in a continuous loop.

## Commands Reference

| Command | Description |
|---------|-------------|
| `a`, `b`, `start`, `select` | Press button |
| `up`, `down`, `left`, `right` | D-pad navigation |
| `l`, `r` | Shoulder buttons (GBA only) |
| `wait N` | Wait N frames (60 = 1 second) |
| `hold BUTTON N` | Hold button for N frames |
| `mash A N` | Press A repeatedly N times |
| `screenshot` | Force immediate screenshot |
| `save_state N` | Save to slot N (1-9) |
| `load_state N` | Load from slot N (1-9) |

### Example Commands

```bash
# Move up three times then press A
echo "up up up a" > input/command.txt

# Wait half a second then mash through dialogue
echo -e "wait 30\nmash a 10" > input/command.txt

# Save state before a tough battle
echo "save_state 1" > input/command.txt
```

## Project Structure

```
ai-plays-pokemon/
├── bridge.py           # Python launcher script
├── bridge.lua          # mGBA Lua bridge (runs inside emulator)
├── Prompt.md           # System prompt for Claude Code
├── README.md
├── input/
│   └── command.txt     # AI writes commands here (auto-cleared)
└── output/
    ├── screenshot.png  # Current game screen (updates every 0.5s)
    ├── game_state.json # Frame counter and timestamp
    └── log.txt         # Bridge event log
```

## How the AI Plays

The included `Prompt.md` instructs the AI to:
- Continuously play without waiting for user input
- Navigate the world, catch Pokemon, battle trainers
- Use type advantages and heal before gym battles
- Use web search when stuck on puzzles
- Save state before risky encounters
- Keep playing until becoming Champion

## Tips

- **Save states are your friend** - Use them before legendary encounters or tough battles
- **Check the log** - `output/log.txt` shows what commands were processed
- **Start fresh or continue** - Works with new games or existing save files
- **Watch the gameplay** - The mGBA window shows exactly what the AI sees

## Troubleshooting

### Bridge not loading?
Open mGBA's scripting console (**Tools > Scripting**) to see error messages.

### Commands not executing?
Check that `input/command.txt` is being cleared after you write to it. If not, the Lua script may not be running.

### Screenshot not updating?
Verify `output/screenshot.png` has a recent timestamp. The bridge saves a new screenshot every 0.5 seconds.

## License

MIT License - See [LICENSE](LICENSE) for details.

## Disclaimer

This project is for educational and entertainment purposes. You must provide your own legally obtained ROM files. Pokemon is a trademark of Nintendo/Game Freak/The Pokemon Company.

## Acknowledgments

- [mGBA](https://mgba.io/) - Excellent GBA emulator with Lua scripting
- [Claude Code](https://claude.ai/claude-code) - AI assistant that can actually play games
