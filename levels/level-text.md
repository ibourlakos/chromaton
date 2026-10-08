# Level text, decided (2026-10-05)

Decided by the designer, 2026-10-05 (DESIGN.md §5.1, "Every level's text is decided"). Written into `levels/*.json` and the code on 2026-10-05 (titles as `name`, `cloth`, `machine`; goals; hints), except the guided step lines, which wait for the guided levels (WP3); this file stays the reference until then. Tracked in git, beside the level files; the web export ships only `levels/*.json`, so it never reaches players. It follows the decisions of 2026-10-05 in DESIGN.md:

- **Title:** two phrases side by side in the top bar, `cloth · machine`. The machine phrase says what the machine does, never how it's built; on an invention level it's the invention's name (with the sticker mark); in the paint box, the pot it makes.
- **Hint panel:** the goal, then the hint: a world-story sentence, then the how, naming pieces by their player words (red pot, Shift Wheel, Mixing Tub, Flip Pan, Sieve, Split). Invention names are today's (their names and personalities come later).
- **Guided levels:** one step line per step, shown beside the hand. ★ marks a guided level.
- Never bits, binary or bytes. No "A paint shows where ...".
- **A level's name** (its primary title, for tags, Cloths and Scores) is the cloth phrase, or in the paint box the machine phrase. Text that refers to a level gives its number and primary title: "2. The Yellow Pot" (designer, 2026-10-05; DESIGN.md §5.1).

Level numbers and order are the new layout (DESIGN.md §5.1, "The new chapters 1 and 2"). *Italic* titles are new levels.

---

## Chapter 1, The Paint Box

### 1 ★ Red · One Pot of Red (`one_pot`)
- **Goal:** Weave a red cloth.
- **Hint:** Every paint in the box starts from this one pot of red. Tube it straight to the loom.
- **Steps:** 1. "This is your red pot." (pot onto the bench) 2. "Tube its paint to the loom." (the tube) 3. "Press Run and watch it weave." (Run)
- Notes: hint kept; it already is story, then how.

### 2 ★ Yellow · The Yellow Pot (`yellow`)
- **Goal:** Weave a yellow cloth.
- **Hint:** The hamster runs, and its wheel turns red into yellow. Tube the red pot through the Shift Wheel.
- **Steps:** 1. "We only have red now." (the red pot in) 2. "One turn of the Shift Wheel makes red yellow." (the Shift Wheel in) 3. "Tube the red into the wheel." 4. "Send the new paint to the loom."
- Notes: steps are the designer's R2 example.

### 3 ★ Blue · The Blue Pot (`blue`)
- **Goal:** Weave a blue cloth.
- **Hint:** Your yellow pot is a piece now, and cheaper than a red pot with a wheel. Turn its yellow once more on the Shift Wheel.
- **Steps:** 1. "Your yellow pot is on the shelf now." (tap the pot slot; the fan opens) 2. "Take it out." (the yellow pot in) 3. "One more turn makes blue." (the Shift Wheel in, tube) 4. "To the loom."
- Notes: teaches an earned pot as a piece.

### 4 ★ Orange · The Orange Pot (`orange`)
- **Goal:** Weave an orange cloth.
- **Hint:** Paint on paint makes a darker paint: red and yellow make orange. Mix the red pot with your yellow pot.
- **Steps:** 1. "Red and yellow make orange." (the red pot in) 2. "Bring your yellow pot." 3. "The Mixing Tub stirs two paints into one." (the tub in) 4. "Tube both paints into the tub." 5. "Send the orange to the loom."
- Notes: carries the colour rule where it first shows (item 4).

### 5 ★ Purple · The Purple Pot (`purple`)
- **Goal:** Weave a purple cloth.
- **Hint:** Today the shelf is shut: only the red pot. Split its red, turn one copy twice to blue, and mix it back with the other.
- **Steps:** 1. "Only red today." 2. "Split copies one drop into two." (Split in, tube) 3. "Turn one copy twice to make blue." (two Shift Wheels) 4. "Mix it back with the other copy." 5. "To the loom."
- Notes: every earned pot held back (`hold_pots`).

