# Chromaton — Design Document

> Working title (Steam name conflict check pending).
> This file is the **single source of truth** for the design. Ideas explored elsewhere (claude.ai Project, chats) come back here.

**Status legend:** ✅ Decided · 🟡 Proposed / leaning · ❓ Open

---

## 1. Vision

A puzzle game about **inventing machines out of color logic**. Where computers build registers and adders out of binary logic gates, Chromaton players build ever-bigger contraptions out of **color operations** that mix, filter, invert, and route paint.

- ✅ **Looks like a children's game, reveals its depth on its own.** North star: *Bloons TD 6*: friendly surface, hard-core depth underneath. Also: *Human Resource Machine* (cute look, real programming depth).
- ✅ **Invent first, then optimize.** Solving a level earns the invention for your toolkit; optimizing it earns stars and leaderboard standing.
- ✅ Shareable with friends early; Steam as a later goal.

Genre neighbours: Zachtronics (SpaceChem, TIS-100, Shenzhen I/O, Opus Magnum), Turing Complete, NandGame, Human Resource Machine. **Watch out for:** *shapez / shapez 2*, a cute factory game that also mixes colors (additive RGB). Chromaton's difference: **logic and invention**, not logistics.

---

## 2. The color algebra

### 2.1 Values ✅

Exactly **8 colors**. A color is *the set of primaries present* in it. Mixing ignores quantity (red + yellow + yellow = orange).

| Primaries present | Color | Complement |
|---|---|---|
| none | **White** (no paint, the empty canvas) | Black |
| R | **Red** | Green |
| Y | **Yellow** | Purple |
| B | **Blue** | Orange |
| R+Y | **Orange** | Blue |
| Y+B | **Green** | Red |
| R+B | **Purple** | Yellow |
| R+Y+B | **Black** (all paint) | White |

Pigment rules (subtractive), **not** light rules: all colors make black, white is nothing.

✅ **Internal representation:** a color is a 3-bit integer (R, Y, B flags, 0–7), and every operation is a bitwise op. **Bits, bytes and "binary" are internal parlance only and never appear in player-facing text, UI or tutorials.** The player thinks in paint.

### 2.2 How big the function space is (for reference)

All functions from *n* colors to 1 color: **8^(8^n)**.

| Arity | Count |
|---|---|
| 1 → 1 | 8^8 ≈ 16.7 million (of which 8! = 40,320 are permutations) |
| 2 → 1 | 8^64 ≈ 6 × 10^57 |
| 3 → 1 | 8^512 ≈ 10^462 |
| n → m | 8^(m · 8^n) |

- **Multi-output components** (n → m) are just *m* functions sharing inputs (e.g. Prism = three 1→1 functions side by side).
- **Stateful components** (cells, buffers, counters) are *not* functions: their output depends on history. They are small machines.

Enumerating everything is impossible, so the design job is: **a small primitive set that can build everything + a curated catalog of named inventions.**

### 2.3 Families of operations 🟡

| Family | Idea | Examples |
|---|---|---|
| **Paint-like** (each primary handled on its own) | 2^(2^n) per arity: 4 unary, 16 binary, 256 ternary | Mix (union), Filter (intersection), Contrast (in exactly one), Bleach (A minus B), Invert; **Consensus** (primaries present in ≥ 2 of 3 inputs) |
| **Hue-like** (moving primaries around) | The 12 "even-handed" symmetries: identity, Shift, Reverse-shift, 3 Swaps, and each of those followed by Invert | Shift: R→Y→B→R, so Orange→Green→Purple |
| **Counting / comparing** (information crosses between primaries) | | "how many primaries?", "is A darker than B?", "equal?" |
| **Routing** (the most naturally ternary family) | A control primary (R/Y/B) chooses one of three paths | 3-way switch (1 in, 3 out), 3-way selector (3 in, 1 out) |
| **Stateful** | Machines, not functions | Cell (holds a color), Buffer (queue), Counter |

🟡 Candidates for every family (questions, counting, wheel, paint-like, choosing, several outputs), each verified on every paint and priced in the game's kit, plus what memory, branching, register-like cards and multi-output inventions would change in the rules: [report §7](docs/algebra-report.md#7-future-work). Not decided.

Nice facts to exploit in puzzles:
- Invert matches art-class **complementary colors** (red↔green, blue↔orange, yellow↔purple).
- *"Given two different primaries, output the third"* = `Invert(Mix(a, b))`, the SET card-game rule, discovered through paint.

### 2.4 Completeness ✅ (verified)

Verified by `tools/algebra_check.gd`; full results in [docs/algebra-report.md](docs/algebra-report.md). These three build **every** machine of any number of inputs:
1. **NOR**: `Invert(Mix(a, b))`
2. **Shift**
3. **one Red pot**

Findings:
- **One pot is enough.** Shift turns red into yellow and blue. Without any pot, nothing can single out one primary (proven), so **at least one "biased" source is required**. Story beat: level 1 = "you have one pot of red paint."
- **Every piece of Mix + Invert + Shift + Red pot is necessary:**
  - without Invert, paint can never be taken away (proven);
  - without Shift, paint never moves between primaries (proven). A single Swap (red/yellow) is *not* a substitute: blue stays stuck.
  - a kit built only on Contrast can only toggle, so it can't mix or filter (proven).
- Complete kits verified: NOR + Shift + Red pot; Mix + Invert + Shift + Red pot; Mix + Filter + Invert + Shift + 3 pots; Mix + Filter + Contrast + Shift + Red pot. Random machines of 1–3 inputs were built from each kit's own pieces and matched their tables exactly.

### 2.5 Starting pieces

✅ **Decided (2026-09-28): the middle kit.** Red pot, **Mix, Filter, Invert, Shift**, plus the free Split and Catch pot. The red pot is the only basic pot; the other seven are earned as inventions (§5.1).
- Filter arrives early as a critter (a sieve tub that holds back whatever the two paints don't share). With a pot it works as a mask (`Filter(card, Red)` keeps only a picture's red), which makes for better early card levels and suits noisy cards (§5.1).
- The De Morgan discovery isn't lost; it moves to the **"invent what you know"** chapter, where the player rebuilds critters they already use: *"one of these critters can be built from the others."* Filter from Mix and Invert, and its mirror, Mix from Filter and Invert.
- One more critter to draw and animate than the lean kit, but far less than the full kit's three extra pots.
- Built (2026-09-28): the Filter critter and piece. It arrives in Sandy Crab (once Smudges), and from there every tray offers the whole kit, except where a level rebuilds a critter or offers only an invention and Split (chapters 3 and 4, §5.1).

*Superseded recommendation, kept for the reasoning:* **the lean kit.** Three vat critters and a pot. *"Everything in Chromaton is made from three critters and a pot of red paint."*

| Piece | In → out | Behaviour | Critter idea | Signature animation |
|---|---|---|---|---|
| **Red pot** | 0 → 1 | Red paint, forever | Chubby clay pot, sleepy | Burps a red drop each tick |
| **Mix** | 2 → 1 | Everything in either input | Wooden tub with a spoon (mockup) | Stirs; the paint swirls into the new color |
| **Invert** | 1 → 1 | Complementary color | Tub that somersaults (mockup) | Flips like a pancake; the paint lands as its opposite |
| **Shift** | 1 → 1 | Turn the wheel one step: Red → Yellow → Blue | Hamster in a red/yellow/blue wheel | Runs; the wheel clicks one notch |
| Tube split | 1 → n | Copies the paint | Plumbing, not a critter | None; free and not counted as a piece |
| Catch pot | 1 → 0 | Swallows every drop and remembers the last few | Pale glazed jar, wide awake, looking back up its tube | Gulps; its tag shows the last colors caught, newest first. Free. ✅ **Out of the trays for now** (2026-09-28): players couldn't tell what it was for, since tubes already show their drops and Step back traces a run. Tapping a tube shows its last few colors instead. It comes back with a real job: the output bin for multi-output and buffer puzzles (§5.4), or where stray paint goes once routing can skip stitches |

- **Filter becomes the first invention** (Act 2): "keep only what both share" = invert both, mix, invert back. It takes 4 pieces and is a real "aha" moment.
- Every other pot is an invention earned in the paint box (§5.1), priced at the machine that made it. Levels may still provide pots as givens.
- **Prototype v0.1 ships the lean kit** (Red pot, Mix, Invert, Shift, free Split). Pieces are one data table (`core/pieces.gd`), so adding Filter as a piece is a one-line change (plus its critter).
- Trade-off: in the lean kit, routing machines cost more (Three-way Switch 35 pieces vs 21 with Filter as a piece; see report §6). Fewer critters to design and animate outweighs this (see §7.2 risk). Placed recipes appear as one block anyway, so the price only shows on the optimizer's scoreboard.
- Alternative (full kit): Mix, Filter, Invert, Shift + 3 pots. Cheaper machines, but 5 critters and 3 pot variants, and the De Morgan discovery is lost.

