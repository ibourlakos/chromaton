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
- Built (2026-09-28): the Filter critter and piece. It arrives in Smudges, and from there every tray offers the whole kit (chapter 3's trays each leave one critter out, §5.1).

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

**Early inventions and their price in the game's kit** (report §6; proven cheapest by search unless marked ≤): Yellow pot 2 · Third Color 2 · Bleach 2 · Black pot 3 · Contrast 4 · Consensus 4 · Prism 6 · Any Red? 6 · Same Color? ≤ 8 · Three-way Switch ≤ 21 · Three-way Selector ≤ 23. Without Filter (chapter 3's trays): Filter 4 · Bleach 3 · Contrast 7. *(The old lean-kit list here had Black pot 5 and Consensus 11; the search found Mix(Red, Invert(Red)) and The Flower's 4-piece rule.)*
- ❓ The Black pot is earned in All the Paint (level 6), whose tray has no Invert, so it costs 5 there and can never reach its real cheapest, 3 (`Mix(Red, Invert(Red))`, the inside of Nothing at All). Either accept it, or let a later level re-earn the pot.

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

Working vocabulary until decided: *vat* (component), *thread* (wire), *braid* (bus: parallel threads), *recipe*, *machine*, *Swatch Book* (§5.7; its Inventions tab holds the player's inventions).

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
- **Chapter payoff:** each level weaves one band; completing a chapter joins the bands into a full tapestry (quilt reveal).
- Finale: a **programmable loom** (the CPU equivalent) that weaves a tapestry from a pattern card.
- 🟡 **Serial vs row weaving:** a single output thread weaves one stitch per tick with a shuttle walking the rows (as in the style mockup); a braid of W threads weaves a whole row per tick. Early levels can be serial; braids arrive later and weave faster.
- ✅ **Prototype: serial weaving.** One output thread; the loom takes one drop per tick and weaves the next stitch, row by row, left to right. The first wrong stitch stops the run and is marked.
- 🟡 A wooden shuttle threads along the row being woven, right across the slots, sitting on the next slot, and slides on to the next slot after each stitch (back to the left edge for a new row), trailing the weft it lays. The loom's cloth shows weft threads along each row, crossing the warp; the design card stays a plain picture.
- 🟡 Unwoven cells are sunken slots, darker than the cloth, so an empty slot never looks like a woven white stitch (bright and full size); a small faint chip of the target's paint sits in each (white as a pale chip). The target picture is pinned beside the loom as a small design card.
- 🟡 Woven stitches carry no glyph dots (as in the mockup); the wrong-stitch bubble compares the two drops with dots.

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

**Prototype v0.1 campaign** 🟡 (levels/*.json; cheapest counts proven by `tools/level_solver.gd`, see [docs/level-report.md](docs/level-report.md)):

✅ **Chapter 1, the paint box:** no pattern cards. Each level weaves a plain cloth of one color (4×3) from the red pot, one level per paint. Every level has a cheaper answer to find.

| # | Level | Teaches | Tray | ★★ budget | ★★★ best |
|---|---|---|---|---|---|
| 1 | One Pot of Red | Place a piece, lay a tube (wordless hand hint) | pot | 1 | 1 |
| 2 | Yellow | Shift | pot, Shift | 3 | 2 |
| 3 | Blue | Pieces chain: Shift twice | pot, Shift | 4 | 3 |
| 4 | Orange | Mix: two pots, one of them shifted | pot, Shift, Mix | 5 | 4 |
| 5 | Purple | Split: two pots is ★★, splitting one pot's paint is ★★★ | pot, Shift, Mix, Split | 5 | 4 |
| 6 | All the Paint | Black = every primary; two Mixes | pot, Shift, Mix, Split | 6 | 5 |
| 7 | Green | Invert. Mixing yellow and blue is ★★; Invert(red) is ★★★ | + Invert | 4 | 2 |
| 8 | Nothing at All | White: make black, then flip it | all | 6 | 4 |

✅ **Level text teaches** (designer, 2026-10-04, from playtests). A meta-design goal: the game teaches players its own rules and world through play, so level text guides the player. Chapters 1 and 2 (and maybe 3) are introductory: they teach the player how to think. 🟡 A level's text has three parts: a title (can be anything), a goal (what to weave) and an optional hint (the guidance); goals are not hints. 🟡 **Built (2026-10-04):** the hint must be visible and easy to revisit, so a level's note (title, goal, hint) pops up over the bench as an unsolved level opens; a tap anywhere or any key sends it flying home, where the hint (or the goal, on a level without one) sits under the title in ink. A "?" badge by the title says the title is tappable: tapping it brings the note back. ✅ **Every level has a hint** (designer's wording, 2026-10-04; in `levels/*.json`). Most say the level's rule in paint (Black Cat: "Wherever the card has paint, the cat is black."); the two levels with a hand hint set up the world instead: One Pot of Red "Every paint in the box starts from this one pot of red.", The Pattern Card "A card holds paint for every stitch and lets it out one drop at a time." Pieces are named as the tray names them (Shift, Mix, Filter, Invert) until their noun names are decided; no hint mentions bits or binary.

✅ **The pattern card gets its own level** (The Pattern Card: tube a card straight to the loom and the first picture appears, a sailboat; no pieces, the hand hint shows the tube). The card levels that follow are the 21-level campaign under "The next campaign" below.

- The v0.1 levels "Yellow from Red" (Shift a card) and "Opposites" (Invert a card) were cut: chapter 1 teaches both. Their files were removed. Opposites came back as a thread level (below).
- ✅ **Each level's tray is an explicit list.** A level offers only the pieces and inventions it names, so tools the player has earned (future color pots, inventions) never trample a puzzle that is meant to go without them. An invention also has to be owned to appear.
- Level ids are stable names (`green`, `black_cat`), not numbers; the number shown is the level's place in `index.json`, so levels can be inserted without renaming files or breaking saves.
- Pattern cards are derived from each target picture by `tools/make_cards.gd` (seeded by level id, so reruns match). The solver also proves the card data has no cheap shortcut.
- 🟡 Black Cat uses a red/white card instead of the red pot, so the black cat is a picture and not a plain black cloth.
- ✅ **Chapters** (built 2026-09-28): `levels/index.json` lists chapters, each a name and its levels. The level select shows one chapter per page (four tags per row, twelve at most), turned with arrows, with a dot per chapter; it opens on the chapter the player was last in. Level numbers run on across chapters.
- ✅ **Every other color pot is an invention** (designer, 2026-09-28): solving a paint-box level earns a pot of that color, a piece that makes that paint every tick. Like any invention it costs the pieces of the machine that made it (Yellow 2, Blue 3, Orange 4, ...), and it appears only where a level lists it.
- ✅ **The pots collapse into one tray slot** (designer): the tray shows one pot slot instead of up to eight. ✅ Its form: tapping the slot fans out the owned pots above the shelf; drag one out (touch-first, no hover). A dropdown list would look like desktop UI.
- ✅ A pot's price is the cheapest the player has made it for, so going back for ★★★ makes the pot cheaper. Star thresholds assume the cheapest price.
- ✅ **Built (2026-09-28):** paint-box levels 2–8 each earn their pot, an invention with no inputs and check `paint:<letter>` (the every-paint check is one stitch). A re-solve keeps the stored pot unless the new machine is cheaper. A pot invention is drawn as the clay pot with its own paint. No level lists pots in its tray yet, so the one-slot fan-out is still to build.
- ✅ **The Pattern Book's paint shelf** (built): eight pots across the top of the page in Swatch Book order, each with its price; the red pot is always there, unearned pots are dashed outlines with the level that earns them. Invention slots follow below.
- 🟡 Pots other than red wear a small swatch tag with the paint's glyph dots (always-on colorblind glyphs); the red pot has none, as the only pot players start with.
- 🟡 A full paint-box shelf closes the chapter.

**Playtest findings (2026-09-28)** and what they changed:

✅ **Teach what each piece does to every paint.** The paint box only shows Shift and Invert acting on primaries and black, so the card levels asked for rules nobody had seen (Keep What They Share needs Invert on any paint). Two ways at once, because not everyone learns the same way:
- Two short levels weave a single **thread** (one row), not a full picture: **Opposites** (a card of all eight paints through Invert) and **Turn the Wheel** (the same card through Shift). Each thread shows every paint beside what it becomes. A level needn't weave a full tapestry, especially early on.
- **Glyph dots show the rule when a piece fires:** Shift turns the dots one notch; Invert empties the filled dots and fills the empty ones.

✅ **Card levels don't write the rule in the goal line.** The cards and the design card carry it; the cloth is evidence to read, not just a check. Measured: many cheap machines match the first stitch (83 on Keep What They Share, 2,925 on The Flower) but only one weaves the whole cloth; most wrong ones fail by stitch 2–4, a few only at stitch 79. `tools/make_cards.gd` should order the card data so the cheap wrong machines fail within the first row.
- ✅ **Built (2026-09-28):** `tools/make_cards.gd` lists every function the level's pieces build within its ★★ budget (formula trees over every combination of card paints), then picks each first-row stitch's card paints among the rule's options, greedily, to make the most of them fail there. Every card level's cheap wrong machines now fail in the first row, except Wash Out (1 of 144 fails at stitch 12) and The Flower (6,336 of 74,679 get past its all-white first row, where "two of three" has nothing to show; the last fails at stitch 46). The rest of the rows stay seeded random.
- 🟡 **Aimed at what a card shows (playtest, 2026-10-04):** the greedy pick first works on the stitches a card shows at the start (6, `Level.CARD_SHOWS`), then on the rest of the first row. Smudges, Missing From Either, Keep What They Share and Mix Without Mix now fail every cheap wrong machine within those 6; The Third Color (1 of 144) and Either, Not Both (2 of 9,690) within the first row; Wash Out still has 1 at stitch 12. The Flower couldn't be fixed by its cards: its first 22 stitches were white, and a machine that makes white there passes whatever the cards hold (7,570 of 74,679 got past the first 6, the last failing at stitch 46). 🟡 So its picture was redrawn (2026-10-04) with paint from the first stitch: a red flower with a yellow and orange heart in an orange pot, a blue butterfly with a purple and black body, a small purple flower, grass. Now 5 of 74,679 get past the first 6 stitches and all fail within the first row.

✅ **Keep What They Share (the De Morgan level) was too steep and blocked the campaign.** Resolved by **Filter first, reinvent it later** (§2.5): Filter is a starting critter, and building it moves to the "invent what you know" chapter, opened by a stepping-stone level, **Missing From Either** (`Mix(Invert A, Invert B)`, 3 pieces), so Filter is "the opposite of what you just built". Nothing later needs the invention.
- ✅ Solving a level opens the next two, so one hard level never walls off the rest.
- ✅ With Filter as a piece, Wash Out becomes `Filter(A, Invert B)` (2 pieces). The Flower gets a new rule, **two of three**: a primary shows if at least two cards have it (4 pieces, `Filter(Mix(C, B), Mix(A, Filter(C, B)))`). Fallback if playtests find it too hard: `Mix(C, Filter(A, Invert B))`, 3 pieces.

🟡 **Noisy cards** (designer's idea): cards carrying stray paint on some stitches that the machine must clean up. With today's pieces every card drop weaves a stitch, so stray paint is *recolored* (e.g. `Filter(card, Red)`), not skipped; skipping stitches needs routing pieces (§2.3), later. ✅ Built: **Smudges**, a red-and-white card with yellow smudges on about a third of its stitches (always some in the first row), cleaned by `Filter(A, Red)`. Stray stitches on a card are marked with a neutral ink blot (never a signal hue), so it's clear where the noise is; the card JSON lists them (`"smudges"`).

✅ **The next campaign** (approved 2026-09-28; **built** 2026-09-28). Chapter 1, the paint box (1–8), stays as above, but each level now earns its pot. Cheapest counts are proven by the solver ([docs/level-report.md](docs/level-report.md)). ~~Goal lines say only what to weave, never the rule.~~ Superseded 2026-10-04, see "Level text" below.

*Chapter 2, Pattern Cards.* From Smudges on, every tray is the whole kit (pot, Shift, Mix, Filter, Invert, Split); before it, everything but Filter (Orange Sun: pot and Mix).

| # | Level | Teaches | Loom | ★★ budget | ★★★ best |
|---|---|---|---|---|---|
| 9 | The Pattern Card | A card is paint over time | 8×6 | – | 0 |
| 10 | Orange Sun | Mix a card with the pot | 6×4 | 3 | 2 `Mix(A, Red)` |
| 11 | **Opposites** (thread) | Invert on every paint | 8×1 | 2 | 1 `Invert(A)` |
| 12 | **Flip Side** (beach flags) | Invert on a picture: a mix flips to a primary | 9×4 | 2 | 1 `Invert(A)` |
| 13 | **Turn the Wheel** (thread) | Shift on every paint | 8×1 | 2 | 1 `Shift(A)` |
| 14 | **Smudges** (a heart) | **Filter arrives**; noisy cards | 8×6 | 3 | 2 `Filter(A, Red)` |
| 15 | Black Cat | Split and Shift a card | 6×4 | 6 | 4 |
| 16 | The Third Color (a kite) | Invert(Mix) | 8×6 | 3 | 2 `Invert(Mix(A, B))` |
| 17 | Wash Out (a fish) | Filter with a card as the mask | 8×6 | 3 | 2 `Filter(A, Invert B)` |
| 18 | **The Flower**, rule: **two of three** | A primary shows if at least two cards have it | 16×12 | 6 | 4 `Filter(Mix(C, B), Mix(A, Filter(C, B)))` |

🟡 **Flip Side** (playtest, 2026-10-04: Invert needed one more entry level, where a mixed paint flips to a primary). Three flags (blue, red, yellow) over a blue sea and yellow sand; the card (rule `invert`) holds their opposites, so orange turns blue and green turns red within the 6 drops a card shows, purple turns yellow right after, and black turns white in the second row. The cheap wrong machine `Invert(Mix(A, Red))` fails at stitch 4. Hint: "Every mix flips to the one paint it lacks: orange to blue."

*Chapter 3, Invent What You Know* (each tray leaves out one critter):

| # | Level | Rebuild | Tray leaves out | Loom | ★★ budget | ★★★ best |
|---|---|---|---|---|---|---|
| 19 | **Missing From Either** (a mushroom) | Stepping stone | Filter | 8×6 | 5 | 3 `Mix(Invert A, Invert B)` |
| 20 | Keep What They Share (a house) | Filter from Mix and Invert | Filter | 8×6 | 6 | 4 |
| 21 | **Mix Without Mix** (a tree) | The mirror image | Mix | 8×6 | 6 | 4 `Invert(Filter(Invert A, Invert B))` |
| 22 | **Either, Not Both** (a butterfly) | A new invention: **Contrast** | – | 8×6 | 6 | 4 `Filter(Mix(A, B), Invert(Filter(A, B)))` |

- Card rules added to `tools/make_cards.gd`: `smudges`, `two_of_three`, `missing` (two cards sharing exactly the opposite of the target), `mix`, `contrast` (card A random, B = what makes the difference).
- The Filter sticker is gone from the campaign (it shared a name with the Filter critter); the tests still build one from Keep What They Share as a fixture, so inventions inside inventions stay covered.

- ✅ Rebuilding a critter earns a Swatch Book page on what that critter is made of, plus stars; no sticker (the critter is already in the tray). The chapter ends with a real invention, Contrast, which keeps the invention loop going into chapter 4.
- ✅ Threads are 8 stitches, every paint once, in the Swatch Book's order, so the cloth reads as a lookup row and fills the piece's Swatch Book page in one run.

**Inventions in the prototype** ✅: solving an invention level saves the player's own machine to the Pattern Book (the Swatch Book's Inventions tab, §5.7) as a new piece. Its cards become input ports (in card order), the loom its output port; it is drawn as a sticker with its name and costs the total of its pieces.
- ✅ **An invention is one piece that takes one tick** (built 2026-09-28). Before, it ran the machine inside, so a Filter sticker took 3 ticks and hid drops in flight: paint seemed to vanish into it and come out late. The simulator stores the invention's answer for every combination of input paints and looks it up. Pieces still count everything inside; Ticks improve, which rewards inventing. Stateful machines (memory) will need their own rule.
- ✅ Before an invention is accepted it is run on every combination of input paints (64 for two inputs). A machine that only happens to match the level's cards is refused with a short note. The one-tick lookup depends on this check.
- 🟡 Re-solving an invention level replaces the invention with the newest machine. The name comes from the level; players don't name inventions yet.

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

### 5.6 Commissions / rush orders (tower-defense-like) 🟡 *later*
Customer orders arrive as incoming color streams with deadlines; the player patches the running machine live; completed orders earn currency for components; waves demand new transformations.
⚠️ Real-time pressure fights the thoughtful-puzzler mindset → offer slow-down/pause, keep it a separate later mode.

**Mode build order:** Campaign → Optimization layer → Creative loom → Commissions.

### 5.7 The Swatch Book ✅
An in-game book that explains how the game works: the eight paints and how they mix, the loom's timing (ticks, one-drop tubes, when a piece fires or waits) and every piece. Named after the swatch books textile mills kept: pages of dyed samples with notes.
- ✅ **One book with tabs: Paint · Loom · Pieces · Inventions.** The Pattern Book (the player's inventions) becomes its Inventions tab.
- ✅ Every entry exists from the start. Entries not discovered yet stay in the book, visibly locked (an empty swatch frame), so the player can see there's more to find.
- ✅ Every level can add knowledge to it.
- 🟡 Knowledge arrives from play: each piece's page has a frame per paint (Invert's page holds eight pairs), and a frame fills the first time the player's own machine does that in a run. Opposites fills the whole Invert page at once.
- 🟡 No bits or binary here either (§2.1): glyph dots and paint do the explaining.

---

## 6. Optimization & leaderboards 🟡

Lessons from Opus Magnum:
- **Multiple metrics:** Cost, Ticks (speed), Area (footprint), plus Edits for repair puzzles. No single solution wins all.
- **Histograms, not just top-10 lists** ("you beat 72% on cost"). Plus **friend leaderboards**.
- **Stars are the kid-friendly face of the optimizer:** ★ solved · ★★ under budget · ★★★ near-optimal. Experts open the same screen and find the histograms.
- ✅ **Prototype stars:** ★ solved · ★★ at or under the level's piece budget · ★★★ at or under the best known count (every best known count is proven minimal by `tools/level_solver.gd`). Metrics: **Pieces** (splits free, inventions at full price) and **Ticks** (until the loom is full). Best Pieces and best Ticks are kept separately.
- **Invented recipes cost the sum of their primitives** (flattened), or rankings break.
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
- 🟡 The Shift wheel is painted red, yellow and blue: the one place outside paint where signal hues appear, because the wheel *is* the rule it applies. Stars, confetti and UI stay in wood and paper tones.
- ✅ Fredoka and Nunito are bundled in `fonts/` (SIL Open Font License).

### 7.3 Progressive depth (the Bloons lesson) ✅
1. Early: drag, drop, watch paint flow. No reading needed.
2. Collecting: the Swatch Book (§5.7) fills like a sticker album.
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
- 🟡 **Saves** (from playtest notes): the save file carries a version and its layout is documented in `core/progress.gd`. A save from another version, or one that no longer fits the levels (unknown level or invention ids, machines with pieces the level doesn't offer, missing keys), is stale: the launch intro says so instead of its usual note and offers Start fresh or Keep what fits. Either way the old file moves to a `.bak` beside it (never overwriting an older backup); nothing is deleted. No migration code while the game is in development.
- **Distribution:** web export on itch.io for friends → Steam later (GodotSteam; Steam Direct fee $100; Steamworks leaderboards) → mobile later.
- ✅ **Prototype v0.1 is built** (Godot 4.7, GDScript only, Compatibility renderer, no threads or plugins). See CLAUDE.md for layout and commands.

### 9.1 Workbench UI (prototype) 🟡 (flow direction ✅)

- 1280×800 design canvas that scales to the window. Top bar: back, level name and one-line goal, Undo · Reset · Step back · Step · Run/Pause, and three speeds (0.55 s, 0.22 s and 0.05 s per tick; Normal is the default, and the chosen speed carries across levels, kept in the settings file with the keys).
- ✅ **Paint flows left to right** (the mockup flows downward; it is the style reference only, see §7.2). Machines grow deeper as puzzles get harder, and the screen is landscape, so depth gets the long axis: the bench is 11 cells deep × 7 wide (one piece per cell), pattern cards sit on its left edge as fixed pieces covering the first two cells of their rows (the rest of the edge takes pieces), and the loom stands on the right with the design card above it and the pieces bar and Ticks below. 🟡 The pieces bar (playtest: a "Pieces 3" count read as a limit) fills one wooden slot per piece placed, with room for two past the two-star count; a marker after the three-star count carries ★★★ on its left, one after the two-star count ★★ on its right, and they light while the bench is within. Ticks show as the clock icon and a number. The parts tray is a shelf along the bottom (room for about 9 pieces) with the trash at its right end.
- Pieces take paint in on their left side through short glass pipes and send it out on their right through wooden spouts; with two ports, the first is on top. Cards release paint from their right end, next color nearest the spout. Tubes are drawn as glass curves between ports; crossings are allowed (no routing rules yet). The cloth still weaves top to bottom (§4).
- Gestures: drag from the tray to place; drag a piece to move it, or back onto the tray (trash) to remove it; drag from an output to an input (or the other way) to lay a tube; drag a tube's end off an input to re-route or drop it; tap a tube or a placed piece to select it, then tap its delete button. Any edit rewinds the run. Undo covers every edit.
- Tubes can end anywhere on the loom. A drop travels along its tube during the tick it was made, then waits at the far end; a woven drop flies into its cell.
- Level 1 has a wordless hand hint; Run glows once the loom is fed. Step back replays the run to one tick earlier (the simulation is deterministic), for tracing a machine tick by tick in both directions.
- 🟡 **Key layer** (from playtest notes): every key only does what a tap already does, so touch loses nothing. Small key caps sit on the controls they press; they show by default unless the device has a touch screen, touching hides them, pressing a key brings them back, and ? (or H), a "? Hide key labels" chip on the level select, or Options turns them on or off for good. Players call them key labels. Workbench defaults: Space run/pause, S or → step, A or ← step back, R reset, Z undo (step and undo repeat when held), − and + speed, Tab cycles slow → normal → fast → slow, P puts the paint card up or away, **1–9 pick up that tray piece** (as does a tap on it; dragging still works): it follows the pointer and only a click on a free cell puts it down, a click anywhere else, a right-click or Esc drops it back (the right-click is only a shortcut for what a tap already does). **Delete or Backspace removes only what is selected** (tap a tube or a piece to select it), never what is merely under the pointer. Esc drops a carried piece, then clears the selection, then puts the paint card away, then leaves the level. After weaving: Enter or → next, R weave again, Esc levels (not Space, which may still be held from the run). Level select: ← → (or A D) turn pages, Enter plays the first open unsolved level (its tag wears the cap), B the Pattern Book, O Options. Keys go by the letter printed on the key (the digit row also by position, for AZERTY). Web: the canvas takes keys once clicked; in browser fullscreen the browser keeps Esc.
- 🟡 **Options**: a gear on the level select opens it, on every build. Show a grid on the bench (faint cell lines; off by default) is always there. Only where a keyboard is likely (desktop and web, not phone builds) does it also list every action by screen (Everywhere, Workbench, After weaving, Level select) with two key slots each (tray pieces one each): tap a slot, press the new key; Esc cancels, tapping it again clears it. A key moves off any action it would clash with (same screen, or Everywhere) and that slot blinks. Plus Show key caps and Put every key back. Every setting (keys, key caps, grid, run speed, the paint card) is saved at once in `user://chromaton_settings.json`, apart from progress.
- 🟡 **Paint card** (playtest, 2026-10-04: testers asked why red, yellow and blue make black, and how the darker paints are made). A Paints button in the top bar, left of Undo, hangs a card of the eight paints over the bench (`ui/paint_card.gd`), laid out as a mixing triangle in the glyph dots' places: red on top, yellow lower right, blue lower left; each mix on the edge between its two paints, black (all three) in the middle, white (no paint) apart. Each drop carries its glyph dots and its name. Two lessons come without text: opposites face each other across black along dashed lines (Invert jumps across), and Shift turns the triangle one corner clockwise. Not modal: the bench works around it, and it clears the middle row, where a single card's machine sits. A tap on the card, the button, P or Back puts it away; it stays up from level to level. The same picture can become the Swatch Book's Paint page (§5.7).
- ✅ The workbench draws its still parts (top bar, tray, bench and grid, design card) on a layer behind the rest that redraws only when they change (a piece picked up, the trash lit, key labels toggled), so tray pieces hold still; only pieces on the bench are alive. Measured on an Intel UHD 620 laptop (desktop build, vsync off): 80 ms a frame down to 36 ms with this and cheaper tube joints.
- Invert shows its input color during the first half of its flip (Invert is its own inverse, so the input is known from the output).

---

## 10. Audience & platforms

- Puzzle fans (programmers, Zachtronics players) **and** kids (~8+), families.
- ⚠️ Online features for under-13s carry legal obligations (COPPA in the US, GDPR child rules in the EU). Steam accounts are 13+, so this matters mainly for mobile later. Build leaderboards/sharing so they can be disabled.

---

## 11. Roadmap

1. **Lock the algebra:** ✅ completeness verified by script ([docs/algebra-report.md](docs/algebra-report.md)); ✅ middle kit with Filter as a starting critter (§2.5).
2. ✅ ~~Pick the art style~~: **Critter Workshop** (see §7.2). Still to confirm: world vocabulary (§3).
3. ✅ ~~Specify ~10 campaign levels~~: fifteen prototype levels (§5.1): a paint-box chapter of plain cloths, then pattern cards, ending in the woven flower.
4. ✅ ~~Godot vertical slice~~: **prototype v0.1** with workbench, loom, 15 levels, stars, Pieces and Ticks, inventions, saved progress.
5. Play it, show friends, decide the 🟡 items below; then a web build (needs `levels/*.json` in the export filter) on itch.io; iterate.

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
- Should re-solving an invention level replace the invention or keep the cheapest?
- Should players name their inventions?
- Glyph dots on woven stitches, or keep the tapestry clean?
- Are the level-8 budget (the Filter route earns ★★, the De Morgan route ★★★) and the other thresholds the right pressure?
