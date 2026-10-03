# Testing Chromaton

Chromaton is a puzzle game about building paint machines: paint flows left to right through critter pieces that mix, filter, invert and shift colors, and a loom weaves what comes out into a picture. It's early, so rough edges are expected, and that's what we want to hear about.

## Setup (Windows, once)

1. Install Godot 4 and Git, if you don't have them:
   ```
   winget install GodotEngine.GodotEngine
   winget install Git.Git
   ```
2. Get the game:
   ```
   git clone https://github.com/ibourlakos/chromaton.git
   cd chromaton
   ```
3. Play:
   ```
   .\make play
   ```

Run the commands from PowerShell or Command Prompt inside the `chromaton` folder. From Git Bash, write `./make.cmd play` instead.

## Commands

| Command | What it does |
|---|---|
| `.\make play` | Start the game |
| `.\make unlock` | Start with every level open |
| `.\make level <id>` | Jump straight into one level. The id is the file name in `levels/` without `.json`, e.g. `.\make level wash_out` |
| `git pull` | Get the latest version (do this before each session) |
| `.\make godot` | Show which Godot the game found, if it won't start |
| `.\make export web` | Build the browser version into `build/web` (needs `.\make templates` once, a 1.3 GB download); `.\make serve` then plays it at http://localhost:8060/ |

## How to play

- **Place a piece:** drag it from the tray onto the bench.
- **Move a piece:** drag it. Drag it back onto the tray to remove it.
- **Lay a tube:** drag from a piece's output to another piece's input (or the other way).
- **Re-route a tube:** drag its end off the input. To delete one, tap it, then its delete button.
- **Run controls (top bar):** Undo, Reset, Step back, Step, Run/Pause, and three speeds.

Each level shows the picture to weave and the paint you start with. Fewer pieces earn more stars.

## Starting over

Your progress is saved in `%APPDATA%\Godot\app_userdata\Chromaton\chromaton_save.json`. Delete that file to start from level one.

An update can change levels so that an old save no longer fits. The game then says so when it starts and lets you start fresh or keep what still fits; the old file is kept beside it as `chromaton_save.json.bak` either way.

## Reporting

Open an issue on GitHub: https://github.com/ibourlakos/chromaton/issues

Helpful things to include:

- The level (its name on screen is fine).
- What you tried, what you expected, and what happened.
- A screenshot (Win + Shift + S, then paste into the issue).

Not just bugs: tell us where you got stuck, what was confusing, what felt too easy or too hard, and which levels you enjoyed.
