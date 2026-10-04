# Playtest notes

Raw remarks, gathered as they come. Not assessed yet. Only what's still to do;
landed items are removed.

# Round 1 (2026-10-03)

## Confusion

- Two testers, same question: "why r+g+b = black?" Possibly trouble with the world-building rules; unclear.
- A separate question on how colours work: how we construct dark, and how the colours mix (see the r+g+b item above).

## Observations

- Testers tend not to pay attention to the title.
- People in a hurry don't seem to cope well.

## Difficulty

- Level 14 (Black Cat): people really struggle on first encounter. It's the first surprisingly difficult level.
- Levels with multiple input cards should be considered advanced (see the "introductory chapters" point under Level design).

## Level design

- The six-colour input card should "trap" the player in one of its colours: if the player solves the six-colour card's mapping, they should have solved the puzzle.
- We need at least one more entry level for the invert, to showcase the case where a mixed colour inverts to a basic colour.
- Introduce the Filter and smudges in separate levels: the Filter first, smudges a bit later (today Smudges, Level 13, brings both at once). We also need a few more smudges levels.
- We definitely need interstitials between levels that teach and prepare the player. Whether they should also appear in the chapter previews (open). See the cutscene-like beat under "Enhance the narrative structure" in Ideas.
- The first chapter's levels (The Paint Box) don't need 2D results: they're single colours, so a one-row result should suffice.
- [ ] TODO: judge Level 17 (The Flower)'s new picture: a flower in a pot, a butterfly and a small flower, redrawn 2026-10-04 with paint from the first stitch. Wrong machines used to fail far beyond the 6 drops a card shows; now 5 of 74,679 cheap wrong machines get past those 6, and all fail within the first row.
- [ ] TODO: write hints for every level that has none. Levels now have a title (can be anything), a goal (what to weave) and a hint (guidance), and the note pops up as an unsolved level opens, but only Orange, Purple, Green and Nothing at All have hints so far (e.g. Level 18 (Missing From Either) opens with only its title and goal). Goals are not hints.
  - Meta-design goal: the game teaches players its own rules and "world setting", so hints guide the player.
  - At least chapters 1 and 2 (The Paint Box, Pattern Cards), and maybe 3 (Invent What You Know), count as introductory as far as goals go: they teach the player how to think.
  - Testers tend not to read the title (see Observations), so the hint, not the title, carries the guidance.
- Level 1 (One Pot of Red) is a kind of guide for the rest of the single-colour levels. Eventually they get pots of their own too, at various costs (see the colour-pots idea under Ideas).

## UI / layout

- The pattern frame's input socket should be inside, or much closer to, the tool area.
- The tool area needs a good name.
- When a level introduces a new tool, highlight that tool in the tray.
- Tools the player has already discovered but that are held back in a later level should still appear in the toolbar, shown as locked.
- A small panel in the UI showing all the colours, with their accessibility dots (glyphs), as a quick reminder (see the colour questions under Confusion and the compendium idea).
- When a run fails, it would be cool to be able to see the initial state of each card; once the player resets, those states should be cleaned up.
- Make the bench grid a bit finer so pieces can be positioned more smoothly.

## Art / personality

- Give the tools more personality: more whimsical, less factory-like.
  - Some tools can be actual tools, like the red pot.
  - The shift's hamster-wheel-like cycle is the vibe.
  - The inverter could be e.g. a gerbil that shaves the input colour off a black paint and delivers the result at its output.
- The filter needs rebranding: very interesting functionality and a neutral visual, but a badly failing name (see the noun-naming point and the vocabulary item under Ideas).
- Change the confetti success effect to successive colour splashes. (A first try landed and was reverted.)
- Introduce a themes and skins engine for the workbench and the tools.

## Tooling

- [ ] TODO: `.\make deploy` exists but butler isn't set up yet. Install butler, run `butler login` (the designer, in a browser), set the itch target (`user/game:channel`, or `ITCH_TARGET`), then do the first push.
- We need a versioning system for the repo and the game.
- We need a specific web distribution where all levels are unlocked, with a notification telling the player so (see the butler TODO above).

## Ideas

- Kind of important: offer more colour pots in the toolkit, each at its corresponding cost (see the cost rule under the pattern-book item, and the open discussion on deriving costs).
- Toggle-turn the shift tool to force specific coloring.
- The initial stages set the colour rules; those rules should be accessible in a compendium.
- Enhance the narrative structure of the levels.
  - Every tool name should be a noun: "red pot" is fine, "shift" and "filter" are not.
  - One axis is how we introduce people to tools. E.g. the filter gets a dedicated level with a rainbow card and rainbow-like weaving, so it showcases what it does.
  - Another axis: a cutscene-like beat (not a level, but browsable in the level list) that explains how the tool works.
  - Requirement: that information is appended to the player's stored journal / compendium / knowledge base (see the compendium idea above).