### 6 Green · The Green Pot (`green_mix`, new)
- **Goal:** Weave a green cloth.
- **Hint:** Yellow and blue make green, as every painter knows. Mix your yellow pot with your blue pot.

### 7 Black · The Black Pot (`black`)
- **Goal:** Weave a black cloth.
- **Hint:** Pour every paint into one tub and it turns black. Mix a pot that holds red and yellow with your blue pot.
- Notes: the second colour-rule moment (item 4). Machine phrase: the pot it earns (designer, 2026-10-05; was "All the Paint").

### 8 ★ *Green · A Cheaper Green Pot* (`green`, kept: today's Invert(Red) level)
- **Goal:** Weave a green cloth.
- **Hint:** Every paint has an opposite across the paint card, and green is red's. Tube the red pot through the Flip Pan.
- **Steps:** 1. "Green sits across from red on the paint card." 2. "The Flip Pan flips a paint to its opposite." (the Flip Pan in) 3. "Tube the red pot into it." 4. "To the loom: green, and cheaper."
- Notes: re-earns Green at 1; "New in your journal" shows "Green pot: cheaper, 2 → 1".

### 9 *Orange · A Cheaper Orange Pot* (`orange_opposite`, new)
- **Goal:** Weave an orange cloth.
- **Hint:** A mix is the opposite of the one paint it lacks, and orange lacks only blue. Flip your blue pot.

### 10 *Purple · A Cheaper Purple Pot* (`purple_opposite`, new)
- **Goal:** Weave a purple cloth.
- **Hint:** Purple lacks only yellow, so it sits across from yellow. Flip your yellow pot.
- Notes: Purple 3 → 1, the biggest drop.

### 11 Black · A Cheaper Black Pot (`black_short_way`)
- **Goal:** Weave a black cloth.
- **Hint:** A paint and its opposite hold every paint between them. Mix red with your green pot.
- Notes: machine phrase the pot it re-earns (designer, 2026-10-05; was "The Short Way", from the old title "Black, the Short Way"). `Mix(Red, Invert(Red))` with a Split ties.

### 12 White · The White Pot (`white`)
- **Goal:** Weave a white cloth.
- **Hint:** White is the empty cloth, the opposite of black. Flip your black pot.

---

## Chapter 2, Pattern Cards

### 13 ★ The Sailboat · Straight from the Card (`pattern_card`)
- **Goal:** Weave the sailboat.
- **Hint:** A card holds a paint for every stitch and lets them out one drop at a time. Tube it straight to the loom.
- **Steps:** 1. "This card holds the whole picture." 2. "Tube it to the loom." 3. "Run, and watch the drops come out in order."

### 14 The Wheel Swatch · Turn the Wheel (`turn_the_wheel`)
- **Goal:** Weave the swatch.
- **Hint:** Tube the card through the Shift Wheel and watch what one turn does to every paint.
- Notes: designer's note: drop the first part. No story sentence: a showing level (swatches and tables; DESIGN.md §5.1, designer, 2026-10-05).

### 15 The Opposites Swatch · Every Paint Flipped (`opposites`)
- **Goal:** Weave the swatch.
- **Hint:** Tube the card through the Flip Pan: each paint lands on the one across the paint card.

### 16 The Orange Sun (`orange_sun`)
- **Goal:** Weave the orange sun.
- **Hint:** The card holds the sun's red. Mix in yellow from your yellow pot.
- Notes: hint kept as it was (designer: "very well stated"). The cloth alone: any machine phrase ("Add the Yellow") gives the puzzle away (designer, 2026-10-05).

