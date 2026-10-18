# Chromaton — Design Document

> Working title (Steam name conflict check pending).
> This file is the **single source of truth** for the design. Ideas explored elsewhere (claude.ai Project, chats) come back here.
> Current decisions only. What they replaced, with dates and reasons (old tables, build notes, the release log), is in [docs/design-history.md](docs/design-history.md).

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
- Built (2026-09-28): the Filter critter and piece. It arrives guided in The Sieve Table (level 20), and from there every tray offers the whole kit, except where a level rebuilds a critter or offers only an invention and Split (chapters 3 and 4, §5.1).
- The pieces are one data table (`core/pieces.gd`, each drawn through its `look`), so a new piece is a line there plus its critter.

| Piece (player word) | In → out | Behaviour | Critter |
|---|---|---|---|
| **Red pot** (red pot) | 0 → 1 | Red paint, forever | Sleepy clay pot that burps a drop |
| **Mix** (Mixing Tub) | 2 → 1 | Every primary in either input | Wide jolly tub that stirs |
| **Filter** (Sieve) | 2 → 1 | Only the primaries both inputs share | A sieve on little feet that shakes |
| **Invert** (Flip Pan) | 1 → 1 | The opposite paint | A frying pan that tosses the drop |
| **Shift** (Shift Wheel) | 1 → 1 | Every primary one step round: red → yellow → blue → red | Hamster in a red, yellow and blue wheel |
| **Split** | 1 → n | Copies the paint; free | Glass and brass plumbing, not a critter |
| **Catch pot** | 1 → 0 | Swallows every drop | ✅ **Out of the trays for now** (2026-09-28): players couldn't tell what it was for (tubes show their drops, Step back traces a run). It comes back with a real job: the output bin for multi-output and buffer puzzles (§5.4), or stray paint once routing can skip stitches |

**Early inventions and their machine sizes in the game's kit** (report §6; proven cheapest by search unless marked ≤): Yellow pot 2 · Third Color 2 · Bleach 2 · Black pot 3 · Contrast 4 · Consensus 4 · Prism 6 · Any Red? 6 · Same Color? ≤ 8 · Three-way Switch ≤ 21 · Three-way Selector ≤ 23. Without Filter: Filter 4 · Bleach 3 · Contrast 7. Since the invention discount (§5.1) the earned invention costs one less than its machine.

What the player invents and keeps: **recipes** (stateless) and, later, **machines** (stateful).

The lean kit this replaced (three critters and a pot) and its reasoning are in [docs/design-history.md](docs/design-history.md).

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

Working vocabulary until decided: *vat* (component), *tube* (wire), *braid* (bus: parallel tubes), *recipe*, *machine*, *journal* (§5.7; its Pieces tab holds the player's inventions too).

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

  The names follow the critters as redrawn (§7.2). **Workbench becomes the workshop** for players (where the critters, the machines and the player work together; it's also the art style's name); `ui/workbench.gd` keeps its name. Hints and lexicon Gameplay texts switched when the rename was built (2026-10-05). 🟡 Later: the inventions' names and personalities.
- ✅ **Critter, tray and workbench are player words**, each with its lexicon entry.

Buses: ✅ parallel = a **braid** of N threads; serial = a **sequence of colors over time** on one thread.

---

## 4. The Loom 🟡

The central visual and the late-campaign goal. Historical anchor: the **Jacquard loom (1804)** used punched cards and inspired Babbage; the campaign quietly retraces that history.

| Loom | Chromaton |
|---|---|
| **Warp** (vertical threads) | The cloth's columns |
| **Weft** (one horizontal pass) | A row of stitches, laid one stitch per tick (serial weaving, below) |
| **Pattern card** | The input: a picture the machine reads drop by drop |
| **Cloth** | The output: the picture the machine weaves, row by row |

- Every run weaves a cloth; a level's target is a cloth picture (pixel art: the one place pixels belong, §7.2).
- **Chapter payoff:** each level weaves one cloth; a chapter's cloths join into a **quilt** (✅ the word, 2026-10-04; built as the quilt beside each chapter's cloths in the journal, §5.7). "Tapestry" is kept for the finale.
- Finale: a **programmable loom** (the CPU equivalent) that weaves a tapestry from a pattern card (Chromaton 2's territory in the current proposal, CHROMATON-2.md).
- ✅ **Serial weaving.** One output thread; the loom takes one drop per tick and weaves the next stitch, row by row, left to right. The first wrong stitch stops the run and is marked with a pulsing ring and cross. 🟡 A braid of W threads weaving a whole row per tick could come later, faster.
- ✅ **The shuttle** threads along the row being woven, standing in the gap before the next slot, never on it, so the target's ghost stays in sight (designer, playtest R4, 2026-10-08; built 2026-10-08), and slides on after each stitch (in from the left edge for a new row), trailing the weft it lays. The cloth shows weft threads along each row, crossing the warp. **Shuttle** is in the lexicon and the journal's Words (Loom tab).
- 🟡 Unwoven cells are sunken slots, darker than the cloth, so an empty slot never reads as a woven white stitch; a small faint chip of the target's paint sits in each (white as a pale chip). The target picture is also pinned beside the loom as a small design card (84 px tall since playtest R3, 2026-10-06).
- 🟡 Woven stitches carry no glyph dots (as in the mockup); the wrong-stitch bubble compares the two drops with dots.

✅ **The pattern card is a picture, the loom cloth's counterpart** (Path B: designer, 2026-10-06; built and merged 2026-10-06).
- *Narrative:* the level's machine turns the pattern pictures into a result cloth. It points at an image algebra (pictures in, an operator, a picture out) without naming it; player-facing text stays in paint and thread. The simulation already is that: stitch *i* depends only on each card's *i*-th drop.
- *Look:* the card is a picture on the loom's grid, in the loom's raster order, so card cell *i* lines up with cloth cell *i*. The whole picture shows, glyphs and all; drops already read fade under a paper tint. The card has its own small shuttle, standing in the gap before its next drop and sliding on as the card releases one.
- *Failed run:* the card stays as it was, the read trail faded and the drop that wove the wrong stitch ringed in ink on every card, so the failure reads at a glance with the wrong-stitch bubble.
- *Sizes* (designer, 2026-10-06): 8 columns by 6 rows (4:3, like the loom cloth) is the default for cards and cloths; a card's picture runs from 4 columns by 1 row to 12 by 9 (`Level.CARD_COLS_MIN/MAX`, `CARD_ROWS_MIN/MAX`, checked by the levels test; The Harbour's 16 by 12 is beyond it, a Lost Level). The cell is 16 px, so the body follows the picture (156 px wide at least, 220 by 168 at the largest); a picture beyond the bounds shrinks its cell to fit. A card sits on rows 1 to 5 of the bench's left edge, its out port on its right edge; pieces keep off the cells under it. Its book button floats just above the body.
- *Why:* chapter 6's Appliqué (the cards are the player's earlier cloths) and later picture chapters need cards that read as pictures.
- *Cost* (`.\make bench`): the trail draws as plain muted discs while running, glyphs only on the frozen wrong-stitch view (about 1.3 ms a frame for the paints layer).
- `card_shows` is no longer anything the player sees: it is the decode depth (§5.1).
- The strip it replaced (Path A) and the look-back that went with it are in [docs/design-history.md](docs/design-history.md).

---

## 5. Modes

### 5.1 Campaign: Invention ✅
Solve a level → earn the construct (a pot or an invention) → use it in later levels. A level shows its target cloth and its pattern cards (§4); the player works out the rule from them.

