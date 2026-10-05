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

Run everything through `.\make <task>` (`make.cmd` → `tools/make.ps1`; works from PowerShell or cmd, no install, no script-policy change). It finds Godot by the `GODOT` environment variable, then `godot` on PATH, then the winget folder (`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\`; winget can't create the `godot` alias without admin). `.\make help` lists the tasks; `.\make godot` shows which Godot it uses. From Git Bash, call `./make.cmd <task>`.

- Play: `.\make play` (game args pass through), `.\make level <id>` to jump into one, `.\make unlock` to open every level.
- Tests: `.\make test` runs every `tests/test_*.gd` in its own process; `.\make test sim paint` runs only those suites (`sim`, `paint`, `levels`, `inventions`, `workbench`, `journal`). A suite also fails if it prints a GDScript error, and each runs with `--quit-after 2` so a runtime error can't hang it.
- Color-algebra checker (rewrites docs/algebra-report.md, the algebra notes: every piece's every-paint table and laws, kit completeness, recipe prices proven by search, future-work candidates; rerun after changing pieces or recipes; takes about a minute): `.\make algebra`. A piece added to `core/pieces.gd` needs a line in `PIECE_NOTES` in `tools/algebra_check.gd`, or the check fails.
- Drawing benchmark (headless, at a fixed 60 frames a second; per level, the time a frame spends drawing the bench while the reference machine runs at fast speed and while a piece is dragged from the tray, and what each layer costs; rerun after changing the workbench or draw_kit): `.\make bench`. The workbench draws in layers that redraw only when what they show changes (see the Drawing section of `ui/workbench.gd`): drawing everything every frame stuttered on the web.
- Journal words (rewrites `data/words.json` from the lexicon's gameplay terms: word, Gameplay text, the level whose solve unlocks it, the tab with its page; rerun after editing `docs/lexicon/`, the journal test fails if they drift apart): `.\make words`. A gameplay term's "Journal:" line must say "unlocks in <Level name>", so renaming a level means updating the lexicon too.
- Level solver (rewrites docs/level-report.md; proves each level's three-star count; rerun after changing levels or pieces): `.\make solve`
- Derive pattern cards from target pictures (rewrites the `cards` of levels with a `card_rule`, choosing the first row so cheap wrong machines fail within the 6 drops a card shows, or else in the first row; takes about half a minute): `.\make cards`
- Compile check with line numbers (when Godot only says a dependency failed): `.\make check`
- After adding fonts or other assets, import once: `.\make import`
- Web build for itch.io: `.\make export web` (the platform is an argument; web is the only one so far, and a bare `export` prints usage) writes `build/web/` and `build/chromaton-web.zip` (upload the zip; `build/` is git-ignored). `.\make serve [port]` plays `build/web/` at http://localhost:8060/ (a web build won't load from `file://`). Needs Godot's export templates once per machine: `.\make templates` (downloads about 1.3 GB, or pass a `.tpz`). The preset lives in `export_presets.cfg`: no threads, and it includes `levels/*.json` and `data/*.json` while leaving out `tests/`, `tools/`, `mockups/` and `docs/`.
- Release to itch.io: `.\make release itch [user/game:channel]` publishes from a committed tree only: it runs every test, exports the web build afresh and pushes `build/web/` with butler under a version made of the date and commit (`2026.10.04-127c7bd`). The store is an argument so other stores can join later. `.\make deploy [target]` pushes the existing `build/web/` as it is (its version marked `-dirty` if the tree has changes). The target comes from the argument or the `ITCH_TARGET` environment variable, never from the repo; the game is https://ibourlakos.itch.io/chromaton, channel `web`. butler is found by `BUTLER`, then PATH, then `%LOCALAPPDATA%\butler\butler.exe` (where it's unpacked); `.\make butler [args]` runs it, and `.\make butler login` (once, in a browser) is the designer's. Both publish, so don't run them unless the designer asks.
- Self-check screenshots (windowed, not headless; saves a PNG and quits): `.\make shot <level_id> <png path> [--ticks=N] [--phase=0.5] [--finish] [--wrong] [--empty] [--note]`. `<level_id>` can also be `levels`, `journal` (or `book`), `options` or `intro` (add `--stale` for its stale-save wording). The journal shows the first `--solved=N` levels woven by their reference machines (default 12; `--empty` for none), at `--tab=<paint|loom|pieces|inventions|cloths|scores|words>`, `--piece=<kind>`, `--word=<n>`, `--page=<chapter>`. On a level, `--peek[=<kind>]` opens the journal over the bench and `--finish --news` goes past the success panel to "New in your journal". `--note` shows the level's note (title, goal, hint) up; `--grid` turns the bench grid on; `--paints` puts the paint card up; `--fan` fans out the pot slot's pots (chapter 2 on); `--touch` draws as a phone build would (no key labels, no keys in Options). Uses the reference solutions and a throwaway save.

## Layout

- `core/`: the simulation, pure GDScript with no scene nodes. `paint.gd` (the eight colors and operations), `pieces.gd` (the data-driven piece table), `machine.gd` (nodes and tubes as plain data), `simulator.gd` (one-drop-tube dataflow with chain reactions; an invention is one piece that looks its answer up), `level.gd` (level JSON), `invention.gd` (packaging and the every-paint check), `progress.gd` (save data in `user://chromaton_save.json`, including what the player's machines have shown each piece doing), `words.gd` (the journal's Words, read from `data/words.json`).
- `ui/`: everything on screen, built in code. `main.gd` (screens and command-line options), `workbench.gd` (the bench, gestures, run controls, loom), `draw_kit.gd` (Critter Workshop drawing), `palette.gd` (colors, fonts), `toy_button.gd`, `level_select.gd`, `journal.gd` (the journal: tabs Paint, Loom, Pieces, Inventions, Cloths, Scores, Words; opened from the level select or by peek over the bench), `journal_news.gd` ("New in your journal" after a solve), `success_panel.gd`, `level_note.gd` (the title, goal and hint that pop up as a level opens), `paint_card.gd` (the eight paints as a mixing triangle, behind the workbench's Paints button), `options.gd` (key settings), `keys.gd` (key bindings, settings file and key caps). `main.tscn` is the only scene.
- `levels/`: `index.json` (campaign order; a level's number is its place there) and one JSON per level, named by its stable id: name, goal and optional hint, target picture, pattern cards, pieces offered (the tray shows this list open, earlier levels' pieces locked, then listed, owned inventions), star thresholds, reference solution. Format documented at the top of `core/level.gd`. `level-text.md` holds every level's decided text for the new campaign (titles, goals, hints, guided steps, and the text outside the level files) until the rebuild writes it into the JSON; not exported (the export ships only `levels/*.json`).
- `data/`: `words.json`, generated by `.\make words`; shipped (the export includes `data/*.json`), unlike `docs/`.
- `tests/`: headless test scripts (extend SceneTree, exit code 1 on failure).
- `tools/`: design tools, not shipped with the game, and `make.ps1` (the tasks behind `make.cmd`). `lexicon.gd` reads the lexicon for `make_words.gd` and the journal test.
- `docs/`: generated reports, and `docs/lexicon/`, the game's vocabulary, hand-written: `lexicon.md` is the index (and its conventions); one file per term (`paint.md`, `critter.md`, ...) holds the term's details. Add a term there when one is named or settled; a term tagged gameplay also needs `.\make words`.
- `fonts/`: Fredoka and Nunito (SIL OFL, licenses alongside).
- `mockups/`: HTML mockups (the art-style reference; the game's layout supersedes theirs).

## Tech

- Godot 4, GDScript only, Compatibility renderer, no threads or plugins (web export needs it). A web export must include `levels/*.json` and `data/*.json` in its export filter (non-resource files).
- Simulation core as pure GDScript classes (no scene nodes), deterministic, unit-tested headless. Scripts load each other with `preload` constants, not `class_name`, so `--script` runs work without an editor import.
- UI built in code; one design canvas of 1280×800 scaled to the window.
- Dataflow with one-drop tubes (DESIGN.md §9): a piece fires when all its inputs hold a drop and each output is empty or is being emptied the same tick (chain reaction); every piece decides from the start-of-tick state.
- When changing levels, rerun `.\make cards` (if cards derive from a rule) and `.\make solve`, then `.\make test`: every level's reference solution must solve it at exactly its three-star count.
