# Chromaton 2

> Everything about the sequel in one place, gathered 2026-10-06 from a design conversation. **Proposed, not decided.** Nothing here has been recorded in DESIGN.md. Each item says where it came from: **(designer)** is already in DESIGN.md or PLAYTEST-NOTES.md, **(proposal)** is new from this conversation. The crucial Chromaton 1 parts are in PLAYTEST-NOTES.md, under "Chromaton 1".

**Status legend:** ✅ Decided · 🟡 Proposed / leaning · ❓ Open. Everything below is 🟡 or ❓ unless it says otherwise.

---

## 1. The line between 1 and 2

🟡 **Chromaton 1 is every machine that is a pure function of its inputs. Chromaton 2 is every machine with memory.** (proposal)

- **The test:** if `tools/level_solver.gd` can prove the level's ★★★, it belongs in 1. A level that needs history (a tube that starts full, a loop, a card the machine writes on) belongs in 2.
- **1 = chapters 1–8** (Paint Box, Pattern Cards, Invent What You Know, The Looking Glass, Choosing, Asking Questions, Plates, Counting). **2 = chapters 9–12** of the parked plan (Memory, Routing, Rows That Remember, The Programmable Loom), plus the pillars below.
- **Why this seam:**
  - It is the oldest one in the field: combinational logic first, sequential logic second.
  - It is the seam in the code. State breaks four things (DESIGN.md §9 and the algebra review in PLAYTEST-NOTES.md): the solver's proofs, the one-tick invention lookup, the invention's every-paint check, and "a closed loop with every tube full can't turn."
  - 1 keeps its "every star is proven minimal" promise from first level to last. 2 changes the rules and says so.
- **A frame for the story:** 1 is Babbage's Difference Engine (fixed-function arithmetic, ending in an adder); 2 is the Analytical Engine (memory, and cards that control the machine), which is the Jacquard loom's own lineage (DESIGN.md §4). Internal framing, not titles.
- **Reading that supersedes an earlier one:** first in the conversation 2 was "whatever comes after the programmable loom, with chapters 9–12 inside 1." The version recorded here moves the line earlier, so chapters 9–12 become 2's core. ❓ Confirm the line, and whether it sits after chapter 8 or elsewhere.

## 2. Thesis: the cloth reads itself