**Early inventions and their price in the game's kit** (report §6; proven cheapest by search unless marked ≤): Yellow pot 2 · Third Color 2 · Bleach 2 · Black pot 3 · Contrast 4 · Consensus 4 · Prism 6 · Any Red? 6 · Same Color? ≤ 8 · Three-way Switch ≤ 21 · Three-way Selector ≤ 23. Without Filter (chapter 3's trays): Filter 4 · Bleach 3 · Contrast 7. *(The old lean-kit list here had Black pot 5 and Consensus 11; the search found Mix(Red, Invert(Red)) and The Flower's 4-piece rule.)* These are machine sizes; since the invention discount (2026-10-05, §5.1) the earned invention costs one less.
- ✅ ~~The Black pot is earned in All the Paint (level 6), whose tray has no Invert, so it costs 5 there and can never reach its real cheapest, 3.~~ Resolved (designer's chapter plan, 2026-10-05): a later level re-earns it. **Black, the Short Way** (level 8) weaves black with `Mix(Red, Invert(Red))` and earns the Black pot at 3; the cheaper machine wins (§5.1).

What the player invents and keeps: **recipes** (stateless) and **machines** (stateful).

---

## 3. World, theme and vocabulary 🟡

🟡 **Leaning: dye works + loom**, the world the chosen Critter Workshop style (§7.2) was mocked up in: wooden vats with faces, glass tubes, pattern cards, a wooden loom. Vocabulary below still needs confirming.

Candidate worlds (can be blended):

| World | Component | Wire | Bus | Invention | Memory | Product |
|---|---|---|---|---|---|---|
| Dye works / textile mill | Vat | Thread | Skein / Braid | Recipe | Spool | Tapestry |
| Print shop | Press / Plate | Ink line | Ribbon | Stencil | Ink well | Print / Poster |
| Painter's guild | Mortar / Easel | Stroke | Band | Technique | Palette well | Masterpiece |
| Alchemy lab | Alembic | Tube | Bundle | Formula | Vial | Elixir |
| Waterworks / canals | Sluice / Lock | Canal | Aqueduct | Blueprint | Cistern | Fountain |
| Botanist's garden | Graft | Stem | Trellis | Cultivar | Seed bank | Flowerbed |

Notes:
- **Print shop** fits the algebra best: real printers split images into color plates (= Prism) and overlay them (= Mix).
- **Painter's guild** has the best progression: apprentice → journeyman → master; a *masterpiece* was historically the work you submitted to become a master, so it's a perfect finale.
- **Dye works + loom** gives the strongest story (Jacquard → Babbage, see §4).
- **Waterworks** fits vertical flow literally.

Working vocabulary until decided: *vat* (component), *tube* (wire), *braid* (bus: parallel tubes), *recipe*, *machine*, *journal* (§5.7; its Inventions tab holds the player's inventions).

✅ **The lexicon** (2026-10-04): the vocabulary lives in [docs/lexicon/](docs/lexicon/lexicon.md), one file per term with an index, answering the playtest call for a vocabulary. One catch-all collection, each term tagged by use: *gameplay* (the player meets it; its Gameplay paragraph is what the journal shows), *design*, *implementation* (its paragraph is a reminder for us, never shown) and *temporary* (a placeholder name kept on purpose for now). The gameplay terms are the player's lexicon, the journal's Words tab (§5.7).
- ✅ **Paint, not color**, everywhere the player looks (2026-10-04); color stays the code's and the algebra's word.
- ✅ **Tube and thread** (2026-10-04): a *tube* carries paint between pieces; a *thread* is a line of stitches in the cloth, a row across or a column down. "Thread" no longer means the wire.
- ✅ ~~**Names kept for now, tagged temporary** (2026-10-04): Mix, Filter, Invert and Shift (noun names wanted, Filter most)~~, and the tray (the playtest's "tool area"; still temporary).
- ✅ **Two names for every piece** (designer, playtest round 2, 2026-10-05; built 2026-10-05). The operation's name belongs to the algebra, the code and this document; the critter's name is the only one the player sees (tray, hints, step lines, journal), so the algebra and the art can change apart. Testers asked for nouns, and for a new name for Filter.

  | Operation (internal) | Critter (player word) |
  |---|---|
  | Red | red pot (earned pots likewise: Yellow, yellow pot) |
  | Shift | Shift Wheel |
  | Mix | Mixing Tub |
  | Invert | Flip Pan (was Flip Tub; designer, 2026-10-05: think omelettes) |
  | Filter | Sieve |
  | Split | Split |

  ✅ Inventions follow the same rule where their names differ (designer, 2026-10-05; built 2026-10-05): **Contrast** (`Filter(Mix(A, B), Invert(Filter(A, B)))`, the XOR analogue) stays the internal name; the player's is **Extreme Mix**, on the sticker, the tray, the journal and in level titles (The Queen · Extreme Mix, The Black King · Extreme Mix). Third Paint, Missing From Either and Same Paint already are their player names.

  The names follow today's critters; the art review can give them more personality without changing what they are. **Workbench becomes the workshop** for players (where the critters, the machines and the player work together; it's also the art style's name); `ui/workbench.gd` keeps its name. Hints and lexicon Gameplay texts switched when the rename was built (2026-10-05). 🟡 Later: the inventions' names and personalities.
- ✅ **Critter, tray and workbench are player words**, each with its lexicon entry.

Buses: ✅ parallel = a **braid** of N threads; serial = a **sequence of colors over time** on one thread.

---

## 4. The Loom 🟡

The central visual and the late-campaign goal. Historical anchor: the **Jacquard loom (1804)** used punched cards and inspired Babbage; the campaign quietly retraces that history.

| Loom | Chromaton |
|---|---|
| **Warp** (vertical threads) | Output columns: a loom of width W has W output threads |
| **Weft** (one horizontal pass) | One tick: each tick weaves one row |
| **Pattern card** | The program / input buffer |
| **Cloth** | The history of the output over time, growing downward under the machine |

- **Time is the vertical axis of the image**; from the painting's point of view, color flows purely vertically.
- Every run of every level produces a strip of fabric.
- **Chapter payoff:** each level weaves one band; completing a chapter joins the bands into a **quilt** (✅ the word, 2026-10-04; built as the quilt beside each chapter's cloths in the journal, §5.7). "Tapestry" is kept for the finale.
- Finale: a **programmable loom** (the CPU equivalent) that weaves a tapestry from a pattern card.
- 🟡 **Serial vs row weaving:** a single output thread weaves one stitch per tick with a shuttle walking the rows (as in the style mockup); a braid of W threads weaves a whole row per tick. Early levels can be serial; braids arrive later and weave faster.
- ✅ **Prototype: serial weaving.** One output thread; the loom takes one drop per tick and weaves the next stitch, row by row, left to right. The first wrong stitch stops the run and is marked.
- 🟡 A wooden shuttle threads along the row being woven, right across the slots, sitting on the next slot, and slides on to the next slot after each stitch (back to the left edge for a new row), trailing the weft it lays. The loom's cloth shows weft threads along each row, crossing the warp; the design card stays a plain picture.
- 🟡 Unwoven cells are sunken slots, darker than the cloth, so an empty slot never looks like a woven white stitch (bright and full size); a small faint chip of the target's paint sits in each (white as a pale chip). The target picture is pinned beside the loom as a small design card.
- 🟡 Woven stitches carry no glyph dots (as in the mockup); the wrong-stitch bubble compares the two drops with dots.

**The pattern card's look: two paths, mutually exclusive** (designer, 2026-10-06, from the R3 playtest notes). The card is shown one way, so the paths are alternatives, not stages: choosing B retires A's strip-specific work.

- **Shared by both (✅ decided, built whichever path wins):**
  - Card length 4 to 8 drops, 6 by default (was 4 to 10; touches `.\make cards`, `card_shows` and the solver's decoding checks).
  - The loom's shuttle stands before its next target and steps onto it on a successful stitch (it sits on the next slot today, as the 🟡 above says).
  - **Shuttle** joins the journal's Words and the lexicon.
  - What a card shows still decodes the level (§5.1): the solver's proof holds under both paths.
- **Path A: improve the card as it is (✅ decided, with one open item).** The card stays a strip of its next `card_shows` drops that slides as it releases. The open item is the failed-run display: the card's look-back (built in WP2) shows the starting window or the window ending at the wrong drop, never both; the playtest asks for both. Any fix here (a faint second window, say) belongs to the strip and is thrown away if B is chosen, so it waits unless B is more than a release away.
- **Path B: the card as the loom cloth's counterpart (🟡 built on branch `path-b-card-picture` (2026-10-06), awaiting the designer's verdict; if kept, Path A's strip work is retired).**
  - *Narrative:* the level's machine converts the pattern pictures into a result cloth. This points at an image algebra (pictures in, an operator, a picture out) without ever naming it; player-facing text stays in paint and thread. The simulation already is that: stitch *i* depends only on each card's *i*-th drop.
  - *Look:* the card is a picture on the loom's grid, in the loom's raster order, so card cell *i* lines up with cloth cell *i*. The next `card_shows` cells are uncovered, cells already read stay shown (as woven stitches do), the rest is veiled slots (as the loom's unwoven ghost slots are), which leaks the card's shape and no colors. The card gets its own shuttle and cursor, standing before its next drop.
  - *Failed run:* the read trail and the ringed drop show where the run stopped, which replaces the look-back and answers the playtest note by itself.
  - *Why it's worth it:* chapter 6's Appliqué (the cards are the player's earlier cloths) and the "rows that remember" chapter need cards that read as pictures.
  - *Risk, bench room: settled, it fits.*
    - The campaign's cards are all 8×6 (the target's own shape) and no campaign level has more than two cards; the 16×12 Harbour and the three-card Flower are Lost Levels, shown nowhere.
    - **Picture sizes (designer, 2026-10-06): 8 columns by 6 rows (4:3, like the loom cloth) is the default for patterns and cloths; a card's picture may run from 1 row by 4 columns up to 9 rows by 12 columns** (`Level.CARD_COLS_MIN/MAX`, `CARD_ROWS_MIN/MAX`, checked by the levels test; the Lost Levels' 16 by 12 pictures are beyond it, shown nowhere).
    - The cell is always 16 px, so the body follows the picture: 156 px wide at least (the default's width, the first two cells), 220 px wide and 168 tall at the largest, 40 tall at the smallest. It sits on rows 1 to 5 (row 0 and 6 would poke off the bench), anchored at the bench's left edge, with its out port on its right edge. Pieces keep off the cells under its body and a piece's size beside it (two spots up and down for the default; more for a bigger one). Two default cards at rows 1 and 5 leave the middle of the bench free. A picture beyond the bounds shrinks its cell to fit them.
    - The card's book button floats just above the body.
  - *Cost, `.\make bench`:* a redraw every tick of up to a picture's worth of drops. Glyph swatches on the whole trail took the paints layer from about 0.6 to about 4 ms a frame (30 ms worst); the trail as plain muted discs while running, glyphs only on the frozen wrong-stitch view, brings it to about 1.3 ms (running average 2.8 ms against 2.6 before).
  - *Built:* `K.card_body` (the veiled slots), `K.card_paints` (the trail, the window, the shuttle, the ringed drop), `K.card_rect`, the workbench's `_card_rect`, `_card_rows`, `_card_reach`, the journal's pattern-card picture, the lexicon's Gameplay text (and `data/words.json`).
  - *Still open:* the shuttle on the card stands in the gap before the next drop and covers part of the drop just read; the loom's own shuttle still sits on its next slot (the shared item above). The "Shuttle" word is not in the lexicon yet.

---

## 5. Modes

### 5.1 Campaign: Invention ✅ (arc 🟡)
Solve a level → earn the construct (recipe/machine) → use it in later levels.

Draft arc:
1. **Mixing:** blend, "is it black?", sort primaries (monotone, gentle).
2. **Negation:** Invert arrives. Contrast recipe (XOR analogue), equality detector.
3. **Rotation:** Shift arrives. "Third color" recipe, hue counters, comparators.
4. **Memory:** feedback loops → Palette Cell (latch) → braided registers.
5. **The Loom:** programmable loom weaving from a pattern card.

Level specs are shown as **animated input/output swatch streams**, not truth tables.

**The campaign, chapters 1–4** ✅ (the designer's chapter plan, 2026-10-05; built 2026-10-05, then rebuilt as the round 2 campaign below, built 2026-10-05: 12, 12, 6 and 6 levels, 36; levels/*.json; cheapest counts proven by `tools/level_solver.gd`, see [docs/level-report.md](docs/level-report.md)). Four chapters of 9, 12, 6 and 6 levels (33). Every chapter after the paint box has a multiple of three levels and a fixed number of patches across, so its quilt fills its grid (§5.7). Every level's reference solution solves it at exactly its three-star count. Chapters 5 and on are parked in the designer's playtest notes, not built.

✅ **Campaign rules** (designer, playtest round 2, 2026-10-05):
- **Each chapter holds together:** one world and one thing to learn about the algebra, a quilt that reads as one piece, **at most 12 levels**, and a multiple of 3 levels (with its `quilt_across`, the quilt fills its grid; 4 across means 12). A chapter that grows too big is split. A chapter short of a multiple of 3 gets a new level made for it; a level that doesn't fit can be pushed to the next chapter.
- **At most two new inventions per chapter** (designer, 2026-10-05; pots aside, and earning one again doesn't count). A level may do an invention's job before the level that invents it, when the story and the chapter's order want it: Wash Out does Bleach's (`Filter(A, Invert B)`) in chapter 2 and stays a puzzle; Bleach and its looking-glass twin `Mix(A, Invert B)` wait for a chapter with room.
- **Levels aren't removed** unless they make no sense at all. One that leaves the campaign goes to **Lost Levels**, a hidden extra campaign. ❓ How it's found and laid out (its own quilt?) is open.
- **A piece comes in three steps:** the level that invents it, if it's an invention (a pot, the Third Paint); the level that introduces it, which is guided (§5.7); then card practice. For a critter the first card practice is its **swatch**, one run showing it on every paint, which fills its journal page: Turn the Wheel (Shift) and Opposites (Invert) today. ✅ Mix and Filter get one each, a **table level** (built 2026-10-05: The Mixing Table, The Sieve Table): card B is the eight paints in journal order on every row, card A one paint per row (red, yellow, blue, orange, purple, green), the machine one Mix (or Filter), so the 8×6 cloth is the piece's table, 33 of its 36 pairs, white and black as columns. Then the first real use (Sandy Crab: Filter as a mask; Parrot: Split as a fork). Split, the pot and the inventions have no swatch.

✅ **Chapter 1, The Paint Box** (this table is the nine-level paint box, superseded by "The new chapters 1 and 2" below, built 2026-10-05): no pattern cards. Each level weaves one row of one color from the red pot, one level per paint. ✅ One row of 8 stitches, the same length as the threads (playtest, 2026-10-04: single colors need no picture; was 4×3), so the nine rows stack into the chapter's quilt. Every level has a cheaper answer to find.

| # | Level | Teaches | Tray | ★★ budget | ★★★ best |
|---|---|---|---|---|---|
| 1 | One Pot of Red | Place a piece, lay a tube (wordless hand hint) | pot | 1 | 1 |
| 2 | Yellow | Shift | pot, Shift | 3 | 2 |
| 3 | Blue | Pieces chain: Shift twice | pot, Shift | 4 | 3 |
| 4 | Orange | Mix: two pots, one of them shifted | pot, Shift, Mix | 5 | 4 |
| 5 | Purple | Split: two pots is ★★, splitting one pot's paint is ★★★ | pot, Shift, Mix, Split | 5 | 4 |
| 6 | All the Paint | Black = every primary; two Mixes | pot, Shift, Mix, Split | 6 | 5 |
| 7 | Green | Invert. Mixing yellow and blue is ★★; Invert(red) is ★★★ | + Invert | 4 | 2 |
| 8 | **Black, the Short Way** | A paint and its opposite make black: `Mix(Red, Invert(Red))` | pot, Shift, Mix, Split, Invert | 4 | 3 |
| 9 | Nothing at All | White: make black, then flip it | all | 6 | 4 |

- ✅ Black, the Short Way (`black_short_way`) re-earns the Black pot at 3, so the pot reaches its real cheapest (it costs 5 from All the Paint, whose tray has no Invert); the cheaper machine wins (§2.5). Hint: "A paint and its opposite hold every paint between them. Mix red with its own opposite." Nothing at All's hint is now "White is the opposite of black. Flip your black."

✅ **Locks, invention prices and the paint box** (designer, playtest round 2, 2026-10-05; built 2026-10-05). Replaces the table above.
- ✅ **A level waits for an invention it can't do without.** A level whose tray can't build its cloth without an invention stays locked until the player owns it, on top of the solve-two-ahead rule; `tools/level_solver.gd` proves which levels those are (today 23, 24, 27, 29, 30 and 33, whose trays offer only the invention and Split). Its locked tag says where to earn it ("Earn the Third Paint in 25. The Pawn.", the text decided 2026-10-05). A level whose tray can also build it from basic pieces opens by the usual rule,. ~~It says so when ★★★ needs the invention~~: dropped (2026-10-05), since the lock chain means those levels (28, 29, 34) open only after levels that wait for the invention, so the player always owns it there. The skip promise holds: both earning levels open their chapters and are their easiest (★★★ 2). (It was a bug: skipping the earning level, unlock-all or a kept old save left those trays with only Split.)
- ✅ **Force unlock comes with the tools.** Unlocking every level (`.\make unlock`: a developer's and tester's cheat; ~~the all-unlocked web build too~~, see below) lends every invention and pot the levels offer, at its reference price, without saving it. Earning one for real replaces the loan.
- ✅ **No all-unlocked build; cheat codes instead** (designer, 2026-10-05, answering the R1 call for a web build with every level open). Nothing is unlocked by default in any build. Testers unlock levels on demand with **cheat codes**, and the cheat engine exists only in development releases, never in a public one. A cheat that opens a level lends what it needs, as force unlock does. Testers keep their progress from build to build through save compatibility where feasible (§9, saves), not by starting unlocked. ❓ The cheat engine itself (the codes, how they're entered touch-first, what marks a development release) is for a later discussion.
- ✅ **The invention discount.** An invention costs the pieces of the machine that made it, inventions inside at their own price, **minus one**, and never less than 1 (was the plain total). Inventing now pays on Pieces, not only on Ticks, and a cheaper machine still makes a cheaper piece. It compounds: Same Paint from four Third Paints costs 4 − 1 = 3. Pots are inventions and follow the same rule; no separate pot prices (the playtest's "primaries 1, mixed 2" falls out of it). Every star threshold from Blue on changes; `.\make solve` re-proves them. Keep What They Share, Either, Not Both and Mix Without Mix gain a ★★★ answer that needs their invention (3 against 4 from basic pieces, checked by hand; Contrast is `Third Paint(Third Paint(A, B), Filter(A, B))`).
- ✅ **Chapter 1's first half has no Invert:** the red pot, Shift, Mix, Split and the earned pots. From Blue on, each tray offers every pot earned so far, so no paint is built from red alone. With the discount: Yellow 1 (`Shift(Red)`), Blue 1 (`Shift(Yellow)`), Orange 2 (`Mix(Red, Yellow)`), Green 2 (`Mix(Yellow, Blue)`), Black 3 (All the Paint, `Mix(Orange, Blue)`).
  - **Purple keeps Split's lesson by holding every pot back** (`hold_pots`): with only the red pot, splitting it (`Mix(Red, Shift(Shift(Red)))`, 4) beats two pots (5), and the Purple pot costs 3. With pots open Split never earns a star: a pot made from red and k pieces costs k, the same as splitting the red and adding those k pieces.
- ✅ **Its second half brings Invert in by making the pots cheaper**: improvements come forward, never back (sending the player back to improve a pot means the level design failed). Every mixed paint is a primary's opposite, so Green (`Invert(Red)`), Orange (`Invert(Blue)`) and Purple (`Invert(Yellow)`) are re-earned at 1, then Black, the Short Way (`Mix(Red, Green)`, Black 2) and Nothing at All (`Invert(Black)`, White 2); the cheaper machine wins. A machine with no card weaves one paint, so they belong with the paint box's rows, not among chapter 2's pictures (designer, 2026-10-05: chosen over opening chapter 2 with them, which would have split it), and the full shelf closes chapter 1 again.
- ✅ **The new chapters 1 and 2** (designer, 2026-10-05; built 2026-10-05). Titles here are the working names; the decided ones are in the level text below.

  | # | Chapter 1, The Paint Box (12 rows) | Teaches | Earns |
  |---|---|---|---|
  | 1 | One Pot of Red | guided: pot, tube | |
  | 2 | Yellow | guided: Shift Wheel | Yellow 1 |
  | 3 | Blue | guided: an earned pot as a piece | Blue 1 |
  | 4 | Orange | guided: Mixing Tub | Orange 2 |
  | 5 | Purple | guided: Split (pots held) | Purple 3 |
  | 6 | Green | yellow and blue | Green 2 |
  | 7 | All the Paint | every paint makes black | Black 3 |
  | 8 | *Green, by its opposite* | guided: Flip Pan, `Invert(Red)` | Green 1 |
  | 9 | *Orange, by its opposite* | `Invert(Blue)` | Orange 1 |
  | 10 | *Purple, by its opposite* | `Invert(Yellow)` | Purple 1 |
  | 11 | Black, the Short Way | `Mix(Red, Green)` | Black 2 |
  | 12 | Nothing at All | `Invert(Black)` | White 2 |

  | # | Chapter 2, Pattern Cards (12, 4 across) | Teaches |
  |---|---|---|
  | 13 | The Pattern Card | guided: the card |
  | 14 | Turn the Wheel | Shift's swatch |
  | 15 | Opposites | Invert's swatch |
  | 16 | Orange Sun | a card and a pot |
  | 17 | Parrot | the fork: Split on a card |
  | 18 | *Mix Table* | guided: a second card; Mix's swatch |
  | 19 | Lighthouse | two cards mixed |
  | 20 | *Filter Table* | guided: Sieve; its swatch |
  | 21 | Sandy Crab | Sieve with a pot as the mask |
  | 22 | Where They Meet | two cards sieved |
  | 23 | Wash Out | `Filter(A, Invert B)` |
  | 24 | Harbour Cat | the closer: a fork three ways |

  ✅ **Ids** (designer, 2026-10-05): an id follows the machine, not the slot, so old saves still fit. `green` stays on the `Invert(Red)` level (8, today's Green); the new levels are `green_mix` (6), `orange_opposite` (9), `purple_opposite` (10), `mix_table` (18) and `filter_table` (20, the operation's name: ids are internal). Every other level keeps its id; `orange`, `purple`, `black`, `black_short_way` and `white` build the same machines in their new slots.

  Chapters 3 and 4 keep their six levels each (36 in all), with room to grow to 12 with new recreational levels (playtest notes, for a later round).
- ✅ **The spikes:** Harbour Cat stays and closes chapter 2, long after Parrot's two-way fork (a closer blocks nothing; the next chapter opens from the level before); its hint is rewritten. **The Harbour** (three cards) goes to Lost Levels until chapter 6 earns its rule as Consensus. **Only the Third Paint** and its twin **Only Missing From Either** stay as capstones: they block nothing, the discount takes them from 8 pieces to 4, and the hint was the real trouble. If testers still hit a wall after the new hints, the pair moves out together (moving one breaks chapter 4's mirror).
- ✅ **Several cards are advanced:** inside a chapter, one-card levels come before two-card ones; a second card arrives in a guided level; three cards only from chapter 5 on.
- ✅ **To Lost Levels:** Flip Side (the same puzzle as Opposites) and The Harbour.
- A player who solved Yellow at ★★ can't reach ★★★ on Blue. Rare (the earning machines are 2 to 4 pieces); the hints cover it, and stars don't adapt to the player's own pots.

✅ **Level text** (designer, 2026-10-05; replaces "Level text teaches", 2026-10-04). A meta-design goal: the game teaches players its own rules and world through play, so level text guides the player. A level's text has three parts: a title (can be anything), a **goal that says what to weave** ("Weave the parrot.") and a **hint that states the rule in paint, then how to approach the machine**. Example: "Wherever the card has paint, the cat is black. Turn the card's paint around the wheel and mix every turn together." Never bits, binary or bytes. Pieces are named as the tray names them (Shift, Mix, Filter, Invert, Split, the Third Paint, Missing From Either). Every one of the 33 levels follows it; hints run to about two sentences (the designer's are around 110 characters, the longest about 140). 🟡 Chapter 4's hints name the chapter 3 level they mirror ("Back to Mix in the looking glass: build a Filter. ...").
- ✅ **The title says what you do, the hint says how** (designer, playtest round 2, 2026-10-05; replaces the three parts above; built 2026-10-05). R1 testers didn't read titles, so the title carries the goal.
  - **The title has two phrases**, side by side in the top bar: what the cloth is, then what the machine is ("The Queen · Either, Not Both"). On an invention level the machine phrase is the invention's name, the piece it becomes, with a small sticker mark beside it (replacing "Your machine becomes a new piece."); in the paint box it's the pot invented ("Yellow · The Yellow Pot"); elsewhere a short phrase in the tray's words for what the machine does ("Keep the Red"). It says what the machine does, never how it's built (that's the hint), so it never gives away the cheapest answer; where nothing fits without spoiling, the cloth alone.
  - **No goal or hint line in the top bar** any more. The **hint panel** (the level note) holds the goal and the hint, with room to spare, scrolling if it ever needs to.
  - **The hint:** a world-story sentence, full stop, then the how, naming pieces as the tray does ("The sand washes out. Sieve the card down to its red."; a piece's name works as a verb too). Two sentences work well; length is no longer bound by the top bar. On guided levels the step lines teach, and the hint stays for coming back.
    - ✅ **The showing levels skip the story** (designer, 2026-10-05): the swatches (Turn the Wheel, Opposites) and the table levels (Mix and Sieve tables) exist to show one piece on every paint, and their cloth is its table, not a picture; their first sentence says what the cloth will show, then the how. Their machine phrase may name the piece too ("Turn the Wheel", "Every Pair Mixed"): showing it is their point.
    - ✅ **A paint-rule sentence counts as the world sentence** (designer, 2026-10-05): paint is the world's physics, so where the cloth has little story (the paint box, the chess boards) the first sentence states the paint rule ("Paint on paint makes a darker paint."). The hint is a sentence about the world, its story or its paint, then the how.
    - ✅ **A level's name, its primary title** (designer, 2026-10-05; built 2026-10-05): the phrase that tells its chapter's levels apart. Everywhere but the paint box, the cloth phrase ("The Parrot", "The Black Queen"); in the paint box, whose cloths are plain colours, the machine phrase (One Pot of Red, The Yellow Pot … The White Pot, A Cheaper Green Pot …), all unique. It is what the level select's tags, the Cloths slots and the Scores rows show; the whole title only the top bar and the hint panel. **A reference to a level inside text gives its number and primary title: "2. The Yellow Pot"** (the journal's locked lines, the locked-tag line, "New in your journal", hints that name another level). At the rebuild the lexicon's "unlocks in" lines follow (Yellow → The Yellow Pot, Orange → The Orange Pot, Purple → The Purple Pot, Green → The Green Pot, Nothing at All → The White Pot, The Pattern Card → The Sailboat), then `.\make words`.
    - ✅ Where any machine phrase would give the puzzle away, the title is the cloth alone (designer, 2026-10-05): The Orange Sun (its every honest phrase says "add yellow"). Titles keep small words lowercase ("Each Paint and the Next").
  - **After a failed run the hint's "?" glows softly**, until the player opens the hint or runs again.
  - ✅ **Every level's text is decided** (designer, 2026-10-05; built 2026-10-05: titles, goals and hints are in `levels/*.json`; the guided step lines wait for the guided levels, §5.7). Titles, goals, hints and guided step lines for all 36 levels and the two Lost Levels, plus the text outside the level files (locked tags, "New in your journal" lines, the paint-card line on each piece page, the Lost Levels line), live in **[levels/level-text.md](levels/level-text.md)** (tracked; not exported, which ships only `levels/*.json`) until the campaign rebuild writes them into `levels/*.json` and the code. The level files stay as they are until then. Settled in it: the paint box earns under pot names (The Black Pot, A Cheaper Black Pot, The White Pot); The Queen and The Black King · Extreme Mix (§3); Sandy Crab "Sieve the card down to its red."; The Orange Sun as the cloth alone; The Rook guided (§5.7); the ids above. Checked: each hint's how earns at least ★★ (Harbour Cat's route is 5 against ★★★ 4; The Queen's 4 needs its re-proved ★★ budget to stay at 4 or more, for `.\make solve` at the rebuild).
- ✅ **Built (2026-10-04); replaced (2026-10-05) by the hint panel above, which flies home into the title's "?" (no line under the title):** the hint must be visible and easy to revisit, so a level's note (title, goal, hint) pops up over the bench as an unsolved level opens; a tap anywhere or any key sends it flying home, where the hint (or the goal, on a level without one) sits under the title in ink. A "?" badge by the title says the title is tappable: tapping it brings the note back. 🟡 (2026-10-05) The note grows to fit a two-sentence hint, and the line under the title wraps onto two smaller lines when one wouldn't clear the run controls.

✅ **The pattern card gets its own level** (The Pattern Card: tube a card straight to the loom and the first picture appears, a sailboat; no pieces, the hand hint shows the tube). Chapter 2 follows from it.

- The v0.1 levels "Yellow from Red" (Shift a card) and "Opposites" (Invert a card) were cut: chapter 1 teaches both. Their files were removed. Opposites came back in chapter 2 (below).
- ✅ **Each level offers an explicit list.** A level offers only the pieces and inventions it names, so tools the player has earned never trample a puzzle that is meant to go without them. An invention also has to be owned to appear. Earned pots are the exception, below.
- ✅ **Locked pieces** (playtest, 2026-10-04: tools the player already knows should still show where a level holds them back; built 2026-10-04). What the tray *shows* follows the campaign; what is *open* is the puzzle's own list. A level's tray shows what it offers plus every piece an earlier level offered, locked: the tray as it was when the campaign got there, so a revisit looks like the first visit, and pieces from later levels stay out. It's worked out from `levels/index.json` (`Level._lay_trays`), not from the save, so the solver, tests and screenshots see the player's tray. Pieces sit in the order the campaign first offers them (pot, Shift, Mix, Split, Invert, Filter), so a new piece always joins at the right end and no piece's slot or number key ever moves. A locked slot keeps its tag paper, with the critter faded under a paper veil, its name faded and the lock (as on a locked level tag) where the key cap sits; a tap, drag or key places nothing, the lock wiggles and a carried piece drops back. So The Pattern Card shows pot, Shift, Mix, Split and Invert locked (with nothing open, no pieces bar, and the hand still lays the card's tube); Orange Sun locks Split and Invert; Keep What They Share locks Filter; Mix Without Mix locks Mix; the levels that offer only an invention and Split lock every critter and the pot.
- Level ids are stable names (`green`, `black_cat`), not numbers; the number shown is the level's place in `index.json`, so levels can be inserted without renaming files or breaking saves. A renamed level keeps its id (Smudges is now Sandy Crab, Black Cat Harbour Cat, The Flower The Harbour; `third_color` is The Third Paint).
- Pattern cards are derived from each target picture by `tools/make_cards.gd` (seeded by level id, so reruns match). The solver also proves the card data has no cheap shortcut.
- 🟡 Harbour Cat uses a red/white card instead of the red pot, so the black cat is a picture and not a plain black cloth.
- ✅ **Chapters** (built 2026-09-28): `levels/index.json` lists chapters, each a name, its levels and (after the paint box) `quilt_across`. The level select shows one chapter per page (four tags per row, twelve at most), turned with arrows, with a dot per chapter; it opens on the chapter the player was last in. Level numbers run on across chapters.
- ✅ **Every other color pot is an invention** (designer, 2026-09-28): solving a paint-box level earns a pot of that color, a piece that makes that paint every tick. Like any invention it costs the pieces of the machine that made it (Yellow 2, Blue 3, Orange 4, ...). ✅ From 2026-10-05 (built 2026-10-05): one less, the invention discount, and built from earlier pots (Yellow 1, Blue 1, Orange 2; above).
- ✅ **Pots as pieces** (designer's chapter plan, 2026-10-05; built 2026-10-05). From chapter 2 on, every pot the player has earned is open in every tray that offers the red pot. A level can hold pots back (`hold_pots` in its file: they show in the fan, locked); a level that offers only named pieces (the Third Paint and Split) offers no pots. Star thresholds assume each pot's cheapest price, and the solver and the card maker search with every pot at that price. Worked out from the campaign like the tray (`Level.pots`, `Level.held_pots`); the workbench shows only the pots the player owns. No level holds a pot back yet. ✅ From 2026-10-05 (built 2026-10-05): pots are open from Blue on, in chapter 1 too, and Purple holds them all back (above).
- ✅ **The pots collapse into one tray slot** (designer): the tray shows one pot slot instead of up to eight. ✅ Its form: tapping the slot fans out the owned pots above the shelf; drag one out (touch-first, no hover). A dropdown list would look like desktop UI. ✅ **Built (2026-10-05):** where the player owns pots, the red pot's slot is the pot slot, labelled Pots, two earned pots peeking out behind the red one. A tap fans the pots out on a paper card above the shelf, pointing at the slot, in paint order (the red pot among them), each with its paint and price; tap one to pick it up or drag it out. Dragging the slot itself places the red pot. With the fan open the number keys pick from it; Back or a tap anywhere else folds it. Orange Sun is the first level that shows it.
- ✅ A pot's price is the cheapest the player has made it for, so going back for ★★★ makes the pot cheaper. Star thresholds assume the cheapest price.
- ✅ **Built (2026-09-28):** paint-box levels 2–9 each earn their pot (the Black pot twice), an invention with no inputs and check `paint:<letter>` (the every-paint check is one stitch). A pot invention is drawn as the clay pot with its own paint.
- ✅ **The paint shelf** (built; the journal's Inventions tab, once the Pattern Book): eight pots across the top of the page in journal order, each with its price; the red pot is always there, unearned pots are dashed outlines with the first level that earns them. Invention slots follow below, one per invention however many levels earn it.
- ✅ **Every pot wears a small swatch tag** with its paint's glyph dots (always-on colorblind glyphs), the red pot too (designer, 2026-10-04; it used to have none, as the only pot players start with, and read as missing beside the others on the shelf).
- 🟡 A full paint-box shelf closes the chapter (still true in the 2026-10-05 layout: White is level 12).

**Playtest findings (2026-09-28)** and what they changed:

✅ **Teach what each piece does to every paint.** The paint box only shows Shift and Invert acting on primaries and black, so the card levels asked for rules nobody had seen (Keep What They Share needs Invert on any paint). Two ways at once, because not everyone learns the same way:
- Two short levels show every paint beside what it becomes: **Turn the Wheel** (a card of all eight paints through Shift) and **Opposites** (through Invert). They wove a single **thread** of 8; ✅ since the chapter plan (2026-10-05) they are 8×6 swatches, each row all eight paints in a different order (the card's first row in journal order, the rows below turned one step further each, so the cloth runs in diagonal stripes), so they sit in chapter 2's quilt as full patches. One run still fills the piece's journal page.
- **Glyph dots show the rule when a piece fires:** Shift turns the dots one notch; Invert empties the filled dots and fills the empty ones.

✅ **Card levels don't write the rule in the goal line.** The cards and the design card carry it; the cloth is evidence to read, not just a check. (The hint says the rule since 2026-10-04; see "Level text".) Measured: many cheap machines match the first stitch (83 on Keep What They Share, 2,925 on The Flower) but only one weaves the whole cloth; most wrong ones fail by stitch 2–4, a few only at stitch 79. `tools/make_cards.gd` should order the card data so the cheap wrong machines fail within the first row.
- ✅ **Built (2026-09-28):** `tools/make_cards.gd` lists every function the level's pieces build within its ★★ budget (formula trees over every combination of card paints; since 2026-10-05 with earned pots and inventions at their price), then picks each first-row stitch's card paints among the rule's options, greedily, to make the most of them fail there. The rest of the rows stay seeded random.
- ✅ **What a card shows decodes the level** (designer, playtest round 2, 2026-10-05; built 2026-10-05): the drops a card shows are all the player needs to work out the rule; the rest of the card is ceremony. Every wrong machine within the ★★ budget fails within the drops shown, on every card level, fixed-rule levels too (their first row or picture is adjusted, since their card can't be); `.\make solve` checks it and fails a level that breaks it. **A card shows 4 to 10 drops**, per level, not always 6: by default the shortest that decodes it (found by `.\make cards`), and a level file can ask for more for looks. The bench's card drawing has to fit 10.
- 🟡 **Aimed at what a card shows (playtest, 2026-10-04):** the greedy pick first works on the stitches a card shows at the start (6, `Level.CARD_SHOWS`), then on the rest of the first row. In the 2026-10-05 campaign every card level with choices fails every cheap wrong machine within those 6, except Wash Out (1 of 144 fails at stitch 12) and The Harbour (3 of 74,679 get past the first 6, all fail within the first row). Rules with no choices (copy, invert, unshift, fork, remove_yellow, any_red) rely on their pictures: each first row carries paint (no level starts with a blank row).
- The Flower couldn't be fixed by its cards (its first 22 stitches were white), so it was redrawn with paint from the first stitch (2026-10-04); The Harbour, its successor, keeps that: a sunset sky with gulls from the first stitch.

✅ **Keep What They Share (the De Morgan level) was too steep and blocked the campaign.** Resolved by **Filter first, reinvent it later** (§2.5): Filter is a starting critter, and building it moves to the "invent what you know" chapter. ~~Opened by a stepping-stone level, Missing From Either (`Mix(Invert A, Invert B)`).~~ Since the chapter plan (2026-10-05) chapter 3 opens with the Third Paint as an invention instead, and Keep What They Share asks it for what neither flipped card has (below).
- ✅ Solving a level opens the next two, so one hard level never walls off the rest. (✅ 2026-10-05: a level that can't be built without an invention also waits for it; §5.1, chapter 1.)
- ✅ With Filter as a piece, Wash Out becomes `Filter(A, Invert B)` (2 pieces). The Flower (now The Harbour) gets a new rule, **two of three**: a primary shows if at least two cards have it (4 pieces, `Filter(Mix(C, B), Mix(A, Filter(C, B)))`). Fallback if playtests find it too hard: `Mix(C, Filter(A, Invert B))`, 3 pieces. Two of three is its own mirror twin.

✅ **Smudges are dropped** (designer, playtest round 2, 2026-10-05; built 2026-10-05). Noise isn't algebraic: a paint is "smudged" when another paint is mixed into it, and a card with paint mixed in is just a card. Sandy Crab stays as a Filter level (keep the card's red), without the ink blots or the noise story; the "more smudge levels" and "the Filter before smudges" notes go with it. More variety comes from what's already there: more cards, a card and a pot, and so on. When built: the card JSON's `"smudges"` list and the ink blots go; the `smudges` card rule and level id can stay as implementation names.

~~🟡 **Noisy cards** (designer's idea)~~, dropped above: cards carrying stray paint on some stitches that the machine must clean up. With today's pieces every card drop weaves a stitch, so stray paint is *recolored* (e.g. `Filter(card, Red)`), not skipped; skipping stitches needs routing pieces (§2.3), later. ✅ Built: **Sandy Crab** (once Smudges), a red crab on a card with yellow sand on about a third of its stitches (always some in the first row), cleaned by `Filter(A, Red)`. Stray stitches on a card are marked with a neutral ink blot (never a signal hue), so it's clear where the noise is; the card JSON lists them (`"smudges"`).

✅ **Chapter 2, Pattern Cards** (the chapter plan, 2026-10-05; built; this table is its first layout, superseded by "The new chapters 1 and 2" above, built 2026-10-05). Seaside pictures, every one 4:3 (8×6, The Harbour 16×12), so all patches share a shape; the quilt is 4 across × 3 down. Before Sandy Crab the tray is everything but Filter (Orange Sun: pot, Shift and Mix, Split and Invert locked); from it on, the whole kit. Earned pots are open throughout (the red pot's slot fans them out).

| # | Level | Teaches | Card rule | ★★ budget | ★★★ best |
|---|---|---|---|---|---|
| 10 | The Pattern Card (a sailboat) | A card is paint over time | `copy` | – | 0 |
| 11 | Orange Sun (a sun setting into the sea, a gull) | Mix a card with the **yellow pot**: the card holds the sun's red; the pot fan's first level | `remove_yellow` | 4 | 3 `Mix(A, Yellow pot)` (`Mix(A, Shift(Red))` ties) |
| 12 | **Parrot** (orange and green on white) | **The fork**: Split the card, Shift one half, Mix them back. No machine without a fork weaves it | `fork` | 3 | 2 `Mix(A, Shift(A))` |
| 13 | Turn the Wheel (swatch) | Shift on every paint | `unshift` | 2 | 1 `Shift(A)` |
| 14 | Opposites (swatch) | Invert on every paint | `invert` | 2 | 1 `Invert(A)` |
| 15 | Flip Side (beach flags) | Invert on a picture: a mix flips to a primary | `invert` | 2 | 1 `Invert(A)` |
| 16 | **Sandy Crab** (`smudges`) | **Filter arrives**; the yellow on the card is sand | `smudges` | 3 | 2 `Filter(A, Red)` |
| 17 | **Lighthouse** (at dusk) | Two cards: Mix them, drop by drop | `mix` | 2 | 1 `Mix(A, B)` |
| 18 | **Where They Meet** (a rock pool) | Filter two cards: what they have in common | `filter` | 2 | 1 `Filter(A, B)` |
| 19 | Harbour Cat (`black_cat`) | A fork three ways: the card turned round the wheel, every turn mixed | `any_red` | 6 | 4 |
| 20 | Wash Out (a fish) | Filter with a card as the mask | `bleach` | 3 | 2 `Filter(A, Invert B)` |
| 21 | **The Harbour** (`the_flower`), rule: **two of three** | A primary shows if at least two cards have it | `two_of_three` | 6 | 4 `Filter(Mix(C, B), Mix(A, Filter(C, B)))` |

🟡 Pictures (2026-10-05, for the designer to review): Orange Sun has a sun in the top right setting into a green sea with its reflection and a black gull, everything holding yellow so `Mix(card, Yellow pot)` weaves it. Flip Side, 8×6 now: blue, red and yellow pennants on black poles over the sea and sand; its card (rule `invert`) shows orange, black and green in the first 6 drops and purple right after. Sandy Crab: a red crab with raised claws. Lighthouse: a red and white tower with a yellow lamp and beams on a purple dusk sky over black rocks. Where They Meet: an orange starfish, green weed and a red crab in blue water between black rocks. Harbour Cat: a black cat standing, tail up. The Harbour: a red and white lighthouse on a rock, a white-sailed boat and a small red-sailed one, the sun, gulls, the sea and a purple quay.

The Third Paint left chapter 2 for chapter 3.

✅ **Chapter 3, Invent What You Know** (the chapter plan, 2026-10-05; built). 8×8 patches, the quilt 3 across × 2 down. Pictures: white chess pieces, one per level (pawn, rook, knight, bishop, queen, king), on squares of two opposite paints (orange and blue, 2×2 stitches each) so no first row is all white, each with a coloured gem or two.

| # | Level | Builds | Tray | Card rule | ★★ budget | ★★★ best |
|---|---|---|---|---|---|---|
| 22 | The Third Paint (`third_color`, the pawn) | **First invention: "Third Paint"** = `Invert(Mix(A, B))` | kit | `third_paint` | 3 | 2 |
| 23 | **Neither, Twice** (the rook) | Invert, as `Third Paint(A, A)` | Third Paint, Split | `invert` | 3 | 2 |
| 24 | **Back to Mix** (the knight) | Mix: a Third Paint, its answer flipped by another, `Third Paint(n, n)` | Third Paint, Split | `mix` | 6 | 4 |
| 25 | Keep What They Share (the bishop) | Filter: the Third Paint of both cards flipped | kit without Filter, Third Paint | `filter` | 6 | 4 |
| 26 | Either, Not Both (the queen) | **Invention: Contrast** | kit, Third Paint | `contrast` | 6 | 4 `Filter(Mix(A, B), Invert(Filter(A, B)))` |
| 27 | **Only the Third Paint** (the king) | Same Paint (each primary both cards have or both lack) from four Third Paints. **Invention: "Same Paint"** at 8 | Third Paint, Split | `same` | 10 | 8 (proven by the solver) |

✅ **Chapter 4, The Looking Glass** (the chapter plan, 2026-10-05; built). Each level is the mirror twin (De Morgan dual) of chapter 3's level in the same slot. Its picture is that level's picture in opposite paints (the photo negative: black chess pieces, the squares swapped, the gems flipped), so the two quilts hang as a pair; cards are derived as usual. Every hint teaches the swap: every Mix becomes a Filter, and black becomes white.

| # | Level | Builds | Tray | Card rule | ★★ budget | ★★★ best |
|---|---|---|---|---|---|---|
| 28 | Missing From Either (the black pawn) | **Invention: "Missing From Either"** = `Invert(Filter(A, B))` | kit | `missing` | 3 | 2 |
| 29 | **Missing, Twice** (the black rook) | Invert, as `Missing From Either(A, A)` | Missing From Either, Split | `invert` | 3 | 2 |
| 30 | **Back to Filter** (the black knight) | Filter from two of them | Missing From Either, Split | `filter` | 6 | 4 |
| 31 | Mix Without Mix (the black bishop) | Mix: Missing From Either of both cards flipped | kit without Mix, Missing From Either | `mix` | 6 | 4 |
| 32 | **Same Paint** (the black queen) | `Mix(Filter(A, B), Invert(Mix(A, B)))`. **Re-earns the Same Paint invention** at 4 | kit | `same` | 6 | 4 |

- ✅ **Two inventions per chapter** (designer, 2026-10-05; built 2026-10-05): Only the Third Paint stops earning Same Paint and stays a capstone challenge (its title's machine phrase is still "Same Paint"); Same Paint (32) becomes where it's invented. With the discount both machines priced it at 3, so earning it twice gave nothing. Chapter 3 earns the Third Paint and Contrast, chapter 4 Missing From Either and Same Paint.
| 33 | **Only Missing From Either** (the black king) | Contrast from four Missing From Eithers | Missing From Either, Split | `contrast` | 10 | 8 (proven by the solver) |

- Checked on every paint: the 4-piece builds from the Third Paint and from Missing From Either; `Filter(Red, Invert Red)` = white; two of three is its own twin.
- Card rules in `tools/make_cards.gd`: `smudges`, `two_of_three`, `missing` (two cards sharing exactly the opposite of the target), `mix`, `contrast` (card A random, B = what makes the difference), and since 2026-10-05 `remove_yellow` (the target without its yellow), `fork` (the paint whose mix with its own Shift is the target), `third_paint` (two cards whose mix is the target's opposite), `same` (card A random, B where A and the target disagree). `remove_red` and `third_color` went with the levels that used them.
- The Filter sticker is gone from the campaign (it shared a name with the Filter critter); the tests still build one from Keep What They Share as a fixture, so inventions inside inventions stay covered.
- ✅ Rebuilding a critter earns a journal page on what that critter is made of, plus stars; no sticker (the critter is already in the tray). Built 2026-10-05: the critter's Pieces page shows "Made of", a row per level that rebuilds it (The Rook, The Knight, The Bishop and their twins) with what the player's machine there used, or an empty frame until it's woven.
- ✅ Threads are 8 stitches, every paint once, in journal order, so the cloth reads as a lookup row.

**Inventions in the prototype** ✅: solving an invention level saves the player's own machine to the journal's Inventions tab (once the Pattern Book, §5.7) as a new piece. Its cards become input ports (in card order), the loom its output port; it is drawn as a sticker with its name (on two lines when long) and costs the total of its pieces (✅ minus one from 2026-10-05, the invention discount, built 2026-10-05; see chapter 1 above). The campaign's inventions: the seven pots, Third Paint, Contrast, Same Paint and Missing From Either.
- ✅ **An invention is one piece that takes one tick** (built 2026-09-28). Before, it ran the machine inside, so a Filter sticker took 3 ticks and hid drops in flight: paint seemed to vanish into it and come out late. The simulator stores the invention's answer for every combination of input paints and looks it up. Pieces still count everything inside; Ticks improve, which rewards inventing. Stateful machines (memory) will need their own rule.
- ✅ Before an invention is accepted it is run on every combination of input paints (64 for two inputs). A machine that only happens to match the level's cards is refused with a short note. The one-tick lookup depends on this check.
- ✅ **The cheaper machine wins** (designer's chapter plan, 2026-10-05; built). Every invention, not only pots, keeps the cheapest machine the player has made it with (a tie takes the newest), so a re-solve never makes it dearer. Two levels may earn the same invention: the Black pot (All the Paint at 5, Black, the Short Way at 3) and Same Paint (Only the Third Paint at 8, Same Paint at 4). Its journal slot names the level whose machine was kept. The name comes from the level; players don't name inventions yet.

### 5.2 Optimization layer ✅
Every level has a second loop after solving (the Zachtronics model), not a separate mode. Details in §6.

### 5.3 Fix-it puzzles 🟡
"Zero- or semi-implemented" machines that need finishing or fixing (themed as **restoration** of old masters' machines):
- **Repair:** find the bug, fix with fewest changes ("fewest edits" metric).
- **Complete:** half-built, with locked parts.
- **Constrained:** only these parts / this area / this budget (like BTD6's CHIMPS).
- **Retrofit:** works for order A; adapt to order B with minimal disruption.

### 5.4 Buffer puzzles 🟡
"Here are your incoming colors (input buffer); produce these colors (output buffer)." Sequence puzzles: reverse, sort by darkness, dedupe, interleave two threads, count the reds.

### 5.5 Creative loom (sandbox) 🟡
- Build machines that weave images; share machine + tapestry.
- **Generative textiles:** each row computed from the previous row by a local rule = an 8-color 1D cellular automaton.
- **Compression challenges:** "weave this pixel-art image with the cheapest machine" (repetition → counters, symmetry → mirror recipes). Bridges creative and optimize.
- 🟡 **Parked (designer, 2026-10-05): "try it" and the lab.** "Try it" on a piece's journal page (give the critter paints, watch it work, fill the page's frames) could grow into **the lab**, a bench with only what's been discovered, where new journal entries (and later inventions) can still be found. Revisit with the creative loom. Its reason, Mix and Filter pages filling slowly, is answered by the table levels (§5.1); the journal stays as it is.

### 5.6 Commissions / rush orders (tower-defense-like) 🟡 *later*
Customer orders arrive as incoming color streams with deadlines; the player patches the running machine live; completed orders earn currency for components; waves demand new transformations.
⚠️ Real-time pressure fights the thoughtful-puzzler mindset → offer slow-down/pause, keep it a separate later mode.

**Mode build order:** Campaign → Optimization layer → Creative loom → Commissions.

### 5.7 The Journal ✅
An in-game book that explains how the game works and keeps what the player has made: the eight paints and how they mix, the loom's timing (ticks, one-drop tubes, when a piece fires or waits), every piece, the player's inventions, cloths and best scores.
- ✅ **Named the journal** (designer, 2026-10-04; its old names are in the lexicon), not the compendium: it's the player's own record, filled from play, and an easy word for young players.
- ✅ **One book with tabs: Paint · Loom · Pieces · Inventions · Cloths · Scores · Words** (2026-10-04). ✅ **Built (2026-10-04)** as `ui/journal.gd`, replacing the Pattern Book screen: same way in (the level select's book button, B), paper tabs along the top, a back button. Rewards and achievements: later, a vibe for now.
  - **Paint** and **Loom** are short articles: each word the lexicon gives that tab, with a small picture and its Gameplay text. Paint also holds the paint card's triangle; Loom has loom, stitch, tick, tube and thread.
    - ✅ **Articles fit their text and scroll** (designer, playtest round 2, 2026-10-05; built 2026-10-05). Today each word gets a fixed row of about 114 px on a page that doesn't move; Loom's five fit with about 80 px to spare, and the words still to come (pattern card, drop, design card) would run off it. Each row is as tall as its picture or its text, whichever is taller, plus a gap; an article longer than the page scrolls (drag, the wheel, ↑ or W and ↓ or S, new Journal keys) with a "more below" chip at the bottom that scrolls on when tapped, the same as "New in your journal". Paint and Loom alike. ← → still turn pages and tabs; peek on a tube opens Loom scrolled to Tube.
  - **Pieces** has a page per piece in the order the campaign brings them (red pot, Shift, Mix, Split, Invert, Filter): the critter, its words, and its frames (below). A piece the player hasn't met (no open level offers it) is a lock.
  - **Inventions** is the old Pattern Book: the paint shelf, then the invention slots.
  - **Cloths** is a picture gallery, one chapter per page: a slot per level, the cloth hung from a rod once woven, an empty frame the cloth's shape until then. A solved level's cloth is its target picture, so it needs no save data.
  - ✅ **Quilts** (designer, 2026-10-04): a chapter's cloths join into a **quilt**, hung beside them on the Cloths tab. Patches fill in as cloths are woven; the paint box's threads stack, other chapters sew each cloth into an equal patch. "Tapestry" stays free for the finale. ✅ (chapter plan, 2026-10-05; built) Each chapter after the paint box pins its patches across (`quilt_across` in `levels/index.json`: chapter 2 four, chapters 3 and 4 three) and has a multiple of that many levels, so the quilt fills its grid; patches take the cloths' shape when they share one (4:3 in chapter 2), and the gallery beside it uses the same grid.
  - **Scores** is the scoreboard, one chapter per page: stars, best Pieces and best Ticks per level (already saved), with the campaign's stars and cloths woven at the top. Best only, no run history. Cloths and Scores stay separate tabs: one is a gallery, the other a scoreboard.
  - **Words** is the player's lexicon: every term tagged *gameplay* in [docs/lexicon/](docs/lexicon/lexicon.md), as tiles of a picture and the word; tapping one shows its Gameplay text and a button to its fuller page, if it has one.
- ✅ **A word unlocks when its level is solved** (designer, 2026-10-04). Each lexicon term's "Journal:" line names the level; `.\make words` turns the gameplay terms into `data/words.json`, which the game ships (a test fails if the two drift apart). Locked words stay visible as empty frames naming their level. The paint card's word unlocks in One Pot of Red (the Paints button is there from the start).
- ✅ **"New in your journal"** (designer, 2026-10-04: a stepping stone into the rest of the campaign). After the success panel, whichever way it's left (next, levels, weave again), a card shows what the solve brought: the level's new words (with their text when there are up to three, as tiles past that) and the frames the player's runs filled on piece pages since the last card. Continue goes on; the book opens the journal. Built.
  - ✅ (designer, 2026-10-05; built 2026-10-05) It also shows **updated** entries: an invention made cheaper, with its icon and both prices ("Orange pot: cheaper, 2 → 1"), only when the price drops. And it announces new levels where the level select wouldn't make them plain: a new chapter opening ("A new chapter: Invent What You Know", with its first level's tag) and the levels an invention opens ("The Third Paint opens 26. The Rook and 27. The Knight.", levels referred to by number and primary title). The ordinary next two inside a chapter stay off it.
  - ✅ **How the card grows, with icons** (designer, playtest round 2, 2026-10-05; built 2026-10-05). Today it grows down and clips silently past 740 px, and names pieces without icons. **One row kind** for every entry: an icon on the left as the thing looks in the game (a critter, an invention's sticker, a pot in its own paint, a level's numbered tag for levels opened, the chapter's first tag for a new chapter, a word's picture), a title and one line; a word keeps its text when there are up to three, a frame row its critter, name and drops. **Most important first:** new pages and words (the solve's reward), what opened (chapter, levels an invention opens), cheaper (both prices), frames found; what falls below the fold matters least. **760 px wide** as now, growing to fit up to about 600 px tall, then the list **scrolls** (drag, or the wheel); while more is below, a "3 more below" chip at the bottom scrolls to it when tapped. **Continue** (Enter or →) scrolls a page while there's more below, and goes on at the bottom; a card that fits, most solves, goes on at once. The book opens the journal at the first new entry. Not widened toward the full window: long lines read badly, and a big Mix table solve could still overflow.
- ✅ **Knowledge arrives from play** (built 2026-10-04): each piece's page has a frame per paint it can be given, and a frame fills the first time the player's own machine does that in any run (a failed run too). Shift and Invert have eight (the paint over what it becomes); Mix and Filter have a table of every pair, which fills both ways at once (36 to find). ✅ They keep the full table (designer, 2026-10-05; the proposal of 8 rule frames is dropped): the Mix and Filter table levels (§5.1) weave that table as their cloth, which fills 33 of the 36 pairs in one run. Opposites fills the whole Invert page in one run, Turn the Wheel Shift's. The red pot and Split state their one rule. Saved as `"seen"` (save version 2).
  - ✅ **A piece's page is a level reward** (designer, 2026-10-04): its text unlocks with its word, when the level that brings the piece in is solved, and "New in your journal" announces it. Until then the page shows the critter and whatever frames the player's runs have filled ("watch it work").
- ✅ **Peek** (designer, 2026-10-04: select, then tap): the journal sits at the tray's right end, beside the trash. Tap a piece on the bench (or pick one up from the tray), then tap the journal: it opens over the bench at that piece's page, showing only what the player knows so far; with a tube selected it opens at Loom, an invention at Inventions, nothing at Pieces. It lights while there's something selected to read about. J does the same. The run pauses; closing the journal comes back to the bench as it was. Dropping a dragged piece on it leaves the piece where it was (the journal is no bin). Replaces the long-press idea. Built.
  - ✅ **Selecting shows the way to the journal** (designer, 2026-10-05, closing the R1 right-click / long-press note; built 2026-10-05). A selected piece or tube gets a small book button beside its delete button (which floats above it, below on the top row), drawn the same way; a tap peeks at its page, as the journal by the trash does. A selected pattern card, which has no delete button, shows the book button there alone. So a player who has just selected something sees that its page is one tap away.
- ~~🟡 **Tool introductions** live in the journal: the piece's journal page opens by itself just before the level that introduces it, the critter acting out its frames, and a book ribbon on that level's tag replays it (designer, 2026-10-04).~~ Dropped (designer, 2026-10-05) for **guided levels**, below: the level teaches, the page is its reward.
- ✅ **Guided levels teach** (designer, playtest round 2, 2026-10-05; built 2026-10-05). Every level that brings something new onto the bench is a guided level, and they are the interstitials (no separate beats). New means a piece or a new kind of thing: the pot and the tube (One Pot of Red), Shift, the first earned pot used as a piece, Mix, Split, the pattern card, Invert, Filter, a second card, the first invention used as a piece.
  - **Show, then you do:** the hand (as in One Pot of Red and The Pattern Card today) acts out one step on a faint ghost, with one line for the step ("We only have red now"), and the next step comes once the player has done it. The player builds the machine. A step that takes a piece from the tray lights that piece's slot, which is how a new piece is highlighted.
  - **The guide never blocks:** it reads the bench, skips any step already done, and the player can ignore it. That is the answer for players in a hurry; there is no skip button.
  - **The journal page is the reward:** the guided level's solve unlocks the page of what it brought in, and "New in your journal" announces it (the play-first principle: the journal is reward and reference). The pattern card gets a word and page, unlocking in The Pattern Card (built 2026-10-05: "unlocks in The Sailboat", its page on the Loom tab).
  - Replaying a solved guided level: tapping the title's "?" brings the guide back, as it brings the note back.
  - The step lines follow the level-text rule and the piece names (both still open), written with the level text.
- ✅ The paint card stays (§9.1): a cheat sheet to glance at, where the Paint page is a short article to read. The overlap is on purpose.
- ✅ Every entry exists from the start. Entries not discovered yet stay in the book, visibly locked (an empty frame), so the player can see there's more to find.
- ✅ Every level can add knowledge to it.
- 🟡 No bits or binary here either (§2.1): glyph dots and paint do the explaining. The journal test checks the words never say bits, binary or colors.

## 6. Optimization & leaderboards 🟡

Lessons from Opus Magnum:
- **Multiple metrics:** Cost, Ticks (speed), Area (footprint), plus Edits for repair puzzles. No single solution wins all.
- **Histograms, not just top-10 lists** ("you beat 72% on cost"). Plus **friend leaderboards**.
- **Stars are the kid-friendly face of the optimizer:** ★ solved · ★★ under budget · ★★★ near-optimal. Experts open the same screen and find the histograms.
- ✅ **Prototype stars:** ★ solved · ★★ at or under the level's piece budget · ★★★ at or under the best known count (every best known count is proven minimal by `tools/level_solver.gd`). Metrics: **Pieces** (splits free, inventions at full price) and **Ticks** (until the loom is full). Best Pieces and best Ticks are kept separately.
- ✅ **An invention costs its machine, flattened, minus one** (the invention discount, designer 2026-10-05, §5.1; was the plain sum). Rankings stay honest as long as every player's invention is priced the same way: a leaderboard prices each invention at its proven cheapest, minus one.
- **Deterministic simulation** so every submitted solution can be re-simulated and verified (anti-cheat).
- **GIF export** of solutions (Opus Magnum's viral marketing).

---

## 7. Art direction 🟡

### 7.1 The reserved-colors rule ✅
Color *is* game state, so:
- **Saturated pure hues are only for signals.** World, UI and characters use neutrals: warm paper, wood, soft greys, muted pastels.
- **Light background (paper/canvas), not dark.** White = no paint, black = all paint: a painter's canvas. Dark neon backgrounds hide black signals and invert the intuition.
- **White signal** = empty/outlined droplet; **black signal** = glossy ink drop.

### 7.2 Style ✅ Critter Workshop
Chosen after comparing three animated directions in [mockups/style-studies.html](mockups/style-studies.html) (Critter Workshop, Pixel Workshop, Paper Minimal).

✅ The mockup is the reference for **style** (critters, palette, droplets, tubes, loom), not layout: it flows downward, the game flows left to right (§9.1). It is not kept in sync; screenshots of the game are the layout reference.

- ❌ Futuristic/neon: it looks like *light*, which mixes the opposite way.
- ❌ Pixel Workshop (whole world in pixels) and Paper Minimal (transit-map diagram): not chosen.
- ✅ **Critter Workshop:** **chunky flat toy-like vector art** (rounded shapes, thick ink outlines, soft shadows, bouncy "juicy" animation; think Bloons TD 6 meets a storybook dye works), **drawn procedurally in code**. The **loom's output is pixel art**: pixel art is *what the player makes*, not decoration.
- ✅ **Components are critters:** wooden vats with faces, each with a signature animation (Mix stirs with a spoon, Invert does a flip). Signals stay clean teardrop droplets with glyph dots, riding through glass tubes.
- Reference palette from the mockup: paper `#ECE5D6`, ink `#3A302A`, wood `#C99A69` / `#A97C52`, hoop `#8C7A68`, tag paper `#F8F3E8`, glass `#F6F1E6`. Font: Fredoka (display) + Nunito (UI).
- ❓ A workshop cast of small animals with a master who hands out commissions (story voice), on top of the component critters.
- ⚠️ Known risk: every new component needs a character and animations; faces must stay out of the way on big machines (consider zoomed-out simplification).
- ✅ **Prototype critters** (`ui/draw_kit.gd`): Mix tub stirs with a spoon; Invert tub flips like a pancake; Filter is a fussy, heavy-lidded tub with a sieve in its rim that shakes when it fires, grains of held-back paint (in neutrals) hopping on the rim; the Red pot is a sleepy clay pot that burps; Shift is a hamster in a wheel that clicks one notch per drop; Split is a small plumbing junction; inventions are stickers with their name.
- ✅ **Each critter becomes what its name says** (designer, playtest rounds 1 and 2, decided 2026-10-05; built 2026-10-05: `ui/draw_kit.gd`'s mixing_tub, sieve, flip_pan, hamster and split, all drawn through `K.piece` by their look). Testers found the pieces factory-like: Mix, Invert and Filter are the same tub with a face, told apart by a prop. Each critter gets its own silhouette first (readable at tray size, mid-run and on big machines, §12), then a way of moving that follows from it, in today's wood, paper and ink (the Shift Wheel's rim stays the only signal hue outside paint).

  | Critter | Brief |
  |---|---|
  | **Mixing Tub** (Mix) | Wide, round and jolly; stirs with stubby arms, cheeks puffing as the swirl turns into the new paint |
  | **Sieve** (Filter) | An actual sieve: a round mesh in a wooden hoop on little feet, a fussy face; it shakes and the held-back grains hop |
  | **Flip Pan** (Invert) | A frying pan, think omelettes (designer, 2026-10-05; the name was Flip Tub): a dark iron pan with a wooden handle and a face; the drop sits in it like an omelette, gets tossed (showing its paint mid-air, as today), and lands on its other side, the opposite paint |
  | **Shift Wheel** (Shift) | Kept: a bigger hamster with ears and a real run cycle, the wheel clicking one notch per drop |
  | **Red pot** and earned pots | Kept: already a tool and a character |
  | **Split** | Stays plumbing, on purpose not a critter (it's free): a glass and brass fitting matching the tubes (glassier tubes, playtest notes) |

- ✅ **Glassier tubes** (designer, playtest round 2, 2026-10-05; built 2026-10-05). Today a tube is ink under a cream fill, like the mockup, with no glass cue. Added: a thin bright glint (paper-white, about 2 px, a little transparent) along each tube's upper inner edge, following its curve, and a faint shade (hoop grey, low alpha) along the lower one, so a drop sits *inside* between them. The ink outline stays thick (§7.2), about 12 px instead of 13. Inlets' glass stubs get the same glint and shade, their ring a highlight arc; outlets stay wooden spouts (the critter's), with a small ink collar where the glass slips over. Neutrals only; the selected tube keeps its hoop halo. Tubes sit on the wiring layer, so it costs next to nothing a frame.

  The note's gerbil that shaves the input off black isn't a Flip Pan; "shave B off A" is **Bleach** (`Filter(A, Invert B)`), so the gerbil waits as Bleach's character when it arrives (the inventions' personality pass). How: a branch that redraws for real, with before-and-after screenshots of the tray and a running bench, and `.\make bench` rerun (critter bodies draw every frame).
- 🟡 **Themes and skins: parked, with a clean seam** (designer, 2026-10-05; R1 note). No engine while there is one theme: its shape depends on the second (a palette swap, an artist's sprites, seasonal skins, high contrast for accessibility, the likeliest first), and the critter redraw is about to change every look. ✅ The rule meanwhile, for the redraw and after: every colour drawn has a name in `ui/palette.gd` (built 2026-10-05: no colour literal is left outside it) (today's few literals, the white glints, `#DDD3C1`, two ink-alpha strokes in `draw_kit.gd` and `journal.gd`, move there), and every piece is drawn only through its `look` (`core/pieces.gd`), so a theme later is a palette set and a look table. ✅ **A theme never touches the eight signal colours or their glyph dots**: they are game rules, not skin (§7.1, §8).
- 🟡 **Success splashes, deferred to a later round** (designer, 2026-10-05). The R1 call: confetti becomes colour splashes landing one after another (a wood-and-paper try, `3fb3049`, was reverted). Proposal on the table, not decided: splash the cloth's own paints, each a drop bursting with its glyph dots at the centre, one per paint the cloth uses in journal order, behind the panel, fading after about 2 s; colour that is paint keeps the reserved-hue rule. Confetti stays wood and paper until then.
- 🟡 The Shift wheel is painted red, yellow and blue: the one place outside paint where signal hues appear, because the wheel *is* the rule it applies. Stars, confetti and UI stay in wood and paper tones.
- ✅ Fredoka and Nunito are bundled in `fonts/` (SIL Open Font License).

### 7.3 Progressive depth (the Bloons lesson) ✅
1. Early: drag, drop, watch paint flow. No reading needed.
2. Collecting: the journal (§5.7) fills like a sticker album.
3. After each solve: stars first; histograms unlock later.
4. Late: restoration, constraints, creative loom, commissions.

Kids can stop at chapter 2 + creative loom happily; experts keep digging. Never talk down; near-zero text.

### 7.4 Royalty-free sources
- **Kenney.nl:** CC0 (public domain), commercial OK. Safest.
- **Google Fonts:** SIL Open Font License; one round friendly font (Nunito / Fredoka / Baloo).
- **SFX:** jsfxr / ChipTone (you own the output), Kenney / Freesound CC0.
- **Music:** Incompetech (CC-BY, attribution); commission later.
- **OpenGameArt / itch.io:** check each license; avoid CC-BY-SA / GPL art unless obligations are understood.
- **game-icons.net:** CC BY (attribution required).
- **AI-generated art:** Steam requires store-page disclosure; code-drawn style sidesteps it.

---

## 8. Accessibility ✅

- **Colorblind support is mandatory** (~8% of men). Each primary gets a glyph segment; a color's badge fills the segments present. It also *teaches* the set structure.
- **Touch-first UI:** big targets, drag-and-drop, nothing that depends on hover or right-click (tablets / future mobile).
- Near-zero text; language independence.

---

## 9. Tech 🟡 (prototype built ✅)

- **Engine: Godot 4 from day zero**, with **GDScript** (Godot 4 web export does not support C#).
- **Simulation core = pure GDScript classes** with no scene-node dependencies, unit-tested headless from the command line. Same core re-verifies leaderboard submissions.
- **UI built mostly in code** rather than hand-edited scenes (keeps the AI-assisted loop tight; the human runs it and reports visual issues).
- **Simulation model:** discrete ticks; every component takes 1 tick. Gives the Ticks metric, makes loops/memory natural, avoids race conditions.
- ✅ **Simulation model for the prototype: dataflow with one-drop tubes** (`core/simulator.gd`):
  - every tube holds at most one drop;
  - each tick a piece fires if every input tube holds a drop and every output tube is empty; it takes one drop per input and puts its result in each output tube (a split copies);
  - a red pot fires whenever its tube is empty; a pattern card releases its next color whenever its tube is empty, until it runs out; the loom takes one drop per tick; a catch pot takes one drop per tick and keeps it;
  - all pieces decide from the state at the start of the tick, so the result never depends on processing order (deterministic, tested);
  - solved when the loom is full and every stitch matches; the first wrong stitch stops the run; a tick where nothing can fire means the machine is stuck.
  - 🟡 **Every card must be used** (playtest, 2026-10-04): a card with no tube out of it fails the run before it starts ("Card B has no tube"), and a card still holding paint when the loom is full fails it at the end ("Card B still has paint left"). Pouring a card into a catch pot counts as using it. Star counts were unchanged.
  - 🟡 A port with no tube never fires (paint never spills). A piece with an unconnected output just waits.
  - ✅ **Chain reactions** (built 2026-09-28): a piece may also fire into a full tube if the piece that tube feeds fires this same tick. Firing sets only grow as the check repeats, so the result still doesn't depend on visiting order. Under the strict rule a steady pipeline alternated full/empty and wove one stitch every two ticks (The Flower 388 ticks); with chain reactions it weaves one per tick (195 with the Filter sticker as one piece). Measured on every reference solution: balanced machines halve their ticks, but where a Split feeds paths of different lengths into a Mix the short path's drop still waits (Purple 50 → 39, Black Cat 99 → 76). That remaining slowness is a Pieces-vs-Ticks trade-off (two pots instead of a split), not a bug.
  - Caveat for memory pieces: under this rule a closed loop with every tube full can't turn.
  - An invention is one node that takes one tick and looks up its answer (§5.1).
  - Machines can never loop in this model (a loop waits on itself), so every working machine is a pure function of the cards. Memory pieces will need their own rule.
- 🟡 **Intro** (from playtest notes): a short note at every launch says this is an early build and an update may reset saved progress; one tap anywhere (or Enter) goes on. Jumping straight into a level from the command line skips it.
- 🟡 **Saves** (from playtest notes): the save file carries a version and its layout is documented in `core/progress.gd`. A save from another version, or one that no longer fits the levels (unknown level or invention ids, machines with pieces the level doesn't offer, missing keys), is stale: the launch intro says so instead of its usual note and offers Start fresh or Keep what fits. Either way the old file moves to a `.bak` beside it (never overwriting an older backup); nothing is deleted. ✅ (2026-10-05, built 2026-10-05) Keep what fits also forgets a solved invention level whose invention it dropped, so the level reads unsolved and earns it again. No migration code while the game is in development. ✅ **Save compatibility where feasible** (designer, 2026-10-05): testers carry their progress from build to build instead of starting unlocked (§5.1, cheat codes), so a change that can keep old saves valid should (new fields with defaults, ids kept stable); where a break is unavoidable, the version bump and the stale check above still handle it. Save version 3 since the chapter plan (2026-10-05): the campaign changed under every save. Save version 4 since the round 2 campaign (built 2026-10-05), the one save break of round 2.
- ✅ **Local profiles** (designer, playtest round 1 note, shaped 2026-10-05; built 2026-10-05: `core/profiles.gd`, `ui/profile_picker.gd`; the local leaderboard is still later). A profile is a save slot: a critter badge (tapped from the critters, no reading needed) and an optional name that defaults to the critter's, so a child makes one without typing and a parent can type "andrew". One save file each (`chromaton_save_<id>.json`); **the existing save becomes the first profile untouched** (save compatibility, nothing to migrate). Settings stay per device (keys and speed belong to the keyboard and screen). With one profile nothing is asked; with two or more the launch intro adds "Who's playing?" (a row of badges, a tap goes on), and the level select has a profile chip in its top-right corner to switch or add one. Later, a **local leaderboard** on the Scores tab: each level's best Pieces and Ticks per profile on the device, side by side, the best starred.
  - ✅ **This is the anonymous, local, offline mode** (designer, 2026-10-05). In a wider player service (say an online Steam release), local profiles stay what they are: no account, nothing leaves the device, nothing online, which also keeps them clear of the children's-data rules (§10). Accounts, online leaderboards and sharing would come on top of it as a separate layer, never in place of it.
- ✅ **Live on itch.io** (checked 2026-10-05): https://ibourlakos.itch.io/chromaton, channel `web`, version 2026.10.05-2c1a7df (build #2066936, the four-chapter campaign), released with `.\make release itch`; the page plays in the browser at 1280×800. What follows from a live build:
  - **Saves now matter for real:** testers have progress on it. The campaign rebuild bumps the save version, so they meet the stale-save intro, and "Keep what fits" carries the solved levels whose ids survive: stable ids are the save compatibility (no migration code).
  - **The store page dates with the rebuild:** its cover and four screenshots (`build/itch/`, 2026-10-03: The Flower, Mix Without Mix, Harbour Cat, Orange Sun) show the old campaign, and The Flower goes to Lost Levels; retake them after the rebuild (`.\make shot`). Retaken 2026-10-05 into `build/itch/` for the designer to upload: the cover (The Black Queen's bench under the title), Harbour Cat mid-run, The Black Queen, The Mixing Table's guide and the journal's Sieve page; the old ones moved to `build/itch/old/`.
  - **Before the next push**, settle whether this channel is a development release (the cheat engine, §5.1, ❓).
  - **Round 2 releases** (`.\make release itch`, one per work package): WP1, the new campaign, 2026.10.05-d0c2aca-dirty (the content of d0c2aca; "dirty" only because the export generated an untracked `tools/functions.gd.uid`, now tracked). WP2, the bench, 2026.10.05-6d6b2d4. WP3, teaching, 2026.10.05-a7539cb. WP4, art and players, 2026.10.05-90f2467.
- **Distribution:** web export on itch.io for friends → Steam later (GodotSteam; Steam Direct fee $100; Steamworks leaderboards) → mobile later.
- ✅ **Prototype v0.1 is built** (Godot 4.7, GDScript only, Compatibility renderer, no threads or plugins). See CLAUDE.md for layout and commands.

### 9.1 Workbench UI (prototype) 🟡 (flow direction ✅)

- 1280×800 design canvas that scales to the window. Top bar: back, the Options gear, the level's number and two title phrases (§5.1, built 2026-10-05), Undo · Reset · Step back · Step · Run/Pause, and three speeds (0.55 s, 0.22 s and 0.05 s per tick, now 0.8 s, 0.22 s and 30 a second, below; Normal is the default, and the chosen speed carries across levels, kept in the settings file with the keys).
  - ✅ **Wider speeds** (designer, playtest round 2, 2026-10-05; built 2026-10-05): still three buttons (a fourth would cost the top bar about 50 px), now **slow 0.8 s** a tick (one drop to follow and talk through), **normal 0.22 s** (unchanged, the default), **fast 30 ticks a second** on any machine. Fast keeps time by the clock, not the frame: when a frame is longer than a tick, the bench steps several ticks and draws the last (drops jump rather than glide). The extra frame each tick waits today (a tick's animation ends one frame, the next step starts the next, so fast ran at about 15 a second at 60 fps, 10 at 30) goes, so every speed runs at its rate. Only the Third Paint then takes about 6.5 s, chapters 3–4 2–3 s, chapter 2 under 2 s. One draw a frame as now (rerun `.\make bench` when built); Step back replays, so nothing piles up in memory; the saved speed (0–2) stays valid.
- ✅ **Paint flows left to right** (the mockup flows downward; it is the style reference only, see §7.2). Machines grow deeper as puzzles get harder, and the screen is landscape, so depth gets the long axis: the bench is 11 cells deep × 7 wide (one piece per cell), pattern cards sit on its left edge as fixed pieces covering the first two cells of their rows (the rest of the edge takes pieces), and the loom stands on the right with the design card above it and the pieces bar and Ticks below. 🟡 The pieces bar (playtest: a "Pieces 3" count read as a limit) fills one wooden slot per piece placed, with room for two past the two-star count; a marker after the three-star count carries ★★★ on its left, one after the two-star count ★★ on its right, and they light while the bench is within. Ticks show as the clock icon and a number. The parts tray is a shelf along the bottom (room for about 9 pieces) with the journal (peek, §5.7) and the trash at its right end; pieces a level holds back sit in it locked (§5.1).
- Pieces take paint in on their left side through short glass pipes and send it out on their right through wooden spouts; with two ports, the first is on top. Cards release paint from their right end, next color nearest the spout. Tubes are drawn as glass curves between ports; crossings are allowed (no routing rules yet). The cloth still weaves top to bottom (§4).
- Gestures: drag from the tray to place; drag a piece to move it, or back onto the tray (trash) to remove it; drag from an output to an input (or the other way) to lay a tube; drag a tube's end off an input to re-route or drop it; tap a tube or a placed piece to select it, then tap its delete button. Any edit rewinds the run. Undo covers every edit.
- ✅ **Pattern cards: selectable, movable along the left edge, never removable** (designer, playtest round 2, 2026-10-05; built 2026-10-05). A tap selects a card (the usual outline), so peek opens the pattern card's page (§5.7); no delete button, and Delete or Backspace leaves it. A drag slides it up or down the left edge only, to any row whose first two cells are free; dropped on another card the two swap; dropped on a piece, off the edge or on the trash it slides back with a small wiggle. A move is an edit (undo, rewinds the run). Left edge only so paint still enters on the left and tubes never run backwards; the point is tidy tubes. A card keeps its letter wherever it sits, and the letter, not the row, orders an invention's input ports. Its row is saved with the bench; a stored bench without one falls back to today's rows (`CARD_ROWS`), so no save version bump.
- ✅ **Tray slots show their cost** (designer, playtest round 2, 2026-10-05; built 2026-10-05). A small chip in each slot's top-right corner: the cost bar's piece icon and the number ("▮ 1"), "(free)" after Split's 0; the key cap stays top left and the name on the bottom line, so cost and name never collide. An invention's chip replaces "3 pieces" (the sticker carries its name); each pot in the fan wears one instead of "· 1"; the folded pot slot has none (one number there would read as every pot's price). On a locked slot it fades under the veil with the name. It is the player's own price (since the discount it can sit above the cheapest); no "could be cheaper" mark, since improvements come forward, never back (§5.1): later levels re-earn pots cheaper and "New in your journal" says so (§5.7).
- ✅ **A card looks back after a wrong stitch** (designer, playtest round 1 note, decided 2026-10-05; built 2026-10-05). Today a card shows what it still holds, so after a wrong stitch the drops that fed it are gone. Once a run stops on a wrong stitch, every card's window shows again the drops it showed at the start (its 4 to 10, §5.1), on a faint paper tint so it reads as a look back, and the drop at the wrong stitch's place is ringed in ink on every card (stitch *i* comes from each card's *i*-th drop). With the wrong-stitch bubble it tells the whole failure at a glance. If the wrong stitch is past the shown drops (only a machine over the ★★ budget, given the decode check), the window shows as many drops ending at the ringed one, with a small gap mark at its start. It goes when the run stops being a failure: Reset, any edit, Step back, Run. "Card B has no tube" and "still has paint left" keep today's look.
- ✅ **Pieces snap to half cells** (designer, playtest round 1 note, decided 2026-10-05; built 2026-10-05). Today a dragged piece jumps a whole 84 × 80 cell. A piece snaps every half cell (42 × 40), 21 × 13 places, but still covers a whole cell's footprint and never overlaps another; so it can sit between two rows, as a Mixing Tub fed by two branches wants to. Cards keep whole rows (and slide a row at a time), the loom's inlet the middle row. The Options grid keeps its whole-cell lines with faint dots at the half points. The machine gains `"grid": 2`; a stored bench without it is whole cells, doubled on load, so saves stay valid with no version bump. Not finer (fiddly on touch, untidy machines); a two-input piece's ports, 17 px off its centre, still bend a tube slightly, and the art isn't changed for that.
- ✅ **The loom's inlet sits on the bench's middle row** (designer, playtest round 2, 2026-10-05; built 2026-10-05). Today it is at the loom's middle (y 350), 14 px above row 3's centre (y 364), so a machine laid straight along the middle row kinks into the loom. The loom moves down 14 px so the inlet is at row 3's centre; the tallest cloth (200 px) then ends at y 464, clear of the stars and pieces bar. Its left-right place still follows the cloth's width. (The R1 note on a card socket nearer the tray is superseded by movable cards, above.)
- Tubes can end anywhere on the loom. A drop travels along its tube during the tick it was made, then waits at the far end; a woven drop flies into its cell.
- Level 1 has a wordless hand hint; Run glows once the loom is fed. (✅ 2026-10-05: grows into guided levels, §5.7.) Step back replays the run to one tick earlier (the simulation is deterministic), for tracing a machine tick by tick in both directions.
- 🟡 **Key layer** (from playtest notes): every key only does what a tap already does, so touch loses nothing. Small key caps sit on the controls they press; they show by default unless the device has a touch screen, touching hides them, pressing a key brings them back, and ? (or H), a "? Hide key labels" chip on the level select, or Options turns them on or off for good. Players call them key labels. Workbench defaults: Space run/pause, S or → step, A or ← step back, R reset, Z undo (step and undo repeat when held), − and + speed, Tab cycles slow → normal → fast → slow, P puts the paint card up or away, J opens the journal at what is selected (peek, §5.7), **1–9 pick up that tray piece** (as does a tap on it; dragging still works; a locked piece's key only wiggles its lock): it follows the pointer and only a click on a free cell puts it down, a click anywhere else, a right-click or Esc drops it back (the right-click is only a shortcut for what a tap already does). **Delete or Backspace removes only what is selected** (tap a tube or a piece to select it), never what is merely under the pointer. Esc drops a carried piece, then clears the selection, then puts the paint card away, then leaves the level. After weaving: Enter or → next, R weave again, Esc levels (not Space, which may still be held from the run). Level select: ← → (or A D) turn pages, Enter plays the first open unsolved level (its tag wears the cap), B the journal, O Options. Journal: 1–7 a tab, Tab the next tab, ← → (or A D) turn a page or step through pieces and words, Enter opens a word's page, B, J or Esc closes it. After the success panel, Enter or → (or Esc) goes on from "New in your journal". Keys go by the letter printed on the key (the digit row also by position, for AZERTY).
  - ✅ **Key changes** (designer, playtest round 2, 2026-10-05; built 2026-10-05). **The level select's journal is J, with B kept as its second key** (`[J, B]`: the cap shows J as everywhere else; B habits still work). **Space is every Continue's second key, Enter staying first:** Next on the success panel, Continue on "New in your journal" (it scrolls first, §5.7), the level select's next unsolved level, the launch intro. The success panel takes Space only once Space has been released since it opened (one still held from the run doesn't count) and it has been up about half a second (a pause pressed as the loom fills doesn't count); then Space is Enter. The other Continues take it at once (none opens mid-run). This replaces "not Space" after weaving, above. Web: the canvas takes keys once clicked; in browser fullscreen the browser keeps Esc.
- 🟡 **Options**: a gear on the level select opens it, on every build. Show a grid on the bench (faint cell lines; off by default) is always there. Only where a keyboard is likely (desktop and web, not phone builds) does it also list every action by screen (Everywhere, Workbench, After weaving, Level select, Journal), in three columns with the switches in the third, with two key slots each (tray pieces one each): tap a slot, press the new key; Esc cancels, tapping it again clears it. A key moves off any action it would clash with (same screen, or Everywhere) and that slot blinks. Plus Show key caps and Put every key back. Every setting (keys, key caps, grid, run speed, the paint card) is saved at once in `user://chromaton_settings.json`, apart from progress.
  - ✅ **Options inside a level** (designer, playtest round 2, 2026-10-05; built 2026-10-05). A small gear (46 px, the speed buttons' size) right of Back in the workbench's top bar, the title moved over to make room. It opens Options over the bench as peek opens the journal: the run pauses, a carried piece drops back, and Back (or Esc) closes it to the bench as it was; nothing is rebuilt. O opens it on the workbench too (free there). Not while the success panel or "New in your journal" is up. Kept out of the right-hand run controls so a reach for Undo never lands on it.
  - ✅ **Back is always the upper-leftmost control** (designer, 2026-10-05), on every screen and overlay that has one; anything else in that corner (the gear) sits to its right.
- 🟡 **Paint card** (playtest, 2026-10-04: testers asked why red, yellow and blue make black, and how the darker paints are made). A Paints button in the top bar, left of Undo, hangs a card of the eight paints over the bench (`ui/paint_card.gd`), laid out as a mixing triangle in the glyph dots' places: red on top, yellow lower right, blue lower left; each mix on the edge between its two paints, black (all three) in the middle, white (no paint) apart. Each drop carries its glyph dots and its name. Two lessons come without text: opposites face each other across black along dashed lines (Invert jumps across), and Shift turns the triangle one corner clockwise. Not modal: the bench works around it, and it clears the middle row, where a single card's machine sits. A tap on the card, the button, P or Back puts it away; it stays up from level to level. ✅ Named the **paint card** (2026-10-04). It stays a card, a cheat sheet, even though the journal's Paint page (§5.7) tells the same rules as a short article to read.
  - ✅ **The colour rules stay in play** (designer, playtest round 2, 2026-10-05): R1 testers asked "why r+g+b = black?" (thinking in screen light: red, green, blue). No beat before level 1 or before black; the paint card has worked, and the guided levels' step lines (§5.7) carry the rule where it first appears.
  - ✅ **Working pieces out on the card** (built 2026-10-05): small ink arrows around the triangle (red → yellow → blue, the mixes turning with them) so Shift reads off the card too; each piece's journal page gets a line on using the card for it (Mix: where the paints meet; Invert: straight across black; Shift: one arrow on), unlocking with the page. ✅ Its text (2026-10-05) is in levels/level-text.md: "On the paint card, a mix sits between its two paints: red and yellow meet at orange." and likewise for the Sieve, the Flip Pan and the Shift Wheel; none for the red pot and Split.
- ✅ The workbench draws its still parts (top bar, tray, bench and grid, design card) on a layer behind the rest that redraws only when they change (a piece picked up, the trash lit, key labels toggled), so tray pieces hold still; only pieces on the bench are alive. Measured on an Intel UHD 620 laptop (desktop build, vsync off): 80 ms a frame down to 36 ms with this and cheaper tube joints.
- 🟡 **Pre-rendered critters: parked** (designer, 2026-10-05; R1 note). `.\make bench` on the UHD 620 laptop (headless, 60 frames a second, 2026-10-05): 3.0 ms a frame on average running at fast, 1.5 ms dragging; worst frames 15.6 ms (The Harbour) and 15.4 ms (Same Paint), under the 16.7 ms budget. Critters are the biggest layer (3.5–4.9 ms on 8–10-piece machines, 60–75% of the frame there), but the frame fits, so baking would buy nothing and cost game-driven animation, crisp art at any size and the quick screenshot loop. ✅ **Two checks on the critter redraw branch** (§7.2): rerun `.\make bench`, and bake each critter's still parts (the middle path: still parts into a texture once, moving bits as transforms, extending the layers) only if a big machine's worst frame passes about 12 ms; and play a windowed web build on that laptop, Only the Third Paint at fast, for stutter the headless bench can't see (GPU fill).
- Invert shows its input color during the first half of its flip (Invert is its own inverse, so the input is known from the output).

---

## 10. Audience & platforms

- Puzzle fans (programmers, Zachtronics players) **and** kids (~8+), families.
- ⚠️ Online features for under-13s carry legal obligations (COPPA in the US, GDPR child rules in the EU). Steam accounts are 13+, so this matters mainly for mobile later. Build leaderboards/sharing so they can be disabled. Local profiles (§9) are the almost-anonymous, local, offline mode that always works without them.

---

## 11. Roadmap

1. **Lock the algebra:** ✅ completeness verified by script ([docs/algebra-report.md](docs/algebra-report.md)); ✅ middle kit with Filter as a starting critter (§2.5).
2. ✅ ~~Pick the art style~~: **Critter Workshop** (see §7.2). Still to confirm: world vocabulary (§3).
3. ✅ ~~Specify ~10 campaign levels~~: fifteen prototype levels, now 33 in four chapters (§5.1, the chapter plan of 2026-10-05): the paint box, pattern cards at the seaside, inventing what you know, and its looking-glass twin.
4. ✅ ~~Godot vertical slice~~: **prototype v0.1** with workbench, loom, 15 levels, stars, Pieces and Ticks, inventions, saved progress.
5. Play it, show friends, decide the 🟡 items below; then a web build (needs `levels/*.json` in the export filter) on itch.io; iterate.
6. ✅ **The round 2 build: four work packages, one itch.io release each** (designer, 2026-10-05). Everything playtest round 2 decided as "not built", in an order where each package rests only on the ones before it. The one save break comes first; every later package keeps saves valid (new fields with defaults).

   **WP1, The new campaign, in the players' words** (the save break; release 1)
   - The invention discount, for inventions and pots (§5.1, §6).
   - Locks and loans: a level waits for an invention it can't do without (the solver proves which), its locked tag ("Earn the Third Paint in 25. The Pawn."), force unlock lends every invention and pot (§5.1).
   - What a card shows decodes the level: 4 to 10 drops per level, `.\make cards` picks the shortest, `.\make solve` fails a level that breaks it, the bench's cards fit 10 (§5.1).
   - Smudges dropped (§5.1).
   - The new chapters 1 and 2 with their ids, pots open from Blue on, Purple's held pots, the Mix and Sieve tables, two inventions a chapter (Same Paint invented in The Black Queen), Flip Side and The Harbour moved to Lost Levels: kept, out of the campaign, not shown yet (how it's found is ❓) (§5.1).
   - Two names: player words in every player-facing text (Mixing Tub, Sieve, Flip Pan, Shift Wheel, Split, red pot, workshop, Extreme Mix), the lexicon's Player word and Gameplay sections switched, `.\make words` (§3).
   - The level-text rule in the UI: two title phrases in the top bar with the sticker mark, goal and hint in the hint panel (scrolling if needed), the "?" glowing after a failed run, primary titles on tags, Cloths and Scores, references as "2. The Yellow Pot" (§5.1). Options' gear beside Back, which is redone with the top bar (§9.1).
   - The text of [levels/level-text.md](levels/level-text.md) into `levels/*.json` (steps wait for WP3), the lexicon's "unlocks in" lines, the pattern card's word and page.
   - Save version 4; Keep what fits forgets an invention level whose invention it dropped (§9).

   ✅ **WP1 built 2026-10-05** (branch `wp1-campaign`), released as 2026.10.05-d0c2aca-dirty (§9). Calls the build made where the design left a detail open, for the designer to review:
   - 🟡 **A level holds back the pot it earns** (goal session, 2026-10-05). Otherwise A Cheaper Green Pot, A Cheaper Orange Pot and A Cheaper Black Pot could be woven by placing the very pot they re-earn (a tie with the intended machine). It shows in the fan, locked, as `hold_pots` does.
   - 🟡 **A pot costs its cheapest price so far** (goal session, 2026-10-05). Star thresholds, the solver and the card maker count, at each level, only what the levels before it earn, at the cheapest price up to there; a pot re-earned cheaper later costs its old price until then. This is how §5.1's chapter 1 prices work out (Green 2 = `Mix(Yellow, Blue)`, Black 3 = `Mix(Orange, Blue)` with Orange still 2); force unlock lends at the overall cheapest.
   - 🟡 **New ★★ budgets keep each level's old margin over ★★★** (goal session, 2026-10-05): Blue 3, Orange 4, Purple 5, Green 4, Black 5, A Cheaper Green Pot 4, the cheaper Orange and Purple 3, A Cheaper Black Pot 4, The White Pot 5, The Orange Sun 3; The Rook and The Black Rook 2, The Knight and The Black Knight 4, The Bishop, The Queen and The Black Bishop 5, The King and The Black King 6, the tables 2. The Queen's is 5 (her hint's route is 4).
   - 🟡 **The Fish (Wash Out) gets two white bubbles** rising from its mouth (stitches 3 and 10; goal session, 2026-10-05). Its first ten stitches were all blue water, so a machine that ignores the cards and weaves blue (the blue pot) passed any ten drops, and `Filter(A, Blue)` and `Filter(Blue, Invert B)` can't both fail on one white stitch; no card could decode it. The picture is the designed remedy (§5.1); the designer may prefer other bubbles.
   - 🟡 **The Flip Pan's word unlocks in A Cheaper Green Pot** (goal session, 2026-10-05), not "The Green Pot" as the rename list says: The Green Pot (`green_mix`) has no Flip Pan, and the word follows the `green` id, the level that brings the Flip Pan in. The Sieve's word stays in Sandy Crab until the guided levels (WP3) move each piece's page to the level that brings it in.
   - 🟡 **Old saves keep their old invention prices** (goal session, 2026-10-05): no repricing on load (no migration code); a re-solve makes them cheaper as usual. An invention's name always follows its level, so an old "Contrast" reads Extreme Mix.
   - 🟡 **Lost Levels** are an entry marked `"lost": true` in `levels/index.json`; a save keeps their records (goal session, 2026-10-05).
   - 🟡 **Force unlock's loans never reach the save**: a saved bench leaves out lent inventions and their tubes, so the save fits again without the flag (goal session, 2026-10-05).
   - 🟡 **Cards with more than six drops** draw them smaller and closer, and a card's letter tab moved onto its top edge so ten fit across (goal session, 2026-10-05).
   - 🟡 **The top bar** shows the level's number (in stamp brown) before the two phrases; the hint panel flies home into the "?" (goal session, 2026-10-05). O opens Options on the workshop as its own action, Options in the Workshop keys.
   - 🟡 **Journal article rows tightened** (80 px at least, 12 px apart) so the Loom page fits the pattern card until articles scroll (WP3) (goal session, 2026-10-05).

   **WP2, The bench** (release 2): half-cell snapping; pattern cards selectable and sliding along the left edge; the book button beside a selection's delete button; the loom's inlet on the middle row; tray cost chips; the card's look-back after a wrong stitch; wider speeds; the key changes (§9.1). Before WP3 because the guide points at bench positions.

   ✅ **WP2 built 2026-10-05** (branch `wp2-bench`), released as 2026.10.05-6d6b2d4 (§9). Calls the build made:
   - 🟡 **Continue keys are Enter, then Space** (goal session, 2026-10-05): an action has two key slots, so → no longer goes on from the success panel or "New in your journal" (§5.7's "Enter or →" yields to the key change; → still works where it's an action of its own).
   - 🟡 **The settings file carries a key version** (goal session, 2026-10-05): keys saved before this change of defaults are dropped (the speed, grid, key labels and paint card stay), so the new keys reach every player; "Put every key back" did the same by hand.
   - 🟡 **The book button sits right of the delete button** (50 px over), drawn the same way with the J cap; on a card it takes the delete button's place (goal session, 2026-10-05).
   - 🟡 **A card slides only up and down**: it follows the pointer's height along the left edge; "off the edge" is a drop outside the bench (goal session, 2026-10-05).
   - 🟡 **Fast catches up at most 8 ticks in one long frame** (goal session, 2026-10-05), so a stall in the browser never runs the machine away.
   - `.\make bench` on this build machine (not the UHD 620 laptop): 5.9 ms a frame on average running at fast, 2.9 ms dragging, worst frames 12 to 51 ms on chapters 3 and 4 and noisy. The build before WP1, measured the same way on the same machine, averaged 4.3 ms running: fast now really runs 30 ticks a second (about twice its old rate), and the loom and the cards redraw once a tick. The windowed web check on the UHD 620 laptop decides (§9.1).

   **WP3, Teaching** (release 3): guided levels with their step lines, on all ten (§5.7); rebuilt-critter journal pages; "New in your journal" with icons, its order, scrolling, and the cheaper, new-chapter and opens entries; journal articles that fit their text and scroll; the paint card's Shift arrows and each piece page's paint-card line (§5.7, §9.1).

   ✅ **WP3 built 2026-10-05** (branch `wp3-teaching`), released as 2026.10.05-a7539cb (§9). Calls the build made:
   - 🟡 **The guide's steps live in the level files** as `steps` (a line and what it asks, against the level's reference machine: place a piece, lay a tube, open the pot fan, run; `ui/guide.gd`). A step with nothing to do (Green's "Green sits across from red on the paint card.", The Sailboat's and The Mixing Table's first lines, The Rook's "on the shelf") leads into the next step's line, the two shown together; Purple's "Only red today." and Green's "Tube the red pot into it." also place the red pot they need (goal session, 2026-10-05).
   - 🟡 **The step's line sits on a paper slip above where the hand acts** (below near the bench's top, under the top bar for Run); a step taking a piece shows its ghost faintly on its reference cell. The guide hides while the player drags, carries a piece, runs, or has an overlay up (goal session, 2026-10-05).
   - 🟡 **The guided level's page is its reward**, so the Sieve's word moved from Sandy Crab to The Sieve Table (goal session, 2026-10-05).
   - 🟡 **"Made of"** heads the rebuilt-critter rows: each names its level ("28. The Bishop") and shows the pieces of the player's own machine there with how many (goal session, 2026-10-05).
   - 🟡 **New in your journal's rows**: a new chapter reads "A new chapter: Invent What You Know" over its first level ("25. The Pawn"), an invention's openings are one sentence ("The Third Paint opens 26. The Rook and 27. The Knight."), a cheaper invention "Orange pot: cheaper, 2 → 1"; a new invention earned for the first time stays on the success panel. Its Continue keys are Enter then Space (WP2) (goal session, 2026-10-05).
   - 🟡 **Articles**: rows at least 80 px, 18 px apart; the scroll keys and the wheel move 60 px, the chip most of a page (goal session, 2026-10-05). Options lists the Journal keys under its round buttons, so every key fits.
   - 🟡 **The paint card's arrows**: one per edge, outside the triangle between a corner and its mix (goal session, 2026-10-05). Each piece page's paint-card line sits beside a small paint card, below the frames (or right of Mix's and the Sieve's tables).

   **WP4, Art and players** (release 4): the critter redraw (Flip Pan included) and glassier tubes under the clean-seam rule (§7.2), with `.\make bench` and the bake rule (§9.1); local profiles (§9); new store screenshots in `build/itch/` for the designer to upload.

   ✅ **WP4 built 2026-10-05** (branch `wp4-art-profiles`), released as 2026.10.05-90f2467 (§9). Calls the build made:
   - 🟡 **The critters' new materials**: the Flip Pan's iron (`IRON`, `IRON_DK`, `IRON_LT`) and Split's brass (`BRASS`, `BRASS_DK`), both muted so nothing reads as paint; the Flip Pan's handle points down to the lower left, clear of its inlet; the Mixing Tub's stubby arms hold its spoon's handle above the paint; the Sieve's face sits on its hoop's band (goal session, 2026-10-05).
   - 🟡 **No baking** (goal session, 2026-10-05). `.\make bench` on this build machine after the redraw: 4.5 ms a frame on average running at fast (5.9 ms before it, with WP2), 2.4 ms dragging; big machines' worst frames 15 to 27 ms, critters 6 to 9 ms of their frames. The build from before WP1 also passed 12 ms on its worst frames here (14 to 21 ms), so on this noisy desktop the 12 ms line can't tell; the redraw didn't raise the average. The bake rule is for the UHD 620 laptop: the windowed web check there (Only the Third Paint at fast) decides.
   - 🟡 **Profiles**: the badges are the five critters (Mixing Tub, Shift Wheel, red pot, Sieve, Flip Pan); a name is at most 16 letters. The roster lives in `user://chromaton_profiles.json`. The profile chip sits under the journal button in the level select's top-right corner, clear of the title's drops; it opens a screen (Back upper left) to switch or add. "Who's playing?" takes Enter (or Space) for the one who played last (goal session, 2026-10-05).

   Not in it: the success splashes, a themes engine, pre-rendering (unless the bench asks), the cheat engine, the lab, Lost Levels' way in.

---

## 12. Open questions ❓

- Final world vocabulary (§3): leaning dye works + loom.
- Workshop cast / story voice on top of the component critters (§7.2).
- How critters simplify when zoomed out on large machines.
- Which arities Mix/Filter support (2 only, or n?). The primitive set is decided (§2.5).
- ~~Is the Red source the only biased primitive?~~ Yes: the red pot is the only basic pot; the others are earned inventions (§5.1).
- Grid-based placement: square grid? Thread routing rules (crossings, bridges)?
- Title: "Chromaton" conflict search.

Raised by the prototype (see the 🟡 markers above):
- ~~Should re-solving an invention level replace the invention or keep the cheapest?~~ The cheapest (2026-10-05, §5.1).
- Should players name their inventions?
- Glyph dots on woven stitches, or keep the tapestry clean?
- Are the level-8 budget (the Filter route earns ★★, the De Morgan route ★★★) and the other thresholds the right pressure?
