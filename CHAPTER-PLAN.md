# Chapter plan: chapters 1–4 (designer, 2026-10-05)

Handoff spec for reorganizing the campaign. Fold it into DESIGN.md §5.1 (the source of truth) and delete this file when done. Chapters 5+ are parked in PLAYTEST-NOTES.md; don't build them.

Four chapters of 9, 12, 6 and 6 levels (33 total). Every chapter has a multiple of three levels so its quilt fills its grid.

## Level text rule (all 33 levels)

The goal says what to weave; the hint states the rule in paint, then how to approach the machine. Example: "Wherever the card has paint, the cat is black. Turn the card's paint around the wheel and mix every turn together." Never mention bits, binary or bytes. Name pieces as the tray names them. Replace DESIGN.md §5.1 "Level text teaches" with this rule.

## Pots as pieces

From chapter 2 on, every pot the player has earned is open in every tray, through the one-slot pot fan-out decided in DESIGN.md §5.1 (tap the slot, the owned pots fan out above the shelf, drag one out; touch-first, no hover). A level can hold pots back. A level that offers only named pieces (e.g. "Third Paint + Split") offers no pots. Star thresholds assume each pot's cheapest price. Update the locked-tray rules (`Level._lay_trays`) to fit.

## Chapter 1, The Paint Box (9 levels; threads stacked into the quilt as today)

1–7 unchanged: One Pot of Red, Yellow, Blue, Orange, Purple, All the Paint, Green.

8. **NEW "Black, the Short Way"** (id `black_short_way`): a black thread from `Mix(Red, Invert(Red))`. Tray: pot, Shift, Mix, Split, Invert. ★★★ 3, ★★ 4. Earns the Black pot at 3 (a re-solve keeps the cheaper pot). Hint: "A paint and its opposite hold every paint between them. Mix red with its own opposite." Resolves the ❓ about the Black pot's price in DESIGN §2.5.
9. Nothing at All (same machine, ★★★ 4). Hint: "White is the opposite of black. Flip your black."

## Chapter 2, Pattern Cards (12 levels)

Seaside theme. Every picture is 4:3, so all patches share a shape; the quilt is 4 across × 3 down.

1. The Pattern Card (sailboat, keep).
2. Orange Sun: the card now holds the sun's red; `Mix(card, Yellow pot)` is the intended answer (`Mix(A, Shift(Red))` ties). ★★★ 3, ★★ 4. Hint: "The card holds the sun's red. Mix in yellow from your yellow pot." Needs a new card rule. First level that shows the pot fan-out.
3. **NEW "Parrot"**, the fork: `Mix(A, Shift(A))` on a card of red, yellow and white (black allowed); the parrot is orange and green on white. ★★★ 2, ★★ 3. Hint: "Fork the card's paint. Turn one half on the wheel, then mix the halves back: red meets yellow and makes orange." Needs a new card rule. (Verified: no machine without a fork weaves it.)
4. Turn the Wheel and 5. Opposites: now 8×6 swatches, each row all eight paints in a different order (the first row in journal order), so they sit in the quilt as full patches. Hints: "Tube the card through Shift and watch what one turn does to every paint." / "Tube the card through Invert: each paint flips to the one across the paint card."
6. Flip Side (beach flags, keep; make it 4:3).
7. Sandy Crab (id `smudges`): Filter arrives; a red crab, and the yellow smudges are sand. ★★★ 2, ★★ 3. Hint: "Keep only the card's red; the sand washes out."
8. **NEW "Lighthouse"**: the first two cards, `Mix(A, B)`. ★★★ 1, ★★ 2. Hint: "Each card holds part of the picture. Mix them, drop by drop."
9. **NEW "Where They Meet"** (a rock pool): `Filter(A, B)`. ★★★ 1, ★★ 2. Hint: "Lay one card over the other and keep only the paint they have in common."
10. Harbour Cat (id `black_cat`): a fork three ways. ★★★ 4, ★★ 6. Hint: "Wherever the card has paint, the cat is black. Turn the card's paint around the wheel and mix every turn together."
11. Wash Out (fish, keep). Hint: "Flip card B to its opposite, then keep only what it shares with card A."
12. The Harbour (id `the_flower`): the two-of-three rule on a 16×12 harbour picture with paint from the first stitch. ★★★ 4, ★★ 6. Hint: "A paint shows where at least two cards have it. Find what each pair of cards shares, then mix those together."

