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
- **Art style is Critter Workshop** (DESIGN.md §7.2): toy-like vector art drawn in code, components as wooden-vat critters, pixel art only for the woven tapestry. [mockups/style-studies.html](mockups/style-studies.html) is the visual reference.

## Commands

Godot 4.7.2 is installed via winget. `godot_console` may not be on PATH (winget can't create aliases without admin); the executable is `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.2-stable_win64_console.exe`.

- Unit tests: `godot_console --headless --path . --script res://tests/test_paint.gd`
- Color-algebra checker (rewrites docs/algebra-report.md; rerun after changing pieces or recipes): `godot_console --headless --path . --script res://tools/algebra_check.gd`

## Layout

- `core/paint.gd`: the eight colors and the basic operations (pure, no scene nodes).
- `tests/`: headless test scripts (extend SceneTree, exit code 1 on failure).
- `tools/`: design tools, not shipped with the game.
- `docs/`: generated reports.
- `mockups/`: HTML mockups (the art-style reference).

## Tech (planned)

- Godot 4, GDScript only (web export needs it).
- Simulation core as pure GDScript classes (no scene nodes), deterministic, unit-tested headless.
- UI built mostly in code.
- Discrete tick simulation; every component takes 1 tick.
