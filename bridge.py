#!/usr/bin/env python3
"""
mGBA Bridge Launcher for Claude Code
Sets up directories and launches mGBA with the Lua bridge script.
"""

import subprocess
import argparse
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="mGBA Bridge for Claude Code")
    parser.add_argument("rom", help="Path to ROM file (.gba, .gb, .gbc)")
    parser.add_argument("--speed", type=int, default=1, help="Emulation speed (1-10)")

    args = parser.parse_args()

    # Setup directories
    base_dir = Path(__file__).parent
    input_dir = base_dir / "input"
    output_dir = base_dir / "output"
    input_dir.mkdir(exist_ok=True)
    output_dir.mkdir(exist_ok=True)

    # Initialize command file
    command_file = input_dir / "command.txt"
    command_file.touch()

    # Initialize log
    log_file = output_dir / "log.txt"
    log_file.write_text("")

    # Find the Lua script
    lua_script = base_dir / "bridge.lua"
    if not lua_script.exists():
        print(f"Error: bridge.lua not found at {lua_script}")
        sys.exit(1)

    # Check ROM exists
    rom_path = Path(args.rom)
    if not rom_path.exists():
        print(f"Error: ROM not found at {rom_path}")
        sys.exit(1)

    # Build mGBA command
    # Try different possible binary names
    mgba_names = ["mGBA", "mgba-qt", "mgba"]
    mgba_bin = None

    for name in mgba_names:
        result = subprocess.run(["which", name], capture_output=True)
        if result.returncode == 0:
            mgba_bin = name
            break

    if not mgba_bin:
        print("Error: mGBA not found. Install with: brew install mgba")
        sys.exit(1)

    cmd = [
        mgba_bin,
        str(rom_path.absolute()),
        "-l", str(lua_script.absolute()),  # -l for script on mGBA
    ]

    print(f"Starting mGBA with bridge script...")
    print(f"ROM: {rom_path}")
    print(f"Script: {lua_script}")
    print(f"Commands: {command_file}")
    print(f"Screenshots: {output_dir / 'screenshot.png'}")
    print()
    print("The emulator window will open. The bridge is ready when you see")
    print("'Bridge initialized' in the mGBA scripting console.")
    print()

    try:
        subprocess.run(cmd)
    except KeyboardInterrupt:
        print("\nShutting down...")


if __name__ == "__main__":
    main()