### 17 The Parrot · Each Paint and the Next (`parrot`)
- **Goal:** Weave the parrot.
- **Hint:** The parrot's red feathers glow orange where the sun turns them. Split the card, turn one tube on the Shift Wheel, and mix both tubes back together.
- Notes: says Split, tube and Shift Wheel instead of fork, half and wheel (designer's note).

### 18 ★ *The Mixing Table · Every Pair Mixed* (`mix_table`, new)
- **Goal:** Weave the table.
- **Hint:** Card A holds one paint a row, card B every paint. Mix them drop by drop, and the cloth becomes the table of every mix.
- **Steps:** 1. "Two cards this time." 2. "The Mixing Tub takes one drop from each." 3. "Tube card A and card B into the tub." 4. "To the loom: every mix, row by row."
- Notes: guided for the second card.

### 19 The Lighthouse · Two Cards Mixed (`lighthouse`)
- **Goal:** Weave the lighthouse.
- **Hint:** At dusk the tower and its lamp are painted on two cards. Mix them, drop by drop.

### 20 ★ *The Sieve Table · What Every Pair Shares* (`filter_table`, new)
- **Goal:** Weave the table.
- **Hint:** The Sieve keeps only the paint both drops share. Sieve card A with card B, and the cloth becomes the table of every share.
- **Steps:** 1. "The Sieve keeps what two paints share." (the Sieve in) 2. "Tube one card into each side." 3. "To the loom: what every pair shares."

### 21 Sandy Crab · Keep the Red (`smudges`)
- **Goal:** Weave the crab.
- **Hint:** The sand washes out. Sieve the card down to its red.
- Notes: the designer's example, its sentences swapped, then "Keep only" made "Sieve ... down to" (designer, 2026-10-05: sieve is also a verb, so the how names the piece without giving away the red pot as the mask).

### 22 The Rock Pool · Where They Meet (`where_they_meet`)
- **Goal:** Weave the rock pool.
- **Hint:** In the rock pool, only what both cards hold stays. Sieve one card with the other.

### 23 The Fish · One Has Something the Other Hasn't (`wash_out`)
- **Goal:** Weave the fish.
- **Hint:** The tide washes card B's paint out of card A. Flip card B to its opposite, then sieve it with card A.
- Notes: adds the story part (designer's note). "Wash Out" no longer in the title; it could be the machine phrase instead ("The Fish · Washed Out").

### 24 The Harbour Cat · Convert to Black and White (`black_cat`)
- **Goal:** Weave the cat.
- **Hint:** Wherever the card has any paint at all, the cat is black. Split the card three ways, turn one copy once and another twice on the Shift Wheel, and mix all three.
- Notes: says the three copies and the turns outright (the old hint was "misleading or vague"). The hint's route is 5 (three Shift Wheels), within ★★ (6); ★★★ (4) splits the once-turned copy and turns it again, the player's find.

---

## Chapter 3, Invent What You Know

### 25 The Pawn · Third Paint (`third_color`, invention)
- **Goal:** Weave the pawn.
- **Hint:** Any two paints leave out a third, the one neither has. Mix the two cards, then flip the mix.

### 26 ★ *Two Pawns · What Neither Has* (`two_pawns`, new 2026-10-06, showcase)
- **Goal:** Weave the two pawns.
- **Hint:** Two pawns stand side by side, in the paint neither card has. Give your Third Paint both cards and tube it to the loom: one piece does what a Mixing Tub and a Flip Pan did.
- **Steps:** 1. "Your Third Paint is a piece now, on the shelf." (its slot lights) 2. "Like any piece: paints in on the left, one out on the right." (the Third Paint in) 3. "Give it both cards." (two tubes) 4. "To the loom: what neither card has, in one piece."
- Notes: the showcase after The Pawn (playtest R3); the first invention used as a piece is guided here now, so The Rook is no longer guided. Waits for the Third Paint.

### 27 The Rook · A Flip Pan, Rebuilt (`neither_twice`)
- **Goal:** Weave the rook, and build a Flip Pan from Third Paints.
- **Hint:** What neither of two same paints has is that paint's opposite. Split the card and give the Third Paint the same paint twice.
- Notes: the goal and the title now say it rebuilds Invert (designer's note). No longer guided since 2026-10-06: its steps (the first invention used as a piece) moved to Two Pawns.

### 28 The Queen · Extreme Mix (`either_not_both`, invention)
- **Goal:** Weave the queen.
- **Hint:** The queen wears only the paint that comes from one card alone. Mix the cards, then sieve the mix with the opposite of what they share.
- Notes: the invention's player name is **Extreme Mix** (designer, 2026-10-05; the title was "Either, Not Both"); Contrast stays its internal name. ★★★ with the discount is `Third Paint(Third Paint(A, B), Sieve(A, B))`; the hint describes the clearer ★★ route (4) on purpose; at the rebuild, `.make solve` must keep its ★★ budget at 4 or more.

### 29 *The Little Board · Stripes Crossed* (`little_board`, new 2026-10-06, showcase)
- **Goal:** Weave the little chessboard.
- **Hint:** Where a row's paint and a column's paint differ, the board turns dark. Give Extreme Mix both cards and tube it to the loom.
- Notes: a 4×4 board; card A is row stripes, card B column stripes, blue and orange, with two corner stitches that come out red. Extreme Mix costs 2, so ★★★ is 2. Waits for Extreme Mix.

### 30 The Knight · A Mixing Tub, Rebuilt (`back_to_mix`)
- **Goal:** Weave the knight, and build a Mixing Tub from Third Paints.
- **Hint:** Flip what neither card has and you get what either has. Ask a Third Paint what neither card has, then flip its answer with a second Third Paint.

### 31 The Bishop · A Sieve, Rebuilt (`keep_what_they_share`)
- **Goal:** Weave the bishop, and build a Sieve.
- **Hint:** What two paints share is what neither of their opposites has. Flip both cards, then ask the Third Paint.

### 32 *The Crown · Only the Blue Flipped* (`the_crown`, new 2026-10-06)
- **Goal:** Weave the crown.
- **Hint:** The card is the crown by night, every paint's blue flipped: added where it was missing, taken away where it was. Ask Extreme Mix about the card and a pot of blue.
- Notes: one card; ★★★ 3 (Extreme Mix 2 and the blue pot 1).

### 33 The King · Same Paint (`only_third_paint`)
- **Goal:** Weave the king using only Third Paints.
- **Hint:** The king wears paint where the cards agree: both have it, or both lack it. Find what only card A has and what only card B has, then ask a Third Paint what neither of those has. (To find what only B has: ask a Third Paint of card A and of what neither card has.)
- Notes: designer's title. No longer an invention level (two per chapter). Three sentences; the panel has room.

---

## Chapter 4, The Looking Glass

### 34 The Black Pawn · Missing From Either (`missing_from_either`, invention)
- **Goal:** Weave the black pawn.
- **Hint:** In the looking glass, mixing turns to sieving and black turns to white. Sieve the two cards, then flip what they share.

### 35 *Two Black Pawns · What They Don't Both Have* (`two_black_pawns`, new 2026-10-06, showcase)
- **Goal:** Weave the two black pawns.
- **Hint:** Two black pawns stand side by side, in the paint the cards don't both have. Give Missing From Either both cards and tube it to the loom: one piece does what a Sieve and a Flip Pan did.
- Notes: Two Pawns' twin; not guided (The Black Rook isn't either). Waits for Missing From Either.

### 36 The Black Rook · A Flip Pan, Rebuilt (`missing_twice`)
- **Goal:** Weave the black rook, and build a Flip Pan from Missing From Either.
- **Hint:** The rook's twin, in the looking glass. Split the card and give Missing From Either the same paint twice.

### 37 The Black Queen · Same Paint (`same_paint`, invention)
- **Goal:** Weave the black queen.
- **Hint:** In the looking glass, the queen wears paint where the cards agree. Mix what the cards share with the opposite of their mix.
- Notes: now the level that invents Same Paint.

### 38 *The Little Black Board · Stripes Agreeing* (`little_black_board`, new 2026-10-06, showcase)
- **Goal:** Weave the little black chessboard.
- **Hint:** The little board's twin, in the looking glass: where a row's paint and a column's paint agree, the board turns dark. Give Same Paint both cards and tube it to the loom.
- Notes: the same two cards as The Little Board; the corners come out green. Same Paint costs 3, so ★★★ is 3. Waits for Same Paint.

### 39 The Black Knight · A Sieve, Rebuilt (`back_to_filter`)
- **Goal:** Weave the black knight, and build a Sieve from Missing From Either.
- **Hint:** Flip what the cards don't both have and you get what they share. Ask Missing From Either, then flip its answer with a second one.

### 40 The Black Bishop · A Mixing Tub, Rebuilt (`mix_without_mix`)
- **Goal:** Weave the black bishop, and build a Mixing Tub.
- **Hint:** What either paint has is what their opposites don't both have. Flip both cards, then ask Missing From Either.

### 41 *The Black Crown · Only the Blue Flipped* (`the_black_crown`, new 2026-10-06)
- **Goal:** Weave the black crown.
- **Hint:** The crown's twin, in the looking glass: the card is the black crown with every paint's blue flipped. Same Paint keeps what agrees, so ask it about the card and an orange pot, which holds everything but blue.
- Notes: ★★★ 4 (Same Paint 3 and the orange pot 1; the solver also finds a 4 with Missing From Either).

### 42 The Black King · Extreme Mix (`only_missing`)
- **Goal:** Weave the black king using only Missing From Either.
- **Hint:** The king's twin wears paint from one card alone. Ask Missing From Either of the two cards, then of each card with that answer, then of the two answers.
- Notes: machine phrase as level 28's (Extreme Mix, the invention it rebuilds), the king and queen trading rules across the looking glass, as the levels already do.

---

## Lost Levels

- **Flip Side** (`flip_side`): The Beach Flags · Every Mix Flipped. Hint: "On the beach, every flag flips to the one paint it lacks. Tube the card through the Flip Pan."
- **The Harbour** (`the_flower`): The Harbour · Two of Three. Hint: "Gulls, sails and the quay, each on two of three cards. Sieve each pair of cards, then mix the three answers." Until chapter 6 earns its rule as Consensus.
- **The Chessboard** (`chessboard`, made up 2026-10-06 to try the largest cards, 12 by 9): The Chessboard · Flip, Then Sieve. Hint: "On the black squares card A is black and card B is bare. On the white squares the two agree. Flip card B to its opposite, then sieve it with card A." A black and white cloth woven from `Filter(A, Invert B)` (Flip Pan and Sieve only; the card maker's "bleach" rule); a Lost Level, played only from the command line (`.make level chessboard`).

---

## Text outside the level files (decided 2026-10-05)

- **Locked tag** (a level waiting for an invention): "Earn the Third Paint in 25. The Pawn." (26, 27, 30); "Earn Missing From Either in 31. The Black Pawn." (32, 33, 36).
- **"★★★ needs the invention" notice:** dropped. 28 and 29 open only from 26 or 27, and 34 only from 32 or 33, which all wait for the invention, so the player always owns it there (a cheat lends it).
- **"New in your journal":** cheaper: "Orange pot: cheaper, 2 → 1". A new chapter: "A new chapter: Invent What You Know", with its first level's tag. Opens: "The Third Paint opens 26. The Rook and 27. The Knight." (levels the invention opens beyond the usual next two).
- **The paint-card line on each piece page** (DESIGN.md §9.1), unlocking with the page:
  - Mixing Tub: "On the paint card, a mix sits between its two paints: red and yellow meet at orange."
  - Sieve: "On the paint card, the Sieve keeps the corners two paints share: orange and purple share red."
  - Flip Pan: "On the paint card, a paint's opposite sits straight across black."
  - Shift Wheel: "On the paint card, follow one arrow: every paint moves one corner on."
  - The red pot and Split: none (one rule each).
- **The lexicon's Gameplay texts in critter names:** written at the rebuild, when the rename is built, then `.\make words`.
- **Lost Levels**, the line under its name: "Levels that wandered off the campaign. They still weave." How it's found and laid out stays open (DESIGN.md §5.1).