- Principle: the game itself should set the world-building rules through play first; the compendium comes as a reward and a reference tool. But there's pushback from confusion over how the 8 colours come from one another (see Confusion), so we might need a cutscene beat before level 1, or where things are about to get weird, e.g. just before the "black" level.
- Right-click (desktop) or long-press (mobile) on an element pops up its compendium details, but only what the player already knows about it at that point (can be tricky on occasion).
- Local player profiles: e.g. dad plays as "andrew", daughter as "butterfly". Opens the door to a local leaderboard.
- We need a vocabulary. Terms like element, unit and tool are already in use loosely; it should also cover the operations and the tools' names (see the noun-naming point and the tool-area name).
  - Part of the vocabulary can serve as an index for the compendium. Or the two should be kept separate (open).
  - Neither the player nor the designer can say exactly what a "tick" is. It should be explained in the vocabulary and the compendium.
- The pattern book should be part of the compendium.
  - Keep the rule that a tool costs the cheapest way we have invented it.
  - Hard requirement: we need levels that actually invent tools. Not every tool can be invented, of course.
- Reminder, not to address yet: set a stronger basis in the early stages, with levels that introduce a new piece, the **prism**: the first multi-output piece, one colour in and three out. It splits the input into its components, red, yellow and blue, one per output slot in a fixed order (red always the first, upper slot); a missing component comes out of its slot as white.
- **Open for discussion:** derive a tool's initial, probable and optimal cost from the complexity of its algebraic function, measured on the function's syntax tree (its syntactic elements).

# Algebra review (2026-10-04)

Recommendations from reviewing the algebra notes ([docs/algebra-report.md](docs/algebra-report.md), section 7 has the details). Not decided. Piece names are working names (see the noun-naming point under Ideas).

- Framing: today every machine is a plain function (stitch *i* depends only on each card's *i*-th drop). That's what lets the solver prove star counts and an invention run in one tick. Memory, branching and register-like cards all break it, so their cost is in the rules and the solver, not in drawing the critter.
- Recommended order: 1. Delay; 2. invention levels with several looms, with Sort and Stencil; 3. If White with Merge, when a noisy-card or buffer chapter needs it; 4. Slate.
- **Memory: a Delay critter** (1 in, 1 out): gives back the drop it got last time, starting from a preset paint (white, or one the player taps in; compare the toggle-turn idea under Ideas).
  - No firing-rule change: it's a piece whose output tube starts full. A loop becomes legal if it passes through a Delay.
  - Builds a toggle (Invert in a loop), a red, yellow, blue counter (Shift in a loop), "everything so far" (a running Mix), "changed?" (Contrast of a drop and the one before), and a Keeper register (Stencil fed back through a Delay, 5 pieces).
  - One simulator fix: a loop with every tube full must still turn (two Delays wired in a ring).
  - An invention with Delays becomes a state table; the every-paint check covers every state.
  - Fits chapter 4 (Memory) of the draft arc as its single new critter.
- **Branching: If White** (2 in, 2 out): a control drop and a paint drop; the paint leaves by the top exit if the control is white, by the bottom otherwise. Feed the same drop to both inputs and it routes itself.
  - The critter is easy; the rule isn't. Today an unused exit would have to carry white, and then a drop routing itself on white changes nothing. A real brancher sends nothing out of the other exit.
  - Needs a Merge (oldest drop first, top on ties), the catch pot back as a bin, and a stream model in the solver.
  - Opens removing smudges instead of recoloring them, and the buffer puzzles (reverse, sort, dedupe, count the reds).
  - Its conditions come from "question" inventions that answer black for yes and white for no (below).
- **Register-like cards: a Slate**, a card the machine writes on its left and reads in order on its right.
  - A Slate fed back into itself is the Jacquard card chain: a long delay.
  - A Slate one row long gives "the row before", which generative textiles need.
  - Output cards that a later level reads would chain levels together.
- **Several outputs:** an invention has exactly one output today. Invention levels with two or three looms, one output port each, unlock Sort, Share and Differ, and the prism (see the prism reminder under Ideas: it costs 6 pieces in the game's kit, and a missing component coming out as white is what Filter with each primary gives).
- **New functions, buildable today** (cheapest in the game's kit, proven by search unless a range):
  - **Stencil** (3 in, 1 out), 4 pieces: each primary from A where the stencil has it, otherwise from B. The favourite next invention.
  - **Sort** (2 in, 2 out), 2 pieces: Filter out the top, Mix out the bottom. Three Sorts give the lightest, middle and darkest of three paints; the middle is The Flower's rule. A good first multi-output invention.
  - Questions: Any Paint? 4, Is It White? 5, Is It Black? 4, Contains? 6. Choosing: Gate 5, Choose 5 to 8. Same Paint 4, Share and Differ (2 out) 4. Counting: Settle 7 to 15, Darker? 6 to 33. Mirror 7 to 11 (with Shift it makes every reordering of the primaries).
- **Costs:** `.\make algebra` now proves the cheapest machine for each recipe by search (the optimal cost), with the hand-built machine as the high end of a range: a measured take on the open discussion about deriving costs above.
  - The Black pot costs 3 at its cheapest (Mix(Red, Invert(Red))), but it's earned in All the Paint, which has no Invert, so it stays at 5 (open question in DESIGN.md 2.5).