✅ **The campaign today** (42 levels in four chapters: the designer's chapter plan and playtest round 2, built 2026-10-05; chapters 3 and 4 grown to nine levels, playtest R3, 2026-10-06; reordered so the little boards centre their quilts, playtest R4, 2026-10-08). Order and chapters live in `levels/index.json`, each level in `levels/<id>.json` (format at the top of `core/level.gd`). Every level's reference solution solves it at exactly its ★★★ count, and every ★★★ count is proven minimal by `tools/level_solver.gd` ([docs/level-report.md](docs/level-report.md), which also lists each level's decode depth, what it waits for and what its ★★★ counts on). In the tables, **G** marks a guided level (§5.7), **waits** a level that stays locked until the player owns its invention, and the machine is a cheapest one, as the solver writes it.

**Chapter 1, The Paint Box** (12 levels): no cards; each level weaves one row of 8 stitches of one paint, so the rows stack into the chapter's quilt, and earns that paint's pot. The first half has no Flip Pan; the second brings it in by making the pots cheaper.

| # | Level | Teaches | Earns | ★★ | ★★★ | Machine |
|---|---|---|---|---|---|---|
| 1 | One Pot of Red | G: the pot and a tube | | 1 | 1 | `Red` |
| 2 | The Yellow Pot | G: Shift Wheel | Yellow 1 | 3 | 2 | `Shift(Red)` |
| 3 | The Blue Pot | G: an earned pot as a piece | Blue 1 | 3 | 2 | `Shift(Yellow)` |
| 4 | The Orange Pot | G: Mixing Tub | Orange 2 | 4 | 3 | `Mix(Red, Yellow)` |
| 5 | The Purple Pot | G: Split (every pot held back) | Purple 3 | 5 | 4 | `Mix(Red, Shift(Shift(Red)))` |
| 6 | The Green Pot | yellow and blue | Green 2 | 4 | 3 | `Mix(Yellow, Shift(Yellow))` |
| 7 | The Black Pot | every paint together is black | Black 3 | 5 | 4 | `Mix(Red, Green)` |
| 8 | A Cheaper Green Pot | G: Flip Pan | Green 1 | 4 | 2 | `Invert(Red)` |
| 9 | A Cheaper Orange Pot | a mix is a primary's opposite | Orange 1 | 3 | 2 | `Invert(Blue)` |
| 10 | A Cheaper Purple Pot | | Purple 1 | 3 | 2 | `Invert(Yellow)` |
| 11 | A Cheaper Black Pot | a paint and its opposite | Black 2 | 4 | 3 | `Mix(Red, Invert(Red))` |
| 12 | The White Pot | white is black flipped | White 2 | 5 | 3 | `Invert(Black)` |

**Chapter 2, Pattern Cards** (12 levels, quilt 4 across): seaside pictures, 8×6.

| # | Level · machine phrase | Teaches | Cards | ★★ | ★★★ | Machine |
|---|---|---|---|---|---|---|
| 13 | The Sailboat · Straight from the Card | G: the pattern card | 1 | – | 0 | `A` |
| 14 | The Wheel Swatch · Turn the Wheel | Shift's swatch | 1 | 2 | 1 | `Shift(A)` |
| 15 | The Opposites Swatch · Every Paint Flipped | Invert's swatch | 1 | 2 | 1 | `Invert(A)` |
| 16 | The Orange Sun | a card and a pot | 1 | 3 | 2 | `Mix(A, Yellow)` |
| 17 | The Parrot · Each Paint and the Next | the fork: Split a card | 1 | 3 | 2 | `Mix(A, Shift(A))` |
| 18 | The Mixing Table · Every Pair Mixed | G: a second card; Mix's table | 2 | 2 | 1 | `Mix(A, B)` |
| 19 | The Lighthouse · Two Cards Mixed | two cards mixed | 2 | 2 | 1 | `Mix(A, B)` |
| 20 | The Sieve Table · What Every Pair Shares | G: Sieve; its table | 2 | 2 | 1 | `Filter(A, B)` |
| 21 | Sandy Crab · Keep the Red | the Sieve with a pot as a mask | 1 | 3 | 2 | `Filter(A, Red)` |
| 22 | The Rock Pool · Where They Meet | two cards sieved | 2 | 2 | 1 | `Filter(A, B)` |
| 23 | The Fish · One Has Something the Other Hasn't | Bleach's job, early: `Filter(A, Invert B)` | 2 | 3 | 2 | `Filter(A, Invert(B))` |
| 24 | The Harbour Cat · Convert to Black and White | the closer: a fork three ways | 1 | 6 | 4 | `Mix(Shift(Shift(A)), Mix(A, Shift(A)))` |

**Chapter 3, Invent What You Know** (9 levels, quilt 3 across): the six white chess pieces on orange and blue squares down the sides, and the game's three chess themes down the middle column (the clock, the board, the trophy), all 8×8 in the same paints. The player invents the Third Paint, rebuilds the critters from it, then invents Extreme Mix.

| # | Level · machine phrase | Does | Cards | ★★ | ★★★ | Machine |
|---|---|---|---|---|---|---|
| 25 | The Pawn · Third Paint | **earns the Third Paint**, `Invert(Mix(A, B))` | 2 | 3 | 2 | `Invert(Mix(A, B))` |
| 26 | The Chess Clock · What Neither Has | G: showcase, the invention placed as one piece; black ink wipes the cloth white; waits | 2 | 2 | 1 | `ThirdPaint(A, B)` |
| 27 | The Rook · A Flip Pan, Rebuilt | Invert from Third Paints; waits | 1 | 2 | 1 | `ThirdPaint(A, A)` |
| 28 | The Queen · Extreme Mix | **earns Extreme Mix** (Contrast) | 2 | 5 | 3 | `ThirdPaint(Filter(A, B), ThirdPaint(A, B))` |
| 29 | The Chessboard · Stripes Crossed | showcase: orange and blue row stripes crossed with white and black column stripes; waits | 2 | 3 | 2 | `ExtremeMix(A, B)` |
| 30 | The Knight · A Mixing Tub, Rebuilt | Mix from Third Paints; waits | 2 | 4 | 2 | `ThirdPaint(ThirdPaint(A, B), ThirdPaint(A, B))` |
| 31 | The Bishop · A Sieve, Rebuilt | Filter, with the Sieve locked | 2 | 5 | 3 | `ThirdPaint(Invert(A), Invert(B))` |
| 32 | The Trophy · Only the Blue Flipped | Extreme Mix with the blue pot | 1 | 5 | 3 | `ExtremeMix(A, Blue)` |
| 33 | The King · Same Paint | capstone, Third Paints only; waits | 2 | 6 | 4 | four Third Paints |

**Chapter 4, The Looking Glass** (9 levels, quilt 3 across): each level is the mirror twin (De Morgan dual) of chapter 3's in the same slot, its picture that level's photo negative (black chess pieces, the squares swapped, the gems flipped), so the two quilts hang as a pair. Every Mix becomes a Filter, and black becomes white.

| # | Level · machine phrase | Does | Cards | ★★ | ★★★ | Machine |
|---|---|---|---|---|---|---|
| 34 | The Black Pawn · Missing From Either | **earns Missing From Either**, `Invert(Filter(A, B))` | 2 | 3 | 2 | `Invert(Filter(A, B))` |
| 35 | The Black Chess Clock · What They Don't Both Have | showcase (not guided); bare paper turns the cloth black; waits | 2 | 2 | 1 | `MissingFromEither(A, B)` |
| 36 | The Black Rook · A Flip Pan, Rebuilt | waits | 1 | 2 | 1 | `MissingFromEither(A, A)` |
| 37 | The Black Queen · Same Paint | **earns Same Paint** | 2 | 6 | 4 | `Mix(Filter(A, B), Invert(Mix(A, B)))` |
| 38 | The Looking-Glass Board · Stripes Agreeing | showcase, the chessboard's two cards; waits | 2 | 4 | 3 | `SamePaint(A, B)` |
| 39 | The Black Knight · A Sieve, Rebuilt | waits | 2 | 4 | 2 | two Missing From Eithers |
| 40 | The Black Bishop · A Mixing Tub, Rebuilt | Mix, with the Mixing Tub locked | 2 | 5 | 3 | `MissingFromEither(Invert(A), Invert(B))` |
| 41 | The Black Trophy · Only the Blue Flipped | Same Paint with the orange pot | 1 | 6 | 4 | (also 4 with Missing From Either) |
| 42 | The Black King · Extreme Mix | capstone, Missing From Eithers only; waits | 2 | 6 | 4 | four Missing From Eithers |

🟡 Watch with testers (playtest round 2): Harbour Cat as chapter 2's closer, and the capstones The King and The Black King. If the capstones still wall testers after their hints, the pair moves out together (moving one breaks chapter 4's mirror). The names, cloths and order of the R3 levels wait for the designer's look (playtest notes).

🟡 **Six pieces and three chess themes** (designer, 2026-10-17; built and merged 2026-10-17, on itch since 2026.10.18-0027698; to play for in the playtest notes, package A). A chess quilt is the six pieces (Pawn, Rook, Queen, Knight, Bishop, King) and three themes about the game that aren't pieces. The themes take the quilt's middle column, slots 2, 5 and 8, and tell the game top to bottom: **the clock** starts it, **the board** is played, **the trophy** ends it. Every theme cloth is 8×8 in the pieces' paints: orange and blue squares, the figure in white, one gem; the twins in chapter 4 have the squares swapped, the figure in black and the gem flipped, as the black pieces do. Ids follow the machines and stay (`two_pawns`, `little_board`, `the_crown` and their twins), so saves keep their records.
- **The Chess Clock** (replaces Two Pawns, which was The Pawn's machine again on cards of noise; playtest R4). Still the Third Paint's guided showcase, one piece, but with an idea of its own: black wipes the cloth clean. Card A is the board by night (every square flipped, the dials left bare), card B the clock in black ink with green dials. Where a card has every paint, neither card is missing anything, so the clock comes out white; where card B is bare, the Third Paint flips the board back. The cards are fixed (no `card_rule`); the clock's buttons sit on the first row, so every cheap wrong machine fails within 4 stitches. Its twin, **The Black Chess Clock**, flips both cards: where a card is bare paper, the cards can't both have anything, so Missing From Either turns the clock black.
- **The Chessboard** (was The Little Board, 4×4 and black and white): a real board of 64 one-stitch squares, finer than the 2×2 squares behind the pieces. Card A is rows of orange and blue, card B columns of white and black; Extreme Mix keeps the row's paint under white and flips it under black, which weaves the orange and blue checker, with two red corner gems. Its twin, **The Looking-Glass Board** (Through the Looking-Glass is a chess game), uses the same two cards, and Same Paint weaves every square swapped, with green corners.
- **The Trophy** (replaces The Crown): the same machine, Extreme Mix with the blue pot. The card is the trophy by night, a classic black and white board with the cup painted in blue and its gem in purple; flipping only the blue turns it into the orange and blue board with a white cup and a red gem. Its twin, **The Black Trophy**, is Same Paint with the orange pot, as before.

✅ **Chapters 3 and 4 stay at nine levels** (designer, 2026-10-17). Only a grid with an odd number of patches each way has a centre, and up to 12 levels only 3×3 does, so growing to 12 would cost the centred board. Recreational ideas go elsewhere (the playtest notes keep them).

✅ **Campaign rules** (designer, playtest round 2, 2026-10-05, unless dated):
- **A chapter holds together:** one world and one thing to learn about the algebra, a quilt that reads as one piece, **at most 12 levels**, and a multiple of 3 (with its `quilt_across`, the quilt fills its grid). A chapter that grows too big is split; one short of a multiple of 3 gets a level made for it, or pushes one on to the next chapter.
- **At most two new inventions a chapter** (pots aside; earning one again doesn't count). A level may do an invention's job before the level that invents it, as The Fish does Bleach's; Bleach and its twin `Mix(A, Invert B)` wait for a chapter with room.
- **A piece comes in three steps:** the level that invents it (if it's an invention), the guided level that introduces it (§5.7), then card practice. A critter's first practice is its **swatch** (one run shows it on every paint and fills its journal page: The Wheel Swatch, The Opposites Swatch) or, for Mix and the Sieve, its **table level** (card B the eight paints in journal order on every row, card A one paint a row: the 8×6 cloth is the piece's table, 33 of its 36 pairs). Then the first real use (Sandy Crab: the Sieve as a mask; The Parrot: Split as a fork).
- **An invention is shown off before it is rebuilt with** (playtest R3, 2026-10-06): each earned invention is followed by a showcase level that places it as one piece.
- **Several cards are advanced:** inside a chapter, one-card levels come before two-card ones; a second card arrives in a guided level; three cards only from chapter 6 on (its guided Stencil level).
- **Levels aren't removed** unless they make no sense at all; one that leaves goes to **Lost Levels** (below).
- **The capstones block nothing:** a chapter's last level is a challenge; the next chapter opens from the level before it.
- Ids are stable names (`green`, `black_cat`), not numbers: the number shown is the level's place in `index.json`, so levels move or join without breaking saves. A level keeps its id when renamed or moved, and an id follows the machine, not the slot (`green` is A Cheaper Green Pot, `third_color` The Pawn, `the_flower` The Harbour).

✅ **Unlocking, locks and loans:**
- Solving a level opens the next two, so one hard level never walls off the rest.
- **A level waits for an invention it can't do without** (built 2026-10-05): its tray can't weave the cloth without it (`waits_for`, proven by the solver), so it stays locked until the player owns it, on top of solve-two-ahead. Its locked tag says where to earn it ("Earn the Third Paint in 25. The Pawn.").
- 🟡 **Quest marks on the level select** (designer, 2026-10-18; built on the branch `objectives`), as an RPG marks its quests, over an open, unsolved level's tag: **"!"** while it isn't started (its stored bench has no piece and no tube; opening it and leaving the bench empty keeps the mark), a quest to pick up, on a wooden roundel that bobs gently; **"?"** once it's started, a quest taken and not done, on a quieter paper roundel that holds still. A solved level has none. Wood, paper and ink, not an RPG's gold, which is a reserved paint (`Progress.in_progress`). On the bench the title's "?" stays as it is: the quest is taken, and "?" also reads as help, which the panel's hint is.
- **Force unlock lends the tools.** Unlocking every level (`.\make unlock`, a developer's and tester's cheat) lends every invention and pot the levels offer, at its reference price, never saved; earning one for real replaces the loan.
- **No all-unlocked build; cheat codes instead** (designer, 2026-10-05). Nothing is unlocked by default in any build; testers unlock levels with cheat codes, in development releases only, a cheat lending what its level needs. Testers keep progress from build to build through save compatibility (§9). ❓ The cheat engine itself (the codes, entering them touch-first, what marks a development release) is for later.

✅ **Prices, pots and inventions:**
- **The invention discount** (designer, 2026-10-05): an invention costs the pieces of the machine that made it, inventions inside at their own price, **minus one**, never less than 1. Inventing pays on price, not only on Ticks, and it compounds. Pots are inventions and follow the same rule.
- **The cheaper machine wins:** every invention keeps the cheapest machine the player has made it with (a tie takes the newest), so a re-solve never makes it dearer and going back for ★★★ makes it cheaper. Its journal slot names the level whose machine was kept. Improvements come forward, never back: later levels re-earn pots cheaper (chapter 1's second half), and "New in your journal" says so.
- **Star counts assume the cheapest prices so far:** at each level, only what the levels before it earn, at the cheapest price up to there (a pot re-earned cheaper later costs its old price until then); the solver and the card maker search with the same prices. A player who earned one at ★★ may not reach ★★★ where it is used: the hint panel says so before the run and the success panel after it, naming the invention and where it gets cheaper (§9.1). What each level's ★★★ counts on is proven by the solver and written into the level file as `star_needs` (19 levels today; the level report lists them).
- **Every color pot but red is an invention** (designer, 2026-09-28): an invention with no inputs (check `paint:<letter>`), drawn as the clay pot in its own paint with a swatch tag of glyph dots (the red pot too).
- **Pots as pieces:** from The Blue Pot on, every pot the player has earned is open in every tray that offers the red pot. A level can hold pots back (`hold_pots`, shown in the fan, locked): The Purple Pot holds them all, so splitting the red (4) beats two pots (5) and Split earns its star. A level holds back the pot it earns (WP1 call, 2026-10-05), so the cheaper-pot levels can't be woven by placing the very pot they re-earn. A tray that offers only an invention and Split offers no pots.
- **The pots share one tray slot:** the red pot's slot, labelled Pots, with two earned pots peeking out behind it. A tap fans the owned pots out on a paper card above the shelf, in paint order, each with its paint and price; tap one to pick it up, or drag it out (touch-first, no hover, no dropdown). Dragging the slot itself places the red pot; number keys pick from an open fan; Back or a tap elsewhere folds it.
- **An invention, once accepted, is one piece that takes one tick** (built 2026-09-28): the simulator stores its answer for every combination of input paints and looks it up, so drops never vanish into it. Its price still counts everything inside; Ticks improve, which rewards inventing. Before it is accepted, the machine runs on every combination of input paints (64 for two inputs); one that only fits the level's cards is refused with a short note. Its cards become its input ports (in card order, by letter), the loom its output; it is drawn as a sticker with its name (the player's name, §3). The name comes from the level; players don't name inventions (❓ §12).
- The campaign's inventions: the seven earned pots, the Third Paint, Extreme Mix (Contrast), Missing From Either and Same Paint. Each invention but the pots has a page among the pieces in the journal; the pots stand on the paint shelf, on the red pot's page (§5.7).

✅ **Each level offers an explicit list** of pieces and inventions, so tools the player has earned never trample a puzzle meant to go without them (an invention also has to be owned to appear; earned pots are the exception above). **Locked pieces** (built 2026-10-04): the tray shows what the level offers plus every piece an earlier level offered, locked: the tray as it was when the campaign got there, worked out from `levels/index.json` (`Level._lay_trays`), not the save. Pieces sit in the order the campaign first offers them (pot, Shift, Mix, Split, Invert, Filter), so no slot or number key ever moves. A locked slot keeps its tag with the critter faded under a paper veil and a lock where the key cap sits; a tap, drag or key places nothing and the lock wiggles. The Bishop locks the Sieve; The Black Bishop the Mixing Tub; levels that offer only an invention and Split lock every critter and the pot.

✅ **Level text** (designer, 2026-10-05; built 2026-10-05). The game teaches its rules and world through play, so level text guides the player; never bits, binary or bytes.
- **The title says what you do, the hint says how.** Two phrases side by side in the top bar, after the level's number: what the cloth is, then what the machine is ("The Queen · Extreme Mix"). On an invention level the machine phrase is the invention's name, with a small sticker mark; in the paint box it's the pot (The Yellow Pot); elsewhere a short phrase in the tray's words for what the machine does ("Keep the Red"), never how it's built, so it never gives away the cheapest answer. Where any phrase would, the cloth alone (The Orange Sun). Small words stay lowercase ("Each Paint and the Next").
- 🟡 **Level objectives** (playtest R3; designer 2026-10-18; built 2026-10-18 on the branch `objectives`, its goal clauses and ★★★ nudges drafts for the designer's markup). The hint panel shows the level as objectives, a row each with its stars: **★ the goal**, with the hint under it; **★★ "A cost of 5 or less."**; **★★★ "A cost of 3 or less."** (one row where the two counts are equal; "A cost of 0: no pieces at all." on The Sailboat). A row's stars fill once the player has them, so reopening the "?" on a solved level shows the progress. The success panel shows the same rows, filled as they stand after the run, without the hint (`Level.objectives`, `LevelNote.lay_out`). A goal says what the level earns: "Weave the pawn, and invent the Third Paint.", "Weave a yellow cloth, and earn your yellow pot."; the cheaper-pot levels, whose ★★ machine doesn't make the pot cheaper, "Weave a green cloth. Three stars make your green pot cheaper." The hints are unchanged.
  - **The hint ladder:** the ★★★ row's note is the next rung, shown once the rung below is reached. Where a pot or invention costs the player too much for ★★★, it is the price line (§9.1), from the start. Otherwise, on a level whose hint describes a dearer machine than ★★★ (24 The Harbour Cat and 28 The Queen, checked against the solver; every other hint's route costs its ★★★ count), a **star_hint** nudges toward the cheaper one, shown only once the player has ★★ and only on the hint panel, never the success panel, so the ★★★ find stays the player's until they look. A first ★★ there makes the "?" glow once, as a failed run does.
- **The hint panel** (the level note) holds the objectives above. It pops up as an unsolved level opens and flies home into the title's "?" on any tap or key; tapping the "?" brings it back, and on a solved guided level brings the guide back too. After a failed run (or a first ★★ that opens a ★★★ nudge) the "?" glows softly until the hint is opened or the player runs again.
- **The hint:** a sentence about the world, its story or its paint, then the how, naming pieces as the tray does ("The sand washes out. Sieve the card down to its red."). A paint-rule sentence counts as the world sentence where the cloth has little story (the paint box, the chess boards). The swatches and tables skip the story: their first sentence says what the cloth will show, and their machine phrase may name the piece.
- **A level's name is its primary title:** the cloth phrase, or in the paint box the machine phrase, all unique. Tags, Cloths and Scores show it; the whole title only the top bar and the hint panel. **Text refers to a level by number and name: "2. The Yellow Pot"** (locked tags, "New in your journal", hints). 🟡 The R3 note asks for "2.The Yellow Pot" with no space, in a font made for level titles (playtest notes).
- Titles, goals and hints live in `levels/*.json`. [levels/level-text.md](levels/level-text.md) keeps every level's decided text with its notes, the guided step lines, and the text outside the level files (locked tags, "New in your journal" lines, the paint-card line on each piece page); it is tracked but not exported.

✅ **Pattern cards decode their level** (designer, playtest round 2, 2026-10-05; built 2026-10-05). Cards are derived from each target picture by `tools/make_cards.gd` from the level's `card_rule` (seeded by level id, so reruns match; the rules are listed at the top of the tool). The picture shows whole (§4), but the rule must be readable early: **every wrong machine within the ★★ budget weaves a wrong stitch within the level's decode depth** (`card_shows`, 4 to 10 stitches, the shortest that works unless the level asks for more with `card_shows_min`). The card maker rerolls those first stitches among the rule's options to make every cheap wrong machine fail there; fixed cards (the Mix and Sieve tables) only get their count. `.\make solve` fails a level that breaks it. ❓ Whether to rename `card_shows` and keep its range now that no window shows it (playtest notes).
- No level starts with a blank first row; where a rule has no choices, the picture carries paint from the first stitch (The Fish got two white bubbles for this, WP1 call).
- **Every card must be used** (§9): a card with no tube fails the run before it starts, one still holding paint when the loom is full fails it at the end.

✅ **Chapters 5 and 6 have no memory and no state** (designer, 2026-10-06). They use the pieces and rules that exist, so every machine in them is still a plain function of its cards (§9) and the solver's proofs hold. Memory is chapter 9 (the sequel, if the game splits: CHROMATON-2.md). Both follow chapters 3 and 4's shape: 9 levels, quilt 3 across, two new inventions, each followed by a showcase. The level lists, with prices by hand (unproven until the solver runs), are in PLAYTEST-NOTES.md, "Chapters 5 and 6, planned".
- 🟡 **Chapter 5, Asking Questions** (quilt: Shadow theatre, every cloth a silhouette, since a question answers black or white). Earns **Any Paint?** and its looking-glass twin **Is It Black?** (4 pieces each in the game's kit, pot price 3), then Is It White?, Any Red?, Contains?, Same Color? (which joins chapter 4's Same Paint to Is It Black?, 6 pieces by hand) and a capstone.
- 🟡 **Chapter 6, Choosing** (quilt: Appliqué, the cards are the player's earlier cloths). Earns **Stencil** (guided: it brings the third card) and **Consensus** (The Harbour returns from Lost Levels), with Gate, Choose, a stencil cut from a card's silhouette, and a capstone appliqué.
- ❓ Which of the two comes first: the designer's priority line says Choosing; the plan, The Harbour's Consensus and the Appliqué quilt have Questions first, and Gate and Choose get cheaper with Any Paint? in hand (recommended: Questions first).

🟡 **Lost Levels** (designer, 2026-10-05): levels that left the campaign, kept and playable from the command line, shown nowhere yet: an entry marked `"lost": true` in `levels/index.json`, whose records a save keeps. **Flip Side** (The Beach Flags · Every Mix Flipped: the same puzzle as Opposites), **The Harbour** (`the_flower`, 16×12, three cards, the two-of-three rule `Filter(Mix(C, B), Mix(A, Filter(C, B)))`, until chapter 6 earns it as Consensus) and **The Big Board** (`chessboard`, 12×9, the largest card size, `Filter(A, Invert B)`; made up 2026-10-06; renamed 2026-10-17 when chapter 3's 8×8 board took the name The Chessboard). ❓ How they're found and laid out: the Chromaton 1 proposal (playtest notes) makes them the post-credits shelf.

The history of this section (the nine-level paint box, the 33- and 36-level campaigns, the old tables, smudges and noisy cards, the playtest findings that shaped it) is in [docs/design-history.md](docs/design-history.md).

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
- ✅ **One book with tabs: Paint · Loom · Pieces · Cloths · Scores · Words** (2026-10-04; the Inventions tab joined Pieces, playtest R4, 2026-10-18; keys 1 to 6 in tab order). ✅ **Built (2026-10-04)** as `ui/journal.gd`, replacing the Pattern Book screen: opened from the level select's book button (J) or by peek over the bench (below), paper tabs along the top, a back button. Rewards and achievements: later, a vibe for now.
  - **Paint** and **Loom** are short articles: each word the lexicon gives that tab, with a small picture and its Gameplay text. Paint also holds the paint card's triangle; Loom has loom, stitch, tick, tube, thread, pattern card and shuttle.
    - ✅ **Articles fit their text and scroll** (designer, playtest round 2, 2026-10-05; built 2026-10-05). Each row is as tall as its picture or its text, whichever is taller (at least 80 px, 18 px apart); an article longer than the page scrolls (drag, the wheel, ↑ or W and ↓ or S) with a "more below" chip at the bottom that scrolls on when tapped, as "New in your journal" does. ← → still turn pages and tabs; peek on a tube opens Loom scrolled to Tube.
  - **Pieces** holds every piece and every invention but the pots (designer, playtest R4; built and merged 2026-10-18, on itch since 2026.10.18-0027698; to play for in the playtest notes, package C). ✅ **One list, by name, as on Words:** the pieces met and the inventions made stand in lexical order by the player's word, so a new one takes its place among them; the rest follow as locks, in the order the campaign brings them, so a lock's place gives nothing away. A **light bulb** in an entry's corner marks an invention (not a star: stars are the score). The list runs past its page and scrolls as the articles do (drag, the wheel, ↑ or W and ↓ or S, the "more below" chip); ← → step through it and it follows.
    - A **piece's page**: the critter, its words, its frames (below) and a line on working it out on the paint card. A piece the player hasn't met (no open level offers it) is a lock. ✅ A critter that chapters 3 and 4 rebuild gets **"Made of"** rows (built 2026-10-05): one per level that rebuilds it ("31. The Bishop"), with the pieces of the player's own machine there and how many, or an empty frame until it's woven; no sticker, since the critter is already in the tray. ✅ The Mixing Tub and the Sieve get three **case rows** beside their tables, once the page is read (the table shows what, the rows say why); Shift Wheel and Flip Pan are one rule each and need none.
    - ✅ An **invention's page** (designer, playtest R4, 2026-10-08): its sticker and price, its rule in one sentence, then 4 to 6 **case rows**, `drop + drop → drop` with a short reason, one row per kind of pair rather than every pair (Extreme Mix: Red + Yellow → Orange, they share nothing; Orange + Red → Yellow, the shared red washes out; the same paint twice → White; with White unchanged; with Black its opposite; with Blue its blue flipped). Below them **"Made of"**: the level whose machine was kept and that machine's pieces, the player's own build. The page opens when the invention is made: the every-paint check has proved its answers, so nothing waits to be found by play. Rows that give a later level's idea away stay (The Crown's and The Little Board's in Extreme Mix's); a player who reads the journal and works a level out from it has earned that. Until it's made, a lock naming the level that invents it.
    - ✅ **Case rows live in the lexicon** (2026-10-18): a term's **Cases** section (`- Orange + Red → Yellow: the red they share washes out.`), written into `data/words.json` by `.\make words`; the journal test checks each row's answer against the piece or invention and its words for bits and binary. Each invention has its own lexicon term (Contrast, Third Paint, Missing From Either, Same Paint), tagged gameplay, so it is also a word on Words, unlocking in the level that invents it, its rule as its text, its sticker as its picture.
    - ✅ **The paint shelf** is on the red pot's page: eight pots in journal order, each with its price; the red pot always there, unearned pots dashed outlines with the first level that earns them. The pots share one tray slot, so they share one page.
  - **Cloths** is a picture gallery, one chapter per page: a slot per level, the cloth hung from a rod once woven, an empty frame the cloth's shape until then. A solved level's cloth is its target picture, so it needs no save data.
  - ✅ **Quilts** (designer, 2026-10-04): a chapter's cloths join into a **quilt**, hung beside them on the Cloths tab. Patches fill in as cloths are woven; the paint box's threads stack, other chapters sew each cloth into an equal patch. "Tapestry" stays free for the finale. ✅ (chapter plan, 2026-10-05; built) Each chapter after the paint box pins its patches across (`quilt_across` in `levels/index.json`: chapter 2 four, chapters 3 and 4 three) and has a multiple of that many levels, so the quilt fills its grid; patches take the cloths' shape when they share one (4:3 in chapter 2), and the gallery beside it uses the same grid.
  - **Scores** is the scoreboard, one chapter per page: stars, best Cost (§9.1) and best Ticks per level (already saved), with the campaign's stars and cloths woven at the top. Best only, no run history. Cloths and Scores stay separate tabs: one is a gallery, the other a scoreboard.
  - **Words** is the player's lexicon: every term tagged *gameplay* in [docs/lexicon/](docs/lexicon/lexicon.md), as tiles of a picture and the word; tapping one shows its Gameplay text and a button to its fuller page, if it has one. ✅ The words found so far stand in lexical order, by the player's word, so a new one takes its place among them; the ones still to find follow, in unlock order (playtest R3, 2026-10-06; built 2026-10-06). The R3 report that Stitch was missing from Words didn't reproduce (it unlocks with One Pot of Red and shows on Words and Loom); in unlock order it was simply hard to find.
- ✅ **A word unlocks when its level is solved** (designer, 2026-10-04). Each lexicon term's "Journal:" line names the level; `.\make words` turns the gameplay terms into `data/words.json`, which the game ships (a test fails if the two drift apart). Locked words stay visible as empty frames naming their level. The paint card's word unlocks in One Pot of Red (the Paints button is there from the start).
- ✅ **"New in your journal"** (designer, 2026-10-04: a stepping stone into the rest of the campaign). After the success panel, whichever way it's left (next, levels, weave again), a card shows what the solve brought: the level's new words (with their text when there are up to three, as tiles past that) and the frames the player's runs filled on piece pages since the last card. Continue (Enter or Space) goes on; the book opens the journal at the first new entry. A new invention earned for the first time stays on the success panel instead.
  - ✅ (designer, 2026-10-05; built 2026-10-05) It also shows **updated** entries: an invention made cheaper, with its icon and both prices ("Orange pot: cheaper, 2 → 1"), only when the price drops. And it announces new levels where the level select wouldn't make them plain: a new chapter opening ("A new chapter: Invent What You Know", over its first level's tag) and the levels an invention opens, in one sentence ("The Third Paint opens 26. The Chess Clock and 27. The Rook."). The ordinary next two inside a chapter stay off it.
  - ✅ **How the card grows, with icons** (designer, playtest round 2, 2026-10-05; built 2026-10-05). **One row kind** for every entry: an icon on the left as the thing looks in the game (a critter, an invention's sticker, a pot in its own paint, a level's numbered tag for levels opened, the chapter's first tag for a new chapter, a word's picture), a title and one line; a word keeps its text when there are up to three, a frame row its critter, name and drops. **Most important first:** new pages and words (the solve's reward), what opened (chapter, levels an invention opens), cheaper (both prices), frames found; what falls below the fold matters least. **760 px wide**, growing to fit up to about 600 px tall, then the list **scrolls** (drag, or the wheel); while more is below, a "3 more below" chip at the bottom scrolls to it when tapped. **Continue** scrolls a page while there's more below, and goes on at the bottom; a card that fits, most solves, goes on at once. Not widened toward the full window: long lines read badly, and a big Mix table solve could still overflow.
- ✅ **Knowledge arrives from play** (built 2026-10-04): each piece's page has a frame per paint it can be given, and a frame fills the first time the player's own machine does that in any run (a failed run too). Shift and Invert have eight (the paint over what it becomes); Mix and Filter have a table of every pair, which fills both ways at once (36 to find). ✅ They keep the full table (designer, 2026-10-05; the proposal of 8 rule frames is dropped): the Mix and Filter table levels (§5.1) weave that table as their cloth, which fills 33 of the 36 pairs in one run. The Opposites Swatch fills the whole Invert page in one run, The Wheel Swatch Shift's. The red pot and Split state their one rule. Saved as `"seen"` (save version 2).
  - ✅ **A piece's page is a level reward** (designer, 2026-10-04): its text unlocks with its word, when the level that brings the piece in is solved, and "New in your journal" announces it. Until then the page shows the critter and whatever frames the player's runs have filled ("watch it work").
- ✅ **Peek** (designer, 2026-10-04: select, then tap): the journal sits at the tray's right end, beside the trash. Tap a piece on the bench (or pick one up from the tray), then tap the journal: it opens over the bench at that piece's page, showing only what the player knows so far; with a tube selected it opens at Loom, an invention at its page, a pot at the red pot's page (the paint shelf), nothing at Pieces. It lights while there's something selected to read about. J does the same. The run pauses; closing the journal comes back to the bench as it was. Dropping a dragged piece on it leaves the piece where it was (the journal is no bin). Replaces the long-press idea. Built.
  - ✅ **Selecting shows the way to the journal** (designer, 2026-10-05, closing the R1 right-click / long-press note; built 2026-10-05). A selected piece or tube gets a small book button (with the J cap) and its delete button, drawn the same way. 🟡 Since playtest R3 (2026-10-06, built 2026-10-06) they sit in a cross around the selection, the book north and the delete button south, far enough apart that a tap can't miss one for the other; where the bench ends, that arm turns east. A tap on the book peeks at its page, as the journal by the trash does. A selected pattern card, which has no delete button, shows the book button alone, clear of its body. So a player who has just selected something sees that its page is one tap away.
- ✅ **Guided levels teach** (designer, playtest round 2, 2026-10-05; built 2026-10-05; they replaced journal pages that opened by themselves before a level). Every level that brings something new onto the bench is a guided level, and they are the interstitials (no separate beats). New means a piece or a new kind of thing: the pot and the tube (One Pot of Red), Shift, the first earned pot used as a piece, Mix, Split, the pattern card, Invert, Filter, a second card, the first invention used as a piece. Ten levels today: 1, 2, 3, 4, 5, 8, 13, 18, 20 and 26 (The Chess Clock, was Two Pawns, since 2026-10-06; The Rook before).
  - **Show, then you do:** the hand acts out one step on a faint ghost of the piece on its reference cell, with one line for the step ("We only have red now") on a paper slip above where the hand acts, and the next step comes once the player has done it. The player builds the machine. A step that takes a piece from the tray lights that piece's slot, which is how a new piece is highlighted. The guide hides while the player drags, carries a piece, runs or has an overlay up.
  - **The steps live in the level files** as `steps` (a line and what it asks, against the level's reference machine: place a piece, lay a tube, open the pot fan, run; `ui/guide.gd`). A step with nothing to do leads into the next one's line, the two shown together.
  - **The guide never blocks:** it reads the bench, skips any step already done, and the player can ignore it. That is the answer for players in a hurry; there is no skip button.
  - **The journal page is the reward:** the guided level's solve unlocks the page of what it brought in, and "New in your journal" announces it (the play-first principle: the journal is reward and reference). The pattern card gets a word and page, unlocking in The Pattern Card (built 2026-10-05: "unlocks in The Sailboat", its page on the Loom tab).
  - Replaying a solved guided level: tapping the title's "?" brings the guide back, as it brings the note back.
- ✅ The paint card stays (§9.1): a cheat sheet to glance at, where the Paint page is a short article to read. The overlap is on purpose.
- ✅ Every entry exists from the start. Entries not discovered yet stay in the book, visibly locked (an empty frame), so the player can see there's more to find.
- ✅ Every level can add knowledge to it.
- 🟡 No bits or binary here either (§2.1): glyph dots and paint do the explaining. The journal test checks the words and case rows never say bits, binary or colors.

## 6. Optimization & leaderboards 🟡

Lessons from Opus Magnum:
- **Multiple metrics:** Cost, Ticks (speed), Area (footprint), plus Edits for repair puzzles. No single solution wins all.
- **Histograms, not just top-10 lists** ("you beat 72% on cost"). Plus **friend leaderboards**.
- **Stars are the kid-friendly face of the optimizer:** ★ solved · ★★ under budget · ★★★ near-optimal. Experts open the same screen and find the histograms.
- ✅ **Prototype stars:** ★ solved · ★★ at or under the level's budget · ★★★ at or under the best known count (every best known count is proven minimal by `tools/level_solver.gd`). Metrics: **Cost** (the machine's total: critters and the red pot 1, splits free, pots and inventions at the player's own price; "Pieces" on screen until 2026-10-08) and **Ticks** (until the loom is full). Best Price and best Ticks are kept separately.
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
- ✅ **Each critter is what its name says** (designer, playtest rounds 1 and 2, decided 2026-10-05; built 2026-10-05: `ui/draw_kit.gd`'s mixing_tub, sieve, flip_pan, hamster and split, all drawn through `K.piece` by their look; inventions are stickers with their name). Testers had found the pieces factory-like: Mix, Invert and Filter were the same tub with a face, told apart by a prop. Each critter has its own silhouette first (readable at tray size, mid-run and on big machines, §12), then a way of moving that follows from it, in today's wood, paper and ink (the Shift Wheel's rim stays the only signal hue outside paint).

  | Critter | Brief |
  |---|---|
  | **Mixing Tub** (Mix) | Wide, round and jolly; stirs with stubby arms, cheeks puffing as the swirl turns into the new paint |
  | **Sieve** (Filter) | An actual sieve: a round mesh in a wooden hoop on little feet, a fussy face; it shakes and the held-back grains hop |
  | **Flip Pan** (Invert) | A frying pan, think omelettes (designer, 2026-10-05; the name was Flip Tub): a dark iron pan with a wooden handle and a face; the drop sits in it like an omelette, gets tossed (showing its paint mid-air, as today), and lands on its other side, the opposite paint |
  | **Shift Wheel** (Shift) | Kept: a bigger hamster with ears and a real run cycle, the wheel clicking one notch per drop |
  | **Red pot** and earned pots | Kept: already a tool and a character |
  | **Split** | Stays plumbing, on purpose not a critter (it's free): a glass and brass fitting matching the tubes |

  New materials, muted so nothing reads as paint (WP4 calls, 2026-10-05): the Flip Pan's iron (`IRON`, `IRON_DK`, `IRON_LT`) with its handle up to the upper left, behind the pan (playtest R3, 2026-10-06); Split's brass (`BRASS`, `BRASS_DK`). The Mixing Tub's stubby arms hold its spoon above the paint; the Sieve's face sits on its hoop's band.
- ✅ **Glassier tubes** (designer, playtest round 2, 2026-10-05; built 2026-10-05). A tube is a thick ink outline round a cream fill with a thin bright glint (paper-white, about 2 px, a little transparent) along each tube's upper inner edge, following its curve, and a faint shade (hoop grey, low alpha) along the lower one, so a drop sits *inside* between them (the outline about 12 px). Inlets' glass stubs get the same glint and shade, their ring a highlight arc; outlets stay wooden spouts (the critter's), with a small ink collar where the glass slips over. Neutrals only; the selected tube keeps its hoop halo. Tubes sit on the wiring layer, so it costs next to nothing a frame.

- 🟡 The R1 note's gerbil that shaves the input off black isn't a Flip Pan; "shave B off A" is **Bleach** (`Filter(A, Invert B)`), so the gerbil waits as Bleach's character when it arrives (the inventions' personality pass).
- 🟡 **Themes and skins: parked, with a clean seam** (designer, 2026-10-05; R1 note). No engine while there is one theme: its shape depends on the second (a palette swap, an artist's sprites, seasonal skins, high contrast for accessibility). The R3 note's dark theme in brown tones would be that second theme (playtest notes). ✅ The rule meanwhile: every colour drawn has a name in `ui/palette.gd` (built 2026-10-05: no colour literal is left outside it), and every piece is drawn only through its `look` (`core/pieces.gd`), so a theme later is a palette set and a look table. ✅ **A theme never touches the eight signal colours or their glyph dots**: they are game rules, not skin (§7.1, §8).
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
  - ✅ **Chain reactions** (built 2026-09-28): a piece may also fire into a full tube if the piece that tube feeds fires this same tick. Firing sets only grow as the check repeats, so the result still doesn't depend on visiting order. Under the strict rule a steady pipeline alternated full/empty and wove one stitch every two ticks (The Flower, now The Harbour, 388 ticks); with chain reactions it weaves one per tick (195 with the Filter sticker as one piece; both measured in 2026-09). Measured on every reference solution: balanced machines halve their ticks, but where a Split feeds paths of different lengths into a Mix the short path's drop still waits (then: Purple 50 → 39, Harbour Cat 99 → 76). That remaining slowness is a price-vs-Ticks trade-off (two pots instead of a split), not a bug.
  - Caveat for memory pieces: under this rule a closed loop with every tube full can't turn.
  - An invention is one node that takes one tick and looks up its answer (§5.1).
  - Machines can never loop in this model (a loop waits on itself), so every working machine is a pure function of the cards. Memory pieces will need their own rule.
- 🟡 **Intro** (from playtest notes): a short note at every launch says this is an early build and an update may reset saved progress; one tap anywhere (or Enter) goes on. Jumping straight into a level from the command line skips it.
- 🟡 **Saves** (from playtest notes): the save file carries a version and its layout is documented in `core/progress.gd`. A save from another version, or one that no longer fits the levels (unknown level or invention ids, machines with pieces the level doesn't offer, missing keys), is stale: the launch intro says so instead of its usual note and offers Start fresh or Keep what fits. Either way the old file moves to a `.bak` beside it (never overwriting an older backup); nothing is deleted. ✅ (2026-10-05, built 2026-10-05) Keep what fits also forgets a solved invention level whose invention it dropped, so the level reads unsolved and earns it again. No migration code while the game is in development. ✅ **Save compatibility where feasible** (designer, 2026-10-05): testers carry their progress from build to build instead of starting unlocked (§5.1, cheat codes), so a change that can keep old saves valid should (new fields with defaults, ids kept stable); where a break is unavoidable, the version bump and the stale check above still handle it. Save version 3 since the chapter plan (2026-10-05): the campaign changed under every save. Save version 4 since the round 2 campaign (built 2026-10-05), the one save break of round 2.
- ✅ **Local profiles** (designer, playtest round 1 note, shaped 2026-10-05; built 2026-10-05: `core/profiles.gd`, `ui/profile_picker.gd`; the local leaderboard is still later). A profile is a save slot: a critter badge (tapped from the critters, no reading needed) and an optional name that defaults to the critter's, so a child makes one without typing and a parent can type "andrew". One save file each (`chromaton_save_<id>.json`); **the existing save becomes the first profile untouched** (save compatibility, nothing to migrate). Settings stay per device (keys and speed belong to the keyboard and screen). With one profile nothing is asked; with two or more the launch intro adds "Who's playing?" (a row of badges, a tap goes on; Enter or Space for the one who played last), and the level select has a profile chip in its top-right corner, under the journal button, opening a screen to switch or add one. The badges are the five critters (Mixing Tub, Shift Wheel, red pot, Sieve, Flip Pan); a name is at most 16 letters; the roster lives in `user://chromaton_profiles.json` (WP4 calls, 2026-10-05). 🟡 A pencil under the playing profile's badge changes its badge and name on the same page as a new player (playtest R3, 2026-10-06: the first profile's name couldn't be changed; built 2026-10-06). Later, a **local leaderboard** on the Scores tab: each level's best Cost and Ticks per profile on the device, side by side, the best starred.
  - ✅ **This is the anonymous, local, offline mode** (designer, 2026-10-05). In a wider player service (say an online Steam release), local profiles stay what they are: no account, nothing leaves the device, nothing online, which also keeps them clear of the children's-data rules (§10). Accounts, online leaderboards and sharing would come on top of it as a separate layer, never in place of it.
- ✅ **Live on itch.io:** https://ibourlakos.itch.io/chromaton, channel `web`, played in the browser at 1280×800. Released with `.\make release itch` from a committed tree (every test, a fresh web export, butler), versioned by date and commit. Current: **2026.10.18-0027698** (build #2150318, package B: tray, bench and paint card). The release log since 2026-10-05 is in [docs/design-history.md](docs/design-history.md).
  - **Saves matter for real:** testers have progress on it, so save compatibility holds where feasible (above) and ids stay stable.
  - **The store page:** the cover and four screenshots in `build/itch/` were retaken on 2026-10-05 (The Black Queen's bench under the title, Harbour Cat mid-run, The Black Queen, The Mixing Table's guide, the journal's Sieve page) for the designer to upload; they predate playtest R3's levels and the picture card, so a fresh set is due.
  - ❓ Whether this channel is a development release (for the cheat engine, §5.1).
- **Distribution:** web export on itch.io for friends → Steam later (GodotSteam; Steam Direct fee $100; Steamworks leaderboards) → mobile later.
- ✅ **Prototype v0.1 is built** (Godot 4.7, GDScript only, Compatibility renderer, no threads or plugins). See CLAUDE.md for layout and commands.

### 9.1 Workbench UI 🟡 (flow direction ✅)

The bench as built (`ui/workbench.gd`), on a 1280×800 design canvas scaled to the window. Dates say when a choice was made; the reasoning trail of each is in [docs/design-history.md](docs/design-history.md).

**Layout**
- ✅ **Paint flows left to right** (the mockup flows downward; it is the style reference only, §7.2). Machines grow deeper as puzzles get harder and the screen is landscape, so depth gets the long axis. The cloth still weaves top to bottom (§4).
- **Top bar:** Back (✅ always the upper-leftmost control, on every screen and overlay), the Options gear right of it, the level's number (stamp brown) and its two title phrases with the "?" (§5.1); on the right the Paints button, Undo, Reset, Step back, Step, Run/Pause, and the three speeds.
- **The bench** is 11 cells deep by 7 tall (84 × 80 px cells). Pattern cards sit on its left edge (§4); the loom stands on the right, the small design card above it, the star bar and Ticks below. ✅ The loom's inlet sits on the bench's middle row, so a machine laid straight along it doesn't kink (2026-10-05). ✅ **Pieces snap to half cells** (2026-10-05): 21 × 13 places, a whole cell's footprint, never overlapping, so a piece can sit between two rows; cards keep whole rows. The machine carries `"grid": 2`; a stored bench without it is whole cells, doubled on load (no save break). An optional grid (Options) shows faint cell lines with dots at the half points.
- **The pieces bar** fills with wood as pieces are placed, so it reads as progress, not a limit (playtest: "Pieces 3" read as a cap). One line divides it, after the three-star count: ★★★ over the part before it, ★★ over the part up to the two-star count (where its frame ends); they light while the bench is within. Past two stars it goes on, paler and dashed, with room for two more, and stretches for a bench that holds more (playtest R3, 2026-10-06). Under it, "Cost" and the bench's cost ("Cost 3", designer 2026-10-18), since the bar alone showed no number. Ticks show as the clock icon and a number.
- **The tray** is a shelf along the bottom (room for about nine slots) with the journal (peek, §5.7) and Clear all at its right end. Pieces a level holds back sit in it locked; no slot or key moves from level to level. Two slots are groups that fan their pieces out on a paper card above the shelf (a tap or the slot's key opens it, a tap or drag takes one out, number keys pick from the open fan, a tap elsewhere or Back folds it; one fan open at a time): the pots share one (§5.1), and ✅ **the Inventions slot** (playtest R3 and R4, designer 2026-10-18; built and merged 2026-10-18): from the first invention earned, every invention shares one slot after the six critters, key 7 on every level (before, an invention's key moved with the level's list). Its fan holds the inventions the player owns from earlier levels, in the order earned, the ones the level doesn't list locked in their places; its face, which a drag from the folded slot places, is the first one the level lists. Owning only one, the slot is that invention; a level that lists none shows it locked. It keeps the tray at seven slots through chapter 4, leaving room for two new pieces; the critters stay one tap each, as every level uses them. ✅ **Each slot shows its price** (2026-10-05): a chip in its top-right corner, the piece icon and the number, "0 free" on Split; the key cap stays top left and the name on the bottom line. It is the player's own price; no "could be cheaper" mark, since improvements come forward (§5.1); ✅ the R4 idea of such a mark was declined (decision 9, 2026-10-18): the hint panel says it where it matters (the success panel, below).
- ✅ **Clear all** (playtest R3, 2026-10-06): a tap arms it ("Tap again", lit three seconds), a second clears every placed piece and tube (cards and loom stay); Undo brings it back. Carrying a piece, a tap just drops it.

**Gestures** (touch-first: everything works by tap and drag)
- Drag from the tray to place; drag a piece to move it, or back onto the tray to remove it; ✅ drag on empty bench to draw a selection rectangle (designer, playtest R3, 2026-10-18; built and merged 2026-10-18): two or more pieces whose middles it holds are selected together (each cell lit, a dashed frame round them all, one delete button under them), move together when one is dragged (their tubes with them; where any would not fit, none moves), go to the tray together, and go with one delete or the Delete key (one Undo brings them back); one piece in it is selected as a tap would. Cards are never caught. A tap on an empty spot clears it; a tap on a tube still selects the tube; drag from an output to an input (or the other way) to lay a tube; drag a tube's end off an input to re-route or drop it. A tap selects a piece or tube; its delete and book buttons appear around it (§5.7). Any edit rewinds the run; Undo covers every edit. ✅ Delete happens only on an explicit selection, never on what is merely under the pointer.
- ✅ **Pattern cards: selectable, movable along the left edge, never removable** (2026-10-05). A tap selects a card (peek opens the pattern card's page); no delete button. A drag slides it up or down the left edge to any row whose first cells are free; dropped on another card the two swap; anywhere else it slides back with a wiggle. A card keeps its letter wherever it sits, and the letter orders an invention's inputs. Its row is saved with the bench.
- Ports: paint goes in on a piece's left through short glass pipes and out on its right through wooden spouts; with two ports, the first is on top. Tubes are glass curves; crossings are allowed (no routing rules yet). A drop travels its tube during the tick it was made, then waits at the far end; a woven drop flies into its cell. Tubes can end anywhere on the loom.

**Running**
- ✅ **Three speeds** (2026-10-05): slow 0.8 s a tick, normal 0.22 s (the default), fast 30 ticks a second on any machine. Fast keeps time by the clock, stepping several ticks in a long frame (at most 8, so a browser stall never runs away). The chosen speed carries across levels, saved with the settings. Step back replays the run to one tick earlier (the simulation is deterministic).
- Level 1 has a wordless hand hint and Run glows once the loom is fed; this grew into guided levels (§5.7).
- **A failed run** stops at the first wrong stitch: the loom marks it, a bubble compares the woven drop with the wanted one (glyph dots), and every card rings the drop that wove it (§4). "Card B has no tube" and "Card B still has paint left" say why a run couldn't start or finish (§9). The "?" glows (§5.1).
- **The success panel** ("Woven!"): the stars pop in, the cloth, **Cost** and Ticks with a "best!" badge where they improved, and the new invention on invention levels. ✅ **The score is a cost** (designer, 2026-10-18; built 2026-10-18 on the branch `objectives`): it is the machine's cost, not how many pieces stand on the bench (playtest R4, 2026-10-08, when it was called Price), so the panel, the Scores tab, an invention's page and the objectives say Cost, and the bench's pieces bar has "Cost 3" under it (saves keep `best_pieces`). Under them, the level's objectives as the hint panel shows them, filled as they stand (§5.1, "Level objectives"; until 2026-10-18 one line on how to earn the next star). 🟡 **When ★★★ waits on an earlier ★★★** (playtest R4, 2026-10-08; decision 9, designer 2026-10-18; built 2026-10-18): where a pot or invention costs this player more than the level's ★★★ allows, a line names it and the way down: "Your Third Paint costs 2. Three stars on 25. The Pawn bring it down to 1." (a line per invention; a pot in lowercase, "Your yellow pot"). It is the ★★★ objective's note (§5.1), on the **hint panel** until the level has ★★★, so it is said before the run, and on the success panel while ★★★ is missing. Both read the level's `star_needs` (`Level.dear_inventions`): for each pot or invention, the dearest price at which a machine still reaches ★★★, proven by `.\make solve` (each on its own, the rest at their cheapest so far), not the reference machine, so the line is never false (41 The Black Trophy's reference uses Same Paint, but its ★★★ needs nothing cheaper and it says nothing). ✅ **No tray mark** for an invention not at its cheapest (decision 9): it would nag on every level that offers it, most of which don't need it cheaper, and hide in the folded Inventions slot. Then "New in your journal" (§5.7).

**Keys** 🟡 (from playtest notes; ✅ the changes of 2026-10-05)
- Every key only does what a tap already does, so touch loses nothing. Small key caps sit on the controls they press: shown by default unless the device has a touch screen; touching hides them, a key brings them back, and ? (or H) or Options turns them on or off for good. Players call them key labels.
- Defaults (`ui/keys.gd`, each action with two slots). **Everywhere:** Esc back. **Workbench:** Space run/pause; S or → step; A or ← step back; R reset; Z undo (step and undo repeat when held); − and = slower, faster; Tab the next speed; Delete or Backspace removes what is selected; P the paint card; J the journal at what is selected (peek); O Options; 1–9 pick up a tray piece (it follows the pointer, a click on a free cell puts it down, anywhere else, a right-click or Esc drops it back; a locked piece's key only wiggles its lock). Esc drops a carried piece, then clears the selection, then puts the paint card away, then leaves the level. **After weaving:** Enter or Space next (Space only once released since the panel opened and after about half a second), R weave again, Esc the levels. **Level select:** ← → or A D turn pages, Enter or Space the first open unsolved level, J or B the journal, O Options. **Journal:** 1–7 a tab, Tab the next tab, ← → or A D a page, ↑ ↓ or W S scroll, Enter a word's page, J, B or Esc closes. "New in your journal" and the intro go on with Enter or Space.
- Keys go by the letter printed on the key (the digit row also by position, for AZERTY). While a text field has the focus, every key is typing (playtest R3). The settings file carries a key version: keys saved before a change of defaults are dropped, the other settings kept. Web: the canvas takes keys once clicked; in browser fullscreen the browser keeps Esc.

**Options** 🟡: the gear on the level select and ✅ on the workbench (2026-10-05: right of Back, opening over the bench as peek does; the run pauses and Back returns to the bench as it was; not over the success panel). Show a grid on the bench is always there. Where a keyboard is likely (desktop and web, not phone builds) it also lists every action by screen with two key slots each: tap a slot, press the key; a clashing key moves off the other action, which blinks. Plus Show key caps and Put every key back. Every setting (keys, key caps, grid, run speed, the paint card) is saved at once in `user://chromaton_settings.json`, apart from progress.

**The paint card** 🟡 (playtest, 2026-10-04): a Paints button in the top bar hangs a card of the eight paints over the bench (`ui/paint_card.gd`), laid out as a mixing triangle in the glyph dots' places (red on top, yellow lower right, blue lower left, each mix on the edge between its two, black in the middle, white apart), each drop with its glyph dots and its name under it (black's above it). Opposites face each other across black along dashed lines (Invert jumps across); three bold ink arrows, arcs of one ring round the triangle, each arching over a whole side from near one corner to near the next, show Shift turning the triangle one corner on (red to yellow to blue). ✅ The arcs replaced short arrows from a corner to the mix beside it, which read as red turning orange (designer, playtest R3, 2026-10-18; built and merged 2026-10-18); the triangle shrank a little to make room. Not modal; a tap on it, the button, P or Back puts it away; it stays up from level to level. ✅ It stays a cheat sheet beside the journal's Paint article (§5.7), and ✅ the colour rules stay in play: no beat before black; the paint card and the guided step lines carry them. Each piece's journal page has a line on working the piece out on the card.

**Drawing**
- ✅ The workbench draws in layers that redraw only when what they show changes (still parts: top bar, tray, bench, grid and design card; the wiring; the moving paints), so tray pieces hold still and only pieces on the bench are alive. Measured on an Intel UHD 620 laptop (desktop build): 80 ms a frame down to 36 ms with this and cheaper tube joints. `.\make bench` measures each layer per level.
- 🟡 **Pre-rendered critters: parked** (designer, 2026-10-05). `.\make bench` (headless, 60 frames a second): about 3 to 4.5 ms a frame on average at fast, critters the biggest layer on big machines. Baking would cost game-driven animation, crisp art at any size and the quick screenshot loop. ✅ The rule: bake each critter's still parts into a texture (moving bits as transforms) only if a big machine's worst frame passes about 12 ms on the UHD 620 laptop, after a windowed web build there (The King at fast) shows stutter. That check is still to do.
- Invert shows its input color during the first half of its flip (Invert is its own inverse, so the input is known from the output).

---

## 10. Audience & platforms

- Puzzle fans (programmers, Zachtronics players) **and** kids (~8+), families.
- ⚠️ Online features for under-13s carry legal obligations (COPPA in the US, GDPR child rules in the EU). Steam accounts are 13+, so this matters mainly for mobile later. Build leaderboards/sharing so they can be disabled. Local profiles (§9) are the almost-anonymous, local, offline mode that always works without them.

---

## 11. Roadmap

Done:
1. ✅ **The algebra locked:** completeness verified by script ([docs/algebra-report.md](docs/algebra-report.md)); the middle kit, Filter a starting critter (§2.5).
2. ✅ **The art style:** Critter Workshop (§7.2). The world vocabulary is still 🟡 (§3).
3. ✅ **Prototype v0.1** (2026-09-28): workbench, loom, 15 levels, stars, price and Ticks, inventions, saved progress.
4. ✅ **Live on itch.io** (§9), released after every round.
5. ✅ **Playtest round 2, four work packages, one release each** (2026-10-05): WP1 the new campaign in the players' words (the one save break), WP2 the bench, WP3 teaching (guided levels, the journal's growth), WP4 art and players (the critter redraw, profiles). Every "call the build made" was folded into the sections above; the packages' text is in [docs/design-history.md](docs/design-history.md).
6. ✅ **Playtest R3** (2026-10-06): the picture card (Path B, §4), chapters 3 and 4 at nine levels, the R3 quick wins.
7. ✅ **Playtest R4 quick wins** (2026-10-08): the price wording, the ★★★ price line, the loom's shuttle, the little boards centred.
8. ✅ **Package B, tray and bench** (2026-10-18): the Inventions slot (key 7 on every level), the selection rectangle on the bench, the paint card's Shift arcs (§9.1). On itch since 2026.10.18-0027698.

Next: the playtest notes (PLAYTEST-NOTES.md, local) hold what's still to do, grouped in packages, and the proposal for **Chromaton 1** (chapters 1–8, every machine a pure function of its cards) with the sequel in [CHROMATON-2.md](CHROMATON-2.md). Chapters 5 and 6 are planned (§5.1).

---

## 12. Open questions ❓

- Final world vocabulary (§3): leaning dye works + loom.
- Workshop cast / story voice on top of the component critters (§7.2).
- How critters simplify when zoomed out on large machines.
- Which arities Mix/Filter support (2 only, or n?). The primitive set is decided (§2.5).
- Thread routing rules (crossings, bridges)? The bench is a grid with half-cell snapping (§9.1).
- Title: "Chromaton" conflict search.
- Should players name their inventions? (Their names and personalities are a later pass, §3.)
- Glyph dots on woven stitches, or keep the cloth clean?
- Are the star thresholds the right pressure? (Each ★★ budget keeps its level's old margin over ★★★, a WP1 call.)
- Chapter 5 and 6's order (§5.1); the Lost Levels' way in (§5.1); the cheat engine and whether the itch channel is a development release (§5.1, §9); `card_shows`'s name and range (§5.1).
- The Chromaton 1 proposal's decisions (playtest notes): the line after chapter 8, the two-inventions cap in Choosing and Plates, sound, the full-spectrum Shift's chapter.