The Third Paint leaves chapter 2.

## Chapter 3, Invent What You Know ("Day", 6 levels)

8×8 patches; the quilt is 3 across × 2 down. Pictures are white chess pieces (pawn, rook, knight, bishop, queen, king), one per level in that order, on squares of two opposite paints (e.g. orange and blue) so no first row is all white, with a coloured gem or two.

1. The Third Paint (id `third_color`): **first invention, "Third Paint"** = `Invert(Mix(A, B))`. Kit tray. ★★★ 2, ★★ 3.
2. **NEW "Neither, Twice"**: rebuild Invert as `Third Paint(A, A)`. Tray: Third Paint, Split. ★★★ 2, ★★ 3. Earns a journal page, no invention.
3. **NEW "Back to Mix"**: rebuild Mix: a Third Paint, then flip its answer with another (`Third Paint(n, n)`). Tray: Third Paint, Split. ★★★ 4, ★★ 6.
4. Keep What They Share: rebuild Filter. Tray: the kit without Filter, plus Third Paint. ★★★ 4, ★★ 6. Hint: "Flip both cards to their opposites, then ask the Third Paint for what neither has."
5. Either, Not Both: **invention Contrast**. Tray: the kit plus Third Paint. ★★★ 4, ★★ 6.
6. **NEW "Only the Third Paint"**: Same Paint (each primary both cards have or both lack) from four Third Paints. Tray: Third Paint, Split. ★★★ 8 (prove it with the solver), ★★ 10. Earns the **invention "Same Paint"** at 8.

## Chapter 4, The Looking Glass ("Night", 6 levels)

Each level is the mirror twin (De Morgan dual) of chapter 3's level in the same slot. Its target picture is that level's picture in opposite paints (the photo negative: black chess pieces, squares swapped), so the two quilts hang as a pair. Cards are derived as usual. Every hint teaches the swap: every Mix becomes a Filter, and black becomes white.

1. Missing From Either: **invention "Missing From Either"** = `Invert(Filter(A, B))`. Kit tray. ★★★ 2, ★★ 3.
2. **NEW "Missing, Twice"**: Invert as `Missing From Either(A, A)`. Tray: Missing From Either, Split. ★★★ 2, ★★ 3.
3. **NEW "Back to Filter"**: Filter from two of them. Same tray. ★★★ 4, ★★ 6.
4. Mix Without Mix: the kit without Mix, plus Missing From Either. ★★★ 4, ★★ 6.
5. **NEW "Same Paint"**: `Mix(Filter(A, B), Invert(Mix(A, B)))`. Kit. ★★★ 4, ★★ 6. **Re-earns** the Same Paint invention at 4: two levels earn the same invention id, and the cheaper machine wins. Build that.
6. **NEW "Only Missing From Either"**: Contrast from four Missing From Eithers. Tray: Missing From Either, Split. ★★★ 8 (prove it), ★★ 10. Earns a journal page, no invention.

Checked on every paint: the 4-piece builds from the Third Paint and from Missing From Either; `Filter(Red, Invert Red)` = white; the two-of-three rule is its own twin.

## Also

- Quilts: keep equal patches, but fix the number across (chapter 2 four, chapters 3 and 4 three).
- Renamed levels keep their ids. Update the lexicon's "Journal: unlocks in <Level name>" lines and run `.\make words`.
- New card rules go in `tools/make_cards.gd`; recipes for the new inventions go in `tools/algebra_check.gd` if the check needs them.
- Bump the save VERSION (saves are disposable, no migration).
- Update the DESIGN.md §5.1 campaign tables and the ✅/🟡 markers.
- Take `.\make shot` screenshots of every new or redrawn picture and of each chapter's quilt (journal Cloths tab, `--solved=33`). Finish with a list of the pictures and hints for the designer to review.