🟡 (proposal) In 1 the pipeline is: cards in, machine, cloth out, one stitch at a time (stitch *i* depends only on each card's *i*-th drop). In 2 the machine can see the cloth it has already woven (the row above, the neighbours), and a cloth can become a card. That closes the loop: cloth → card → machine → cloth.

- It is the sequel move of *7 Billion Humans* after *Human Resource Machine*: the soul stays, the verb changes.
- It gives Jacquard, cellular automata and picture filters, which the notes treat as late chapters, as the premise instead.
- It is more tangible than abstract state machines: every puzzle has a picture you can see.
- It builds on what is already there: the pattern card as a picture (Path B, DESIGN.md §4), cards that are the player's earlier cloths (Appliqué, chapter 6 of 1), and the Slate (below).

## 3. The rule changes, in order of need

All from the algebra review in PLAYTEST-NOTES.md (designer, 2026-10-04, parked), with the cost named there. Every one costs more in the rules and the solver than in drawing the critter.

1. **Delay** (1 in, 1 out). Gives back the drop it got last time, starting from a preset paint (white, or one the player taps in).
   - No firing-rule change: a piece whose output tube starts full. A loop is legal if it passes through a Delay.
   - Builds a toggle (Invert in a loop), a red-yellow-blue counter (Shift in a loop), "everything so far" (a running Mix), "changed?" (Contrast of a drop and the one before), and a Keeper register (a Stencil fed back through a Delay, 5 pieces).
   - One simulator fix: a loop with every tube full must still turn (two Delays in a ring).
   - An invention with Delays becomes a state table, and the every-paint check covers every state.
2. **A hand-turned critter** (designer, 2026-10-05: a separate critter, nothing to do with the Shift Wheel): a piece set by hand to force a paint. A setting chosen on the bench is a preset, like a Delay's starting paint, so it belongs here.
3. **If White and Merge** (branching).
   - If White (2 in, 2 out): a control drop and a paint drop; the paint leaves by the top exit if the control is white, otherwise by the bottom. Feed the same drop to both and it routes itself.
   - The hard part is the rule: a real brancher sends nothing out of the other exit, so an unused exit can no longer carry white.
   - Needs a Merge (oldest drop first, top on ties), the catch pot back as a bin (it was taken out of the trays, DESIGN.md §2.5), and a stream model in the solver.
   - Opens removing smudges instead of recolouring them (smudges were dropped as a puzzle idea, DESIGN.md §5.1, because skipping stitches needs routing), and the buffer puzzles (§5.4).
4. **The Slate**: a card the machine writes on its left and reads in order on its right.
   - Fed back into itself it is the Jacquard card chain (a long delay). One row long it gives "the row before", which generative textiles need.
   - Output cards that a later level reads would chain levels together.
   - ❓ Order: the plan puts Routing (If White, Merge) before the Slate. The thesis says the cloth reading itself is the heart of 2. Should Rows That Remember come before Routing?

🟡 **Stars after state.** Without the solver's proofs ★★★ can't be proven minimal. (proposal) The simulator verifies every solution (it is deterministic, DESIGN.md §6) and stars become relative: the best known, ranked by the community. Say so openly in 2, so 1's "proven" promise isn't broken by surprise. ❓ How ★★ budgets work without a proof.

## 4. The campaign

The parked chapter plan (PLAYTEST-NOTES.md, "Later chapters, parked"; designer, 2026-10-05), chapters 9–12. Every chapter keeps a multiple of three levels so its quilt fills its grid, and has at most 12 levels and two new inventions (DESIGN.md §5.1, ✅ rules).

| Ch | Theme | Logic ancestor | New rule or piece | Levels | Quilt |
|---|---|---|---|---|---|
| 9 | Memory | Flip-flops, finite-state machines | Delay | 9: Toggle, ring counter (red, yellow, blue stripes), running Mix, change detector, Keeper (a register), the paint-box counter (Next Paint plus a Delay walks the eight paints), three tartan cloths | **Tartan**: stripes, gingham and checks woven with no card at all |
| 10 | Routing | Demultiplexer, branching | If White, Merge, the catch pot as a bin | 9 buffer levels: remove smudges instead of recolouring, sort by darkness, dedupe, count the reds, interleave two cards, ... | **Scrap quilt**: built from sorted scraps |
| 11 | Rows That Remember | Cellular automata | Slate | 6: Sierpinski triangle (Contrast of the two neighbours, rule 90), the Rule 30 shell pattern, ... ending with Rule 110 | **Shells**: generative triangles and shells |
| 12 | The Programmable Loom | CPU (the Jacquard loom) | None new | 3: the card is a program; a ring counter steps through it, Keepers hold values, Questions and Choose decode it, the loom weaves what it says | The finale tapestry |

- **Turing completeness:** chapter 11. Memory alone (chapter 9) gives finite-state machines. A finite-state machine plus a Slate that loops back into itself is a queue machine (Post's tag systems); Rule 110 shows it a second way. It needs the Slate or the cloth to grow without limit; bounded, it is only a big finite-state machine, like any real computer. (designer)
- ❓ **27 levels is thin for a sequel**, against 1's about 66. The gap is filled by the pillars below, by chapters growing (up to 12 each), or by both. Not decided.
- **An on-ramp.** 2 opens on a loom weaving something, not on a pot of red (see §5, pillar 5). A short recap set of pure-function levels, using the player's imported inventions, could bridge. ❓ Whether it is needed.

## 5. Pillars

All (proposal) unless marked.

1. **Space finally matters.** Today tubes cross freely and layout is cosmetic (DESIGN.md §9.1), Pieces and Ticks mostly move together, and ★★★ is one proven number, so histograms would be a spike (the critic's main worry about 1, which stateful play and shared outputs cure).
   - Give the bench one real constraint: crossings that need a bridge piece, or tube length that costs something. ❓ Which one.
   - Show a **Pieces × Ticks Pareto plot**, not only stars (DESIGN.md §6 already wants histograms and several metrics; the notes mention Area and Edits).
   - **Modifiers on the same level**, in the BTD6 way (DESIGN.md §1, §5.3's constrained puzzles): Easy keeps your inventions in the tray, Hard forbids them. Kids and experts without two games.
   - 🟡 Fix-it puzzles (§5.3) and buffer puzzles (§5.4) are part of 2's variety.
2. **The Studio is the endless mode.** (the first half is the designer's creative loom, §5.5)
   - Import any image; the game quantizes it to the eight paints. The challenge is to weave it with the cheapest machine, so repetition becomes counters and symmetry becomes mirrors (the compression challenges in §5.5).
   - Scoring needs no solver, only the simulator.
   - A seeded **daily cloth**, which `tools/make_cards.gd` already half-builds. Machines share as a short code; tapestry and GIF export (§6, Opus Magnum's marketing).
   - A **Workshop** for levels works if the author must submit their own solution (as in Baba Is You and Poly Bridge).
   - 🟡 Likely **free post-launch updates to 1**, not 2's headline: they need no new rules, and they keep 1 alive and visible before 2 arrives. The new verb is what sells 2. ❓ Where the Studio ships.
   - The parked "try it" journal pages and the lab (§5.5) revisit here.
3. **Sound.**
   - Map the three primaries to three notes. Mixing then makes chords: black is the full chord and white is silence. The paint algebra is already set union, so the mapping is exact.
   - A wrong stitch becomes audible, and the loom plays a melody (the tapestry as a score). It is a second channel for accessibility and doesn't touch the reserved-colour rule (§7.1), which is visual.
   - Critters need voices. DESIGN.md §7.4 only lists royalty-free sources. 🟡 Cheap enough to ship in 1.
4. **A light cast and a voice.**
   - Answer the open question of a workshop cast (§7.2, §12): three or four characters give **commissions** with constraints. That turns the parked rush-orders mode (§5.6) into a calm one: a budget, a palette, no timer. Real-time pressure fights the thoughtful-puzzler mindset (§5.6's own warning).
   - **Historical notes** (designer, R3): rewards on how looms relate to automation through history, one snapshot per reward. ❓ How rewards map to levels (their own chapter, or spread). Optional, never blocking. 2's themes (Hollerith, punched cards, Lovelace's comparison of the Analytical Engine to the Jacquard loom) fit.
5. **The first minute shows a picture.** 2 opens on a loom weaving something. Single-colour levels, if any, become a later tutorial, not the front door.
   - Avoid, as defaults: the "re-earn this pot cheaper" pattern and the mirror-twin chapter structure. Elegant on paper, repetitive in play.

## 6. What carries over from 1

- **Inventions** import as lookup stickers. An invention is already one piece with a stored answer for every combination of paints (DESIGN.md §5.1), which remains valid in 2 as a stateless piece. Inventions with Delays are the new kind (state tables).
- **The journal, the lexicon, profiles, the loom, stars and Scores.** The journal's tabs and Words extend; the pieces' two names and the critters' art style stay.
- **Saves:** keep compatibility where feasible (the standing rule); the simulator change is version-gated.
- **Simulator:** deterministic, tests headless. Delay is a piece whose output tube starts full, so the firing rule is unchanged (§3).

## 7. Platforms and release (for 1 and 2)

- **Steam Deck is the most important target.** Its screen is 1280×800, the design canvas's size, and it has a touch screen, so touch-first (CLAUDE.md) pays off directly. Controller: a cursor over the half-cell grid with a carry-and-drop key should work. (proposal)
- **Order:** itch web demo (live), a Steam page early for wishlists, a Next Fest demo, 1.0 on Steam, tablets (iPad first), then phones. The bench has 21×13 snap points (§9.1), so phones are cramped; the phone-sized-window layout note (R3) is where that starts. (proposal; DESIGN.md §9 already has "web → Steam (GodotSteam) → mobile")
- **Model:** premium, no ads, no IAP; 2 is a natural bundle with 1. Price not decided.
- **Players' data:** local anonymous profiles stay the baseline (§9, ✅); any online layer (leaderboards, sharing, Workshop) is separate and optional, which keeps the game clear of the children's-data rules (§10).
- **Languages:** every string behind a table now; Greek as the first proof (designer, R3). For right-to-left, mirror the text UI but never the bench, which is a diagram like a circuit or a score and flows left to right (§9.1). ❓ Font coverage for Greek (Fredoka and Nunito) and, later, Arabic and Hebrew.
- **Accessibility as marketing:** always-on glyphs (§8), a dark theme in brown tones (designer, R3), reduced motion, high contrast (the likeliest second theme, §7.2).
- **Success** means: a 90% or better positive Steam score (for puzzlers that mostly means no difficulty cliffs and a way out of every stuck state), tapestries and GIFs that people post unprompted, and a daily or Workshop tail that outlasts the campaign. Word of mouth rather than spend. (proposal)

## 8. What 2 should not do

- **No real-time pressure** (§5.6's warning).
- **No logistics.** That is *shapez*'s lane (§1).
- **No more primaries.** The closed eight-paint set is the elegance (§2.1, §2.4).
- **No bits, binary or bytes** in player text, even for memory (CLAUDE.md hard rule): state is "the machine remembers the last paint", a Delay's preset is a paint, the Slate is a card.
- **No theming of signal colours or their glyphs** (§7.2).

## 9. What to keep possible while finishing 1

- Keep `core/` pure and deterministic.
- Keep ids stable, saves compatible.
- Serialize machines compactly now, so share codes are cheap later.
- Put every string behind a table before more text piles up.
- Check the "Chromaton" name conflict before building a store page (§12).

## 10. Open questions, gathered

1. ❓ Does the line sit after chapter 8? (§1)
2. ❓ Slate before Routing? (§3)
3. ❓ How ★★ budgets work without a proof. (§3)
4. ❓ Is 27 levels enough, or do chapters 9–12 grow? (§4)
5. ❓ Is an on-ramp (recap levels, imported inventions) needed? (§4)
6. ❓ Which bench constraint: bridges or tube cost? (§5.1)
7. ❓ Where the Studio ships: free update to 1 or 2? (§5.2)
8. ❓ How historical-note rewards map to levels. (§5.4)
9. ❓ Price and bundle. (§7)
10. ❓ Greek and later RTL font coverage. (§7)
11. ❓ The workshop cast: how many, and whose voice. (§5.4; DESIGN.md §7.2, §12)

## 11. Source map

- **DESIGN.md:** §1 vision and neighbours, §2.1 and §2.4 the closed eight-paint set, §4 the loom and Path B, §5.3–5.6 fix-it, buffer, creative loom and commissions, §5.7 the journal, §6 optimization and leaderboards, §7.2 the cast, themes and splashes, §8 accessibility, §9 tech and distribution, §9.1 the bench, §10 audience, §11 roadmap, §12 open questions.
- **PLAYTEST-NOTES.md** (git-ignored): "Algebra review" (Delay, hand-turned critter, branching, Slate, several outputs, new functions), "Later chapters, parked" (chapters 5–12 and the Turing-completeness note), R3 (languages, historical notes, dark theme, phone layout), "Chromaton 1" (the release's crucial parts).
- **docs/algebra-report.md** §7 for each candidate's price in the game's kit.
