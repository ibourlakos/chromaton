# Testing Chromaton

Chromaton is a puzzle game about building paint machines: paint flows left to right through critter pieces that mix, filter, invert and shift colors, and a loom weaves what comes out into a picture. It's early, so rough edges are expected, and that's what we want to hear about.

## Linux

This project targets **Godot 4.7** (GDScript, Compatibility renderer). It has
been checked with Godot **4.7.2** on Linux x86_64. Use a standard Godot build;
the .NET build is not needed.

From this project folder:

```sh
./make play
```

The prepared portable engine lives in `.linux-tools/godot/`. Nothing is
installed system-wide. The launcher keeps saves, settings, caches, temporary
files and graphics caches inside this project. Game saves are in
`.linux-user/data/godot/app_userdata/Chromaton/chromaton_save.json`.
The portable editor keeps its own data beside the engine in `editor_data/`.
Tests, headless smoke checks and screenshots use `.linux-user/test-data/`
instead, so test completions do not change your playing progress.

| Command | What it does |
|---|---|
| `./make play` | Start the game |
| `./make unlock` | Start with every level open |
| `./make level wash_out` | Open one level directly |
| `./make editor` | Open this project in the portable editor |
| `./make godot` | Show the engine path and exact version |
| `./make import` | Rebuild imported assets |
| `./make check` | Compile every script |
| `./make test` | Run all five test suites |
| `./make smoke` | Run a short headless startup check |
| `./make export-pack` | Build `builds/linux/Chromaton.pck` |
| `./make export` | Build a native Linux executable and its PCK |
| `./make play-export` | Start the native exported build |

The launcher uses OpenGL ES with software rendering by default because the
available Linux graphics driver failed to create the initial OpenGL context.
This works for this 2D game and changes only the launched process. To try your
GPU instead, run `CHROMATON_SOFTWARE_RENDERING=0 ./make play`.

For screenshots, choose a destination inside the project, for example:

```sh
./make shot wash_out .linux-user/screenshots/wash_out.png --finish
```

On a fresh copy without `.linux-tools/`, download the standard Linux x86_64
Godot 4.7.x archive from [Godot's official downloads](https://godotengine.org/download/linux/),
extract its executable into `.linux-tools/godot/`, make it executable, and
create an empty `_sc_` file beside it to keep editor data local. The launcher
also accepts `GODOT=/absolute/path/to/godot` or a `godot4`/`godot` executable
on PATH. An external editor already configured in self-contained mode uses
its own `editor_data/`; use the supplied portable engine for project-only
editor writes.

The Linux export preset explicitly includes `levels/*.json` and the font
licenses. Native exports need matching Godot export templates. The prepared
copy stores only the Linux x86_64 templates under
`.linux-tools/godot/editor_data/export_templates/4.7.2.stable/`, inside this
project. Keep `Chromaton.pck` beside `Chromaton.x86_64` when sharing a build.
Run `./make play-export` here to keep its save data local too; launching the
executable directly uses Godot's standard Linux user data directory.

The portable engine, local user data, imports, screenshots, and builds are
ignored by Git. Windows testing instructions follow below.

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

## Windows commands

| Command | What it does |
|---|---|
| `.\make play` | Start the game |
| `.\make unlock` | Start with every level open |
| `.\make level <id>` | Jump straight into one level. The id is the file name in `levels/` without `.json`, e.g. `.\make level wash_out` |
| `git pull` | Get the latest version (do this before each session) |
| `.\make godot` | Show which Godot the game found, if it won't start |

## How to play

- **Place a piece:** drag it from the tray onto the bench.
- **Move a piece:** drag it. Drag it back onto the tray to remove it.
- **Lay a tube:** drag from a piece's output to another piece's input (or the other way).
- **Re-route a tube:** drag its end off the input. To delete one, tap it, then its delete button.
- **Run controls (top bar):** Undo, Reset, Step back, Step, Run/Pause, and three speeds.

Each level shows the picture to weave and the paint you start with. Fewer pieces earn more stars.

## Starting over

Your progress is saved in `%APPDATA%\Godot\app_userdata\Chromaton\chromaton_save.json`. Delete that file to start from level one.

## Reporting

Open an issue on GitHub: https://github.com/ibourlakos/chromaton/issues

Helpful things to include:

- The level (its name on screen is fine).
- What you tried, what you expected, and what happened.
- A screenshot (Win + Shift + S, then paste into the issue).

Not just bugs: tell us where you got stuck, what was confusing, what felt too easy or too hard, and which levels you enjoyed.
