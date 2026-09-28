# Chromaton

A puzzle game about inventing machines out of **color logic**: 8 pigment colors, operations that mix/filter/invert/shift/route them, reusable inventions, and a loom that weaves the output into pixel-art tapestries. Early stage.

## Source of truth

- **[DESIGN.md](DESIGN.md)** holds every design decision and open question. Read it before proposing design or code changes.
- When a decision is made or changed in conversation, update DESIGN.md (and its ✅/🟡/❓ status markers) in the same session.

## Working with the user

- The user is the game designer. For design-level choices, discuss and recommend first; don't implement until they agree.
- Keep recommendations opinionated (pick one, explain why) rather than surveying every option.

## Hard rules

- **Bits are internal parlance only.** Colors are 3-bit ints (R, Y, B flags) and ops are bitwise in code, but player-facing text, UI and tutorials never mention bits, binary or bytes. The player thinks in paint.
- **The 8 signal colors are reserved.** Decorative art and UI must not use saturated signal hues; use neutrals on a light (paper/canvas) background.
- **Colorblind glyphs are always on** for signals, not an optional mode.
- **Touch-first UI:** no hover-only or right-click-only interactions.
- **Art style is Critter Workshop** (DESIGN.md §7.2): toy-like vector art drawn in code, components as wooden-vat critters, pixel art only for the woven tapestry. [mockups/style-studies.html](mockups/style-studies.html) is the visual reference for style, not layout (it flows downward; the game flows left to right, DESIGN.md §9.1).

## Commands

Godot 4.7.2 is installed via winget. `godot_console` may not be on PATH (winget can't create aliases without admin); the executables are in `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\`: `Godot_v4.7.2-stable_win64_console.exe` (tests, tools, screenshots) and `Godot_v4.7.2-stable_win64.exe` (play without a console window).

- Play: `godot --path .` (add `-- --unlock-all` to open every level, `-- --level=<id>` to jump into one).
- All tests: `godot_console --headless --path . --script res://tests/test_all.gd` (runs every `tests/test_*.gd` in its own process). One suite: `--script res://tests/test_sim.gd` (also `test_paint`, `test_levels`, `test_inventions`, `test_workbench`).
- Color-algebra checker (rewrites docs/algebra-report.md; rerun after changing pieces or recipes): `godot_console --headless --path . --script res://tools/algebra_check.gd`
- Level solver (rewrites docs/level-report.md; proves each level's three-star count; rerun after changing levels or pieces): `--script res://tools/level_solver.gd`
- Derive pattern cards from target pictures (rewrites the `cards` of levels with a `card_rule`): `--script res://tools/make_cards.gd`
- Compile check with line numbers (when Godot only says a dependency failed): `--script res://tools/check_scripts.gd`
- After adding fonts or other assets, import once: `godot_console --headless --path . --import`
- Self-check screenshots (windowed, not headless; saves a PNG and quits): `godot_console --path . -- --screenshot=<level_id>:<png path> [--ticks=N] [--phase=0.5] [--finish] [--wrong] [--empty]`. `<level_id>` can also be `levels` or `book`. Uses the reference solutions and a throwaway save.

## Layout

- `core/`: the simulation, pure GDScript with no scene nodes. `paint.gd` (the eight colors and operations), `pieces.gd` (the data-driven piece table), `machine.gd` (nodes and tubes as plain data), `simulator.gd` (one-drop-tube dataflow with chain reactions; an invention is one piece that looks its answer up), `level.gd` (level JSON), `invention.gd` (packaging and the every-paint check), `progress.gd` (save data in `user://chromaton_save.json`).
- `ui/`: everything on screen, built in code. `main.gd` (screens and command-line options), `workbench.gd` (the bench, gestures, run controls, loom), `draw_kit.gd` (Critter Workshop drawing), `palette.gd` (colors, fonts), `toy_button.gd`, `level_select.gd`, `pattern_book.gd`, `success_panel.gd`. `main.tscn` is the only scene.
- `levels/`: `index.json` (campaign order; a level's number is its place there) and one JSON per level, named by its stable id: target picture, pattern cards, pieces offered (the tray is exactly this list plus listed, owned inventions), star thresholds, reference solution. Format documented at the top of `core/level.gd`.
- `tests/`: headless test scripts (extend SceneTree, exit code 1 on failure).
- `tools/`: design tools, not shipped with the game.
- `docs/`: generated reports.
- `fonts/`: Fredoka and Nunito (SIL OFL, licenses alongside).
- `mockups/`: HTML mockups (the art-style reference; the game's layout supersedes theirs).

## Tech

- Godot 4, GDScript only, Compatibility renderer, no threads or plugins (web export needs it). A web export must include `levels/*.json` in its export filter (non-resource files).
- Simulation core as pure GDScript classes (no scene nodes), deterministic, unit-tested headless. Scripts load each other with `preload` constants, not `class_name`, so `--script` runs work without an editor import.
- UI built in code; one design canvas of 1280×800 scaled to the window.
- Dataflow with one-drop tubes (DESIGN.md §9): a piece fires when all its inputs hold a drop and each output is empty or is being emptied the same tick (chain reaction); every piece decides from the start-of-tick state.
- When changing levels, rerun `tools/make_cards.gd` (if cards derive from a rule) and `tools/level_solver.gd`, then the tests: every level's reference solution must solve it at exactly its three-star count.
