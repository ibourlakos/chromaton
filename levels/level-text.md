# Level text, decided (2026-10-05)

Decided by the designer, 2026-10-05 (DESIGN.md §5.1, "Level text"). Written into `levels/*.json` and the code on 2026-10-05 (titles as `name`, `cloth`, `machine`; goals; hints; the guided step lines as `steps`, with WP3): the level files are what the game uses, and this file keeps the decided text with its notes, the text outside the level files, and the levels' numbers (renumbered 2026-10-08). Tracked in git, beside the level files; the web export ships only `levels/*.json`, so it never reaches players. It follows the decisions of 2026-10-05 in DESIGN.md:

- **Title:** two phrases side by side in the top bar, `cloth · machine`. The machine phrase says what the machine does, never how it's built; on an invention level it's the invention's name (with the sticker mark); in the paint box, the pot it makes.
- **Hint panel:** the goal, then the hint: a world-story sentence, then the how, naming pieces by their player words (red pot, Shift Wheel, Mixing Tub, Flip Pan, Sieve, Split). Invention names are today's (their names and personalities come later).
- **Level objectives** (2026-10-18, DESIGN.md §5.1): the hint panel shows the goal as the ★ objective with the hint under it, then the ★★ and ★★★ costs. A goal says what the level earns ("and invent the Third Paint", "and earn the yellow pot"; level 1 "with the red pot"; the cheaper-pot levels "Three stars make your green pot cheaper."). A **★★★ nudge** (`star_hint`) is written only where the hint describes a dearer machine than ★★★ (28, 32); it shows once the player has ★★. The goals and nudges marked *(draft, 2026-10-18)* wait for the designer's markup; the level files already carry them.
- **Guided levels:** one step line per step, shown beside the hand. ★ marks a guided level.
- Never bits, binary or bytes. No "A paint shows where ...".
- **A level's name** (its primary title, for tags, Cloths and Scores) is the cloth phrase, or in the paint box the machine phrase. Text that refers to a level gives its number and primary title in the level-title font, the number and its dot in stamp brown and a narrow gap before the name: "2. The Yellow Pot" (designer, 2026-10-05; Bree Serif and the stamp-brown number since 2026-10-18; DESIGN.md §5.1). The level files write a marker, `{level:yellow}`, never the number and name; this file writes what the player reads.

Level numbers and order are the new layout (DESIGN.md §5.1, "The campaign today"). *Italic* titles are new levels.

---

## Chapter 1, The Paint Box

Every paint once (re-org in fours, 2026-10-18): eight one-row cloths stack into a square sampler. Split waits for Bargain Pots; the Flip Pan arrives on the last level.

### 1 ★ Red · One Pot of Red (`one_pot`)
- **Goal:** Weave a red cloth with the red pot. *(draft, 2026-10-18: was "Weave a red cloth.")*
- **Hint:** Every paint in the box starts from this one pot of red. Tube it straight to the loom.
- **Steps:** 1. "This is your red pot." (pot onto the bench) 2. "Tube its paint to the loom." (the tube) 3. "Press Run and watch it weave." (Run)
- Notes: hint kept; it already is story, then how.

### 2 ★ Yellow · The Yellow Pot (`yellow`)
- **Goal:** Weave a yellow cloth, and earn the yellow pot. *(draft, 2026-10-18: was "Weave a yellow cloth.")*
- **Hint:** The hamster runs, and its wheel turns red into yellow. Tube the red pot through the Shift Wheel.
- **Steps:** 1. "We only have red now." (the red pot in) 2. "One turn of the Shift Wheel makes red yellow." (the Shift Wheel in) 3. "Tube the red into the wheel." 4. "Send the new paint to the loom."
- Notes: steps are the designer's R2 example.

### 3 ★ Blue · The Blue Pot (`blue`)
- **Goal:** Weave a blue cloth, and earn the blue pot. *(draft, 2026-10-18: was "Weave a blue cloth.")*
- **Hint:** Your yellow pot is a piece now, and cheaper than a red pot with a wheel. Turn its yellow once more on the Shift Wheel.
- **Steps:** 1. "Your yellow pot is on the shelf now." (tap the pot slot; the fan opens) 2. "Take it out." (the yellow pot in) 3. "One more turn makes blue." (the Shift Wheel in, tube) 4. "To the loom."
- Notes: teaches an earned pot as a piece.

### 4 ★ Orange · The Orange Pot (`orange`)
- **Goal:** Weave an orange cloth, and earn the orange pot. *(draft, 2026-10-18: was "Weave an orange cloth.")*
- **Hint:** Paint on paint makes a darker paint: red and yellow make orange. Mix the red pot with your yellow pot.
- **Steps:** 1. "Red and yellow make orange." (the red pot in) 2. "Bring your yellow pot." 3. "The Mixing Tub stirs two paints into one." (the tub in) 4. "Tube both paints into the tub." 5. "Send the orange to the loom."
- Notes: carries the colour rule where it first shows (item 4).

### 5 Purple · The Purple Pot (`purple`)
- **Goal:** Weave a purple cloth, and earn the purple pot. *(draft, 2026-10-18: was "Weave a purple cloth.")*
- **Hint:** Red and blue make purple. Mix the red pot with your blue pot. *(draft, 2026-10-18)*
- Notes: no longer guided (2026-10-18): its Split steps moved to A Cheaper Black Pot and it holds nothing back. `Mix(Red, Blue)`, Purple 2 (was 3).

### 6 Green · The Green Pot (`green_mix`)
- **Goal:** Weave a green cloth, and earn the green pot. *(draft, 2026-10-18: was "Weave a green cloth.")*
- **Hint:** Yellow and blue make green, as every painter knows. Mix your yellow pot with your blue pot.

### 7 Black · The Black Pot (`black`)
- **Goal:** Weave a black cloth, and earn the black pot. *(draft, 2026-10-18: was "Weave a black cloth.")*
- **Hint:** Pour every paint into one tub and it turns black. Mix a pot that holds red and yellow with your blue pot.
- Notes: the second colour-rule moment (item 4). Machine phrase: the pot it earns (designer, 2026-10-05; was "All the Paint").

### 8 ★ White · The White Pot (`white`)
- **Goal:** Weave a white cloth, and earn the white pot. *(draft, 2026-10-18: was "Weave a white cloth.")*
- **Hint:** White is the empty cloth, the opposite of black. Flip your black pot.
- **Steps:** 1. "White sits across from black on the paint card." 2. "The Flip Pan flips a paint to its opposite." (the Flip Pan in) 3. "Take your black pot from the shelf." (the fan, the black pot in) 4. "Tube it into the Flip Pan." 5. "To the loom: black flipped is white." *(draft, 2026-10-18, from A Cheaper Green Pot's steps)*
- Notes: the Flip Pan's guided level since 2026-10-18 (was A Cheaper Green Pot's). `Invert(Black)`, White 3; A Cheaper White Pot brings it to 2.

---

## Chapter 2, Bargain Pots

Every paint is another's opposite (re-org in fours, 2026-10-18): the Flip Pan makes the pots cheaper, and Split arrives as the thrift tool. Its eight one-row cloths stack in the paint box's paint order (`quilt_order`), so the two quilts match row for row. Every pot ends where the old paint box left it: the mixes 1, black 2, white 2.

### 9 Green · A Cheaper Green Pot (`green`)
- **Goal:** Weave a green cloth. Three stars make your green pot cheaper. *(draft, 2026-10-18: was "Weave a green cloth.")*
- **Hint:** Every paint has an opposite across the paint card, and green is red's. Tube the red pot through the Flip Pan.
- Notes: re-earns Green at 1; "New in your journal" shows "Green pot: cheaper, 2 → 1". No longer guided (2026-10-18): the Flip Pan comes in on The White Pot.

### 10 Orange · A Cheaper Orange Pot (`orange_opposite`)
- **Goal:** Weave an orange cloth. Three stars make your orange pot cheaper. *(draft, 2026-10-18: was "Weave an orange cloth.")*
- **Hint:** A mix is the opposite of the one paint it lacks, and orange lacks only blue. Flip your blue pot.

### 11 Purple · A Cheaper Purple Pot (`purple_opposite`)
- **Goal:** Weave a purple cloth. Three stars make your purple pot cheaper. *(draft, 2026-10-18: was "Weave a purple cloth.")*
- **Hint:** Purple lacks only yellow, so it sits across from yellow. Flip your yellow pot.
- Notes: Purple 2 → 1.

### 12 *Yellow · Yellow Without the Wheel* (`yellow_opposite`, new 2026-10-18)
- **Goal:** Weave a yellow cloth, with the Shift Wheel put away. *(draft, 2026-10-18)*
- **Hint:** Yellow sits across from purple on the paint card. Flip your purple pot. *(draft, 2026-10-18)*
- Notes: earns nothing; the Flip Pan does the Wheel's job. The Shift Wheel is locked and the yellow pot held back. `Invert(Purple)` 2 (★★★), `Invert(Mix(Red, Blue))` 3 (★★).

### 13 *Blue · Blue Without the Wheel* (`blue_opposite`, new 2026-10-18)
- **Goal:** Weave a blue cloth, with the Shift Wheel put away. *(draft, 2026-10-18)*
- **Hint:** Blue sits across from orange on the paint card. Flip your orange pot. *(draft, 2026-10-18)*
- Notes: earns nothing; Shift Wheel locked, blue pot held. `Invert(Orange)` 2.

### 14 *Red · Red Without the Red Pot* (`red_opposite`, new 2026-10-18)
- **Goal:** Weave a red cloth, with the red pot and the Shift Wheel put away. *(draft, 2026-10-18)*
- **Hint:** Even red has an opposite: green, across the paint card. Flip your green pot. *(draft, 2026-10-18)*
- Notes: earns nothing; Shift Wheel locked and the red pot itself held back (`hold_pots: ["red_pot"]`: the pot slot still fans out the earned pots, the red one locked). `Invert(Green)` 2; without the lock `Shift(Blue)` would tie.

### 15 ★ Black · A Cheaper Black Pot (`black_short_way`)
- **Goal:** Weave a black cloth. Three stars make your black pot cheaper. *(draft, 2026-10-18: was "Weave a black cloth.")*
- **Hint:** A paint and its opposite hold every paint between them. Split the red pot's drop, flip one copy and mix it back with the other. *(draft, 2026-10-18; was "Mix red with your green pot.")*
- **Steps:** 1. "Only red today." 2. "Split copies one drop into two." (Split in, tube) 3. "Flip one copy to green." (the Flip Pan in, tube) 4. "Mix it back with the other copy." 5. "To the loom: a paint and its opposite make black." *(from The Purple Pot's steps, 2026-10-18)*
- Notes: Split's guided level since 2026-10-18 ("one pot, two tubes"). Every earned pot is held back (`hold_pots`), as The Purple Pot did, so one red pot split (3) beats two red pots (4) and Split earns its star. Black 3 → 2.

### 16 *White · A Cheaper White Pot* (`white_cheaper`, new 2026-10-18)
- **Goal:** Weave a white cloth. Three stars make your white pot cheaper. *(draft, 2026-10-18)*
- **Hint:** Your black pot is cheaper now, and white is still its opposite. Flip it. *(draft, 2026-10-18)*
- Notes: `Invert(Black)` with black at 2, White 3 → 2. ★★ 4: `Invert(Mix(Red, Invert(Red)))`.

---

## Chapter 3, Pattern Cards

### 17 ★ The Sailboat · Straight from the Card (`pattern_card`)
- **Goal:** Weave the sailboat.
- **Hint:** A card holds a paint for every stitch and lets them out one drop at a time. Tube it straight to the loom.
- **Steps:** 1. "This card holds the whole picture." 2. "Tube it to the loom." 3. "Run, and watch the drops come out in order."

### 18 The Wheel Swatch · Turn the Wheel (`turn_the_wheel`)
- **Goal:** Weave the swatch.
- **Hint:** Tube the card through the Shift Wheel and watch what one turn does to every paint.
- Notes: designer's note: drop the first part. No story sentence: a showing level (swatches and tables; DESIGN.md §5.1, designer, 2026-10-05).

### 19 The Opposites Swatch · Every Paint Flipped (`opposites`)
- **Goal:** Weave the swatch.
- **Hint:** Tube the card through the Flip Pan: each paint lands on the one across the paint card.

### 20 The Orange Sun (`orange_sun`)
- **Goal:** Weave the orange sun.
- **Hint:** The card holds the sun's red. Mix in yellow from your yellow pot.
- Notes: hint kept as it was (designer: "very well stated"). The cloth alone: any machine phrase ("Add the Yellow") gives the puzzle away (designer, 2026-10-05).

### 21 The Parrot · Each Paint and the Next (`parrot`)
- **Goal:** Weave the parrot.
- **Hint:** The parrot's red feathers glow orange where the sun turns them. Split the card, turn one tube on the Shift Wheel, and mix both tubes back together.
- Notes: says Split, tube and Shift Wheel instead of fork, half and wheel (designer's note).

### 22 ★ *The Mixing Table · Every Pair Mixed* (`mix_table`, new)
- **Goal:** Weave the table.
- **Hint:** Card A holds one paint a row, card B every paint. Mix them drop by drop, and the cloth becomes the table of every mix.
- **Steps:** 1. "Two cards this time." 2. "The Mixing Tub takes one drop from each." 3. "Tube card A and card B into the tub." 4. "To the loom: every mix, row by row."
- Notes: guided for the second card.

### 23 The Lighthouse · Two Cards Mixed (`lighthouse`)
- **Goal:** Weave the lighthouse.
- **Hint:** At dusk the tower and its lamp are painted on two cards. Mix them, drop by drop.

### 24 ★ *The Sieve Table · What Every Pair Shares* (`filter_table`, new)
- **Goal:** Weave the table.
- **Hint:** The Sieve keeps only the paint both drops share. Sieve card A with card B, and the cloth becomes the table of every share.
- **Steps:** 1. "The Sieve keeps what two paints share." (the Sieve in) 2. "Tube one card into each side." 3. "To the loom: what every pair shares."

### 25 Sandy Crab · Keep the Red (`smudges`)
- **Goal:** Weave the crab.
- **Hint:** The sand washes out. Sieve the card down to its red.
- Notes: the designer's example, its sentences swapped, then "Keep only" made "Sieve ... down to" (designer, 2026-10-05: sieve is also a verb, so the how names the piece without giving away the red pot as the mask).

### 26 The Rock Pool · Where They Meet (`where_they_meet`)
- **Goal:** Weave the rock pool.
- **Hint:** In the rock pool, only what both cards hold stays. Sieve one card with the other.

### 27 The Fish · One Has Something the Other Hasn't (`wash_out`)
- **Goal:** Weave the fish.
- **Hint:** The tide washes card B's paint out of card A. Flip card B to its opposite, then sieve it with card A.
- Notes: adds the story part (designer's note). "Wash Out" no longer in the title; it could be the machine phrase instead ("The Fish · Washed Out").

### 28 The Harbour Cat · Convert to Black and White (`black_cat`)
- **Goal:** Weave the cat.
- **Hint:** Wherever the card has any paint at all, the cat is black. Split the card three ways, turn one copy once and another twice on the Shift Wheel, and mix all three.
- **★★★ nudge** *(draft, 2026-10-18)*: Turning a paint twice is turning it once, then once more. A copy already turned once is halfway there.
- Notes: says the three copies and the turns outright (the old hint was "misleading or vague"). The hint's route is 5 (three Shift Wheels), within ★★ (6); ★★★ (4) splits the once-turned copy and turns it again, the player's find.

---

## Chapter 4, Invent What You Know

### 29 The Pawn · Third Paint (`third_color`, invention)
- **Goal:** Weave the pawn, and invent the Third Paint. *(draft, 2026-10-18: was "Weave the pawn.")*
- **Hint:** Any two paints leave out a third, the one neither has. Mix the two cards, then flip the mix.

### 30 ★ *The Chess Clock · What Neither Has* (`two_pawns`, new 2026-10-06, showcase)
- **Goal:** Weave the chess clock.
- **Hint:** The clock starts the game. Where a card has every paint, neither card is missing anything, so the cloth turns white. Give your Third Paint both cards and tube it to the loom: one piece does what a Mixing Tub and a Flip Pan did.
- **Steps:** 1. "Your Third Paint is a piece now, on the shelf." (its slot lights) 2. "Like any piece: paints in on the left, one out on the right." (the Third Paint in) 3. "Give it both cards." (two tubes) 4. "To the loom: what neither card has, in one piece."
- Notes: the showcase after The Pawn (playtest R3); the first invention used as a piece is guided here now, so The Rook is no longer guided. Waits for the Third Paint. Was Two Pawns until 2026-10-17 (playtest R4: it was The Pawn again, on cards of noise); now the first of the quilt's three chess themes (clock, board, trophy). Card A is the board by night with the dials left bare, card B the clock in black ink with green dials: the hint gives the new idea (black wipes the cloth white) and leaves the board flipping back, and the red dials, to the player.

### 31 The Rook · A Flip Pan, Rebuilt (`neither_twice`)
- **Goal:** Weave the rook, and build a Flip Pan from Third Paints.
- **Hint:** What neither of two same paints has is that paint's opposite. Split the card and give the Third Paint the same paint twice.
- Notes: the goal and the title now say it rebuilds Invert (designer's note). No longer guided since 2026-10-06: its steps (the first invention used as a piece) moved to level 30 (now The Chess Clock).

### 32 The Queen · Extreme Mix (`either_not_both`, invention)
- **Goal:** Weave the queen, and invent Extreme Mix. *(draft, 2026-10-18: was "Weave the queen.")*
- **Hint:** The queen wears only the paint that comes from one card alone. Mix the cards, then sieve the mix with the opposite of what they share.
- **★★★ nudge** *(draft, 2026-10-18)*: The Third Paint from 29. The Pawn gives what neither of two paints has, in one piece. Try the queen with Third Paints and one Sieve.
- Notes: the invention's player name is **Extreme Mix** (designer, 2026-10-05; the title was "Either, Not Both"); Contrast stays its internal name. ★★★ with the discount is `Third Paint(Third Paint(A, B), Sieve(A, B))`; the hint describes the clearer ★★ route (4) on purpose; at the rebuild, `.make solve` must keep its ★★ budget at 4 or more.

### 33 *The Chessboard · Stripes Crossed* (`little_board`, new 2026-10-06, showcase)
- **Goal:** Weave the chessboard.
- **Hint:** The game is played on sixty-four squares. Where a column is black, Extreme Mix flips the row's paint; where it is white, it keeps it. Give Extreme Mix both cards and tube it to the loom.
- Notes: 8×8 since 2026-10-17 (was The Little Board, 4×4 in black and white): card A is rows of orange and blue, card B columns of white and black, and the cloth the pieces' orange and blue checker, two corner stitches red. Extreme Mix costs 2, so ★★★ is 2. Waits for Extreme Mix.

### 34 The Knight · A Mixing Tub, Rebuilt (`back_to_mix`)
- **Goal:** Weave the knight, and build a Mixing Tub from Third Paints.
- **Hint:** Flip what neither card has and you get what either has. Ask a Third Paint what neither card has, then flip its answer with a second Third Paint.

### 35 The Bishop · A Sieve, Rebuilt (`keep_what_they_share`)
- **Goal:** Weave the bishop, and build a Sieve.
- **Hint:** What two paints share is what neither of their opposites has. Flip both cards, then ask the Third Paint.

### 36 *The Trophy · Only the Blue Flipped* (`the_crown`, new 2026-10-06)
- **Goal:** Weave the trophy.
- **Hint:** The game is won, but the card shows the trophy by night, every paint's blue flipped: added where it was missing, taken away where it was. Ask Extreme Mix about the card and a pot of blue.
- Notes: one card; ★★★ 3 (Extreme Mix 2 and the blue pot 1). Was The Crown until 2026-10-17: the same machine, the third chess theme. The card is a black and white board with the cup in blue and its gem in purple.

### 37 The King · Same Paint (`only_third_paint`)
- **Goal:** Weave the king using only Third Paints.
- **Hint:** The king wears paint where the cards agree: both have it, or both lack it. Find what only card A has and what only card B has, then ask a Third Paint what neither of those has. (To find what only B has: ask a Third Paint of card A and of what neither card has.)
- Notes: designer's title. No longer an invention level (two per chapter). Three sentences; the panel has room.

---

## Chapter 5, The Looking Glass

### 38 The Black Pawn · Missing From Either (`missing_from_either`, invention)
- **Goal:** Weave the black pawn, and invent Missing From Either. *(draft, 2026-10-18: was "Weave the black pawn.")*
- **Hint:** In the looking glass, mixing turns to sieving and black turns to white. Sieve the two cards, then flip what they share.

### 39 *The Black Chess Clock · What They Don't Both Have* (`two_black_pawns`, new 2026-10-06, showcase)
- **Goal:** Weave the black chess clock.
- **Hint:** The chess clock's twin, in the looking glass. Where a card has no paint at all, the cards can't both have anything, so the cloth turns black. Give Missing From Either both cards and tube it to the loom: one piece does what a Sieve and a Flip Pan did.
- Notes: The Chess Clock's twin, both its cards flipped; not guided (The Black Rook isn't either). Waits for Missing From Either. Was Two Black Pawns until 2026-10-17.

### 40 The Black Rook · A Flip Pan, Rebuilt (`missing_twice`)
- **Goal:** Weave the black rook, and build a Flip Pan from Missing From Either.
- **Hint:** The rook's twin, in the looking glass. Split the card and give Missing From Either the same paint twice.

### 41 The Black Queen · Same Paint (`same_paint`, invention)
- **Goal:** Weave the black queen, and invent Same Paint. *(draft, 2026-10-18: was "Weave the black queen.")*
- **Hint:** In the looking glass, the queen wears paint where the cards agree. Mix what the cards share with the opposite of their mix.
- Notes: now the level that invents Same Paint.

### 42 *The Looking-Glass Board · Stripes Agreeing* (`little_black_board`, new 2026-10-06, showcase)
- **Goal:** Weave the looking-glass board.
- **Hint:** The chessboard's twin, in the looking glass: the same two cards, and every square swapped. Where a column is white, Same Paint flips the row's paint; where it is black, it keeps it. Give Same Paint both cards and tube it to the loom.
- Notes: the same two cards as The Chessboard; the corners come out green. Same Paint costs 3, so ★★★ is 3. Waits for Same Paint. Was The Little Black Board until 2026-10-17; the name nods to Through the Looking-Glass, which is a chess game.

### 43 The Black Knight · A Sieve, Rebuilt (`back_to_filter`)
- **Goal:** Weave the black knight, and build a Sieve from Missing From Either.
- **Hint:** Flip what the cards don't both have and you get what they share. Ask Missing From Either, then flip its answer with a second one.

### 44 The Black Bishop · A Mixing Tub, Rebuilt (`mix_without_mix`)
- **Goal:** Weave the black bishop, and build a Mixing Tub.
- **Hint:** What either paint has is what their opposites don't both have. Flip both cards, then ask Missing From Either.

### 45 *The Black Trophy · Only the Blue Flipped* (`the_black_crown`, new 2026-10-06)
- **Goal:** Weave the black trophy.
- **Hint:** The trophy's twin, in the looking glass: the card is the black trophy with every paint's blue flipped. Same Paint keeps what agrees, so ask it about the card and an orange pot, which holds everything but blue.
- Notes: ★★★ 4 (Same Paint 3 and the orange pot 1; the solver also finds a 4 with Missing From Either). Was The Black Crown until 2026-10-17.

### 46 The Black King · Extreme Mix (`only_missing`)
- **Goal:** Weave the black king using only Missing From Either.
- **Hint:** The king's twin wears paint from one card alone. Ask Missing From Either of the two cards, then of each card with that answer, then of the two answers.
- Notes: machine phrase as level 32's (Extreme Mix, the invention it rebuilds), the king and queen trading rules across the looking glass, as the levels already do.

---

## Lost Levels

- **Flip Side** (`flip_side`): The Beach Flags · Every Mix Flipped. Hint: "On the beach, every flag flips to the one paint it lacks. Tube the card through the Flip Pan."
- **The Harbour** (`the_flower`): The Harbour · Two of Three. Hint: "Gulls, sails and the quay, each on two of three cards. Sieve each pair of cards, then mix the three answers." Until chapter 6 earns its rule as Consensus.
- **The Big Board** (`chessboard`, made up 2026-10-06 to try the largest cards, 12 by 9; was The Chessboard until 2026-10-17, when chapter 3's 8×8 board took the name): The Big Board · Flip, Then Sieve. Hint: "On the black squares card A is black and card B is bare. On the white squares the two agree. Flip card B to its opposite, then sieve it with card A." A black and white cloth woven from `Filter(A, Invert B)` (Flip Pan and Sieve only; the card maker's "bleach" rule); a Lost Level, played only from the command line (`.make level chessboard`).

---

## Text outside the level files (decided 2026-10-05)

- **Locked tag** (a level waiting for an invention): "Earn the Third Paint in 29. The Pawn." (30, 31, 34, 37); "Earn Extreme Mix in 32. The Queen." (33); "Earn Missing From Either in 38. The Black Pawn." (39, 40, 43, 46); "Earn Same Paint in 41. The Black Queen." (42).
- **The ★★★ price line** (decision 9, designer 2026-10-18; DESIGN.md §9.1): on the hint panel under the hint, and on the success panel after a run that misses ★★★, where a pot or invention costs the player more than the level's ★★★ allows (`star_needs`, written by `.\make solve`): "Your Third Paint costs 2. Three stars on 29. The Pawn bring it down to 1." A line per invention; a pot in lowercase ("Your yellow pot costs 2. Three stars on 2. The Yellow Pot bring it down to 1."). Levels with `star_needs` today: 3, 4, 5, 8, 10, 12 to 14, 16, 20, 30 to 37, 39, 40, 42 to 44, 46.
- **"★★★ needs the invention" notice:** dropped. 32 and 33 open only from 30 or 31, and 38 only from 36 or 37, which all wait for the invention, so the player always owns it there (a cheat lends it).
- **"New in your journal":** cheaper: "Orange pot: cheaper, 2 → 1". A new chapter: "A new chapter: Invent What You Know", with its first level's tag. Opens: "The Third Paint opens 30. The Chess Clock and 31. The Rook." (levels the invention opens beyond the usual next two).
- **The paint-card line on each piece page** (DESIGN.md §9.1), unlocking with the page:
  - Mixing Tub: "On the paint card, a mix sits between its two paints: red and yellow meet at orange."
  - Sieve: "On the paint card, the Sieve keeps the corners two paints share: orange and purple share red."
  - Flip Pan: "On the paint card, a paint's opposite sits straight across black."
  - Shift Wheel: "On the paint card, follow one arrow: every paint moves one corner on."
  - The red pot and Split: none (one rule each).
- **The lexicon's Gameplay texts in critter names:** written at the rebuild, when the rename is built, then `.\make words`.
- **Historical notes** (2026-10-18; DESIGN.md §5.7): the dashed tag on a quilt not yet full, "Sew in every cloth to read this note."; the open note's foot, "Pinned to the quilt of The Paint Box."; "New in your journal", "A note from history: The Paper Strip" over "Pinned to the quilt of The Paint Box, on Cloths." The notes' own texts are in "Historical notes" below.
- **Lost Levels**, the line under its name: "Levels that wandered off the campaign. They still weave." How it's found and laid out stays open (DESIGN.md §5.1).

---

## Historical notes *(first draft, 2026-10-18)*

The shape is decided (designer, 2026-10-18; DESIGN.md §5.7): one note per chapter, unlocked by completing the chapter's quilt (never blocking), pinned to the quilt on the Cloths tab as a paper tag and announced by "New in your journal"; 3 or 4 sentences and one picture drawn in code. The line-up keeps the dates in order and matches a note to its chapter's idea where it can. The designer took the texts as they are for now (2026-10-18), to improve in a later round. The notes of the built chapters are in the game: `levels/index.json` carries them as the game uses them (a `note` per chapter), as the level files carry the level text.

Each note has a title (the tag's line), a year, the text, and the picture. The pictures are wood, paper, thread and ink in the workshop's neutrals, never the eight paints' hues (CLAUDE.md, reserved colours). Under each, **Checked** lists the facts and where they were checked; **Left out** is what was true but didn't fit. The planned chapters' notes are provisional until those chapters are built; Plates' is open. The re-org in fours (2026-10-18) put Bargain Pots second; its note is a draft out of date order until the history notes pass reorders the line-up.

### Chapter 1, The Paint Box: The Paper Strip (1725)
- **Text:** In the silk town of Lyon, weaving a pattern was slow: before every pass of the shuttle, a helper had to pull the cords of the right threads by hand. In 1725 Basile Bouchon, whose father built organs, gave the loom a long strip of paper punched with holes instead. The holes chose which threads would lift, one row of holes for each row of cloth. For the first time, a loom read its own pattern.
- **Picture:** a paper strip with rows of holes, curling off a wooden roller into a loom's frame.
- **Checked:** Lyon silk trade, 1725, the perforated paper roll, his father an organ maker (Wikipedia, "Basile Bouchon"; History of Information); needles in a box raised or left down by the tape's holes, the drawloom's cords pulled by hand before (Grace's Guide, "Basile Bouchon"). "Read its own pattern" stands for "the first industrial use of a semi-automated machine" (History of Information).
- **Left out:** the helper's name, the *drawboy* (often a child): the usual term, but not in the sources checked here. Which way a hole works (lift or stay down): the sources word it awkwardly, so the text doesn't say.

### Chapter 2, Bargain Pots: A Cheap Purple (1856) *(draft, 2026-10-18; out of date order until the history notes pass)*
- **Text:** For two thousand years purple was the dearest dye there was: Tyrian purple was squeezed from thousands of sea snails, and only emperors could afford to wear it. In 1856 William Henry Perkin, an 18-year-old student trying to make a medicine at home, found a purple dye in coal tar instead. He called it mauve, and his factory made it by the barrel, cheaply. Within a few years anyone could wear purple, and chemists set out to make every dye that way.
- **Picture:** a corked glass flask of ink-dark dye on the bench, a skein of dyed silk hanging to dry beside it (ink and paper tones: never the purple paint's hue).
- **Checked:** not yet. The draft goes by well-known facts (Perkin, aged 18, looking for a way to make quinine in his home laboratory in 1856; mauveine from aniline, a coal-tar product; his works at Greenford; Tyrian purple from murex snails, worn by emperors). The history notes pass checks each against sources.
- **Fit:** a bargain pot exactly: the dearest paint made cheap by a new way of making it.

### Chapter 3, Pattern Cards: Cards on a Chain (1728)
- **Text:** A paper strip is hard to change once it's punched. In 1728 Jean-Baptiste Falcon, who worked with Bouchon, cut the pattern into cards and laced them together in a chain. A card could be mended, swapped or moved without punching the whole pattern again. Your pattern cards carry the same idea: the picture comes into the machine on a card.
- **Picture:** a chain of punched cards laced at their edges, folding over itself like a paper fan.
- **Checked:** 1728, a chain of punched cards in place of Bouchon's tape, "to make the input of instructions more flexible" (Wikipedia, "Basile Bouchon"; Grace's Guide, "Jean-Baptiste Falcon"); Jacquard later used "Falcon's individual pasteboard cards" (Wikipedia, "Jacquard machine").
- **Left out:** whether Falcon was Bouchon's assistant or his colleague (sources differ, hence "worked with").

### Chapter 4, Invent What You Know: Jacquard's Loom (1804)
- **Text:** Joseph-Marie Jacquard, a Lyon weaver's son, built his loom out of what others had found. In Paris he studied a loom by Jacques de Vaucanson, the maker of a famous mechanical duck, and joined its ideas to Falcon's chain of cards. His loom of 1804 let one weaver weave the richest pattern with no helper at the cords. By 1812 some 11,000 of them were working in France.
- **Picture:** the Jacquard head, a wooden box on top of a loom, with its chain of cards draping down beside it.
- **Checked:** patented 1804 (Wikipedia, "Jacquard machine"); attached to the Conservatoire des Arts et Métiers in Paris in 1803, where Vaucanson's loom "suggested various improvements" (Wikipedia, "Joseph Marie Jacquard", quoting the 1911 Britannica); Vaucanson's loom replaced by cards, "generally similar to Vaucanson's arrangement" (Wikipedia, "Jacquard machine"); the Digesting Duck, 1738 (Wikipedia, "Jacques de Vaucanson"); 11,000 looms in France by 1812 (Encyclopedia.com, "Jacquard's Loom"). His father Jean Charles Jacquard, a master weaver of Lyon (Wikipedia, "Joseph Marie Jacquard"; ERIH).
- **Left out:** Vaucanson's year (1745 in most sources, 1740 in some), hence no year. The silk weavers' fight against the loom (it was hanged in effigy, a crowd resolved to break the looms), Napoleon handing the patent to the city of Lyon in 1805 with a pension for Jacquard: true, but a fourth sentence too many.

### Chapter 5, The Looking Glass: The Woven Portrait (1839)
- **Text:** In 1839 a Lyon workshop wove a portrait of Jacquard on one of his own looms, from some 24,000 cards. It was silk in black, white and every grey between, and so fine that two members of London's Royal Academy took it for an engraving. Charles Babbage, who was designing a calculating machine that would read cards, hung a copy in his home and showed it to his visitors.
- **Picture:** a framed grey portrait of a man in a dark coat, hung on a nail, with a few punched cards tucked behind the frame.
- **Checked:** 1839, woven by Michel-Marie Carquillat for Didier, Petit et Cie of Lyon, about 24,000 cards (Linda Hall Library; Metropolitan Museum, via Bonhams; History of Information); "mistaken for such by two members of the Royal Academy", Babbage's own words in *Passages from the Life of a Philosopher*, 1864 (quoted in Essinger, *Jacquard's Web*); Babbage wanted a copy for his London home in December 1839 and showed it to the Duke of Wellington and Prince Albert around 1842 (Science History Institute, "The French Connection"); the Analytical Engine read punched cards. The greys: from the portrait itself (it imitates an engraving); no source checked says it in words.
- **Left out:** Wellington taking it for an engraving and Prince Albert putting him right: a magazine's telling, with no primary source found. That the portrait gave Babbage his cards: he chose cards before 1839, so the text only says he was designing a machine that read them.

### Asking Questions *(provisional, a planned chapter)*: Weaving Patterns of Numbers (1843)
- **Text:** In 1843 Ada Lovelace wrote about Charles Babbage's Analytical Engine, a machine he had designed to follow punched cards as Jacquard's loom does. "The Analytical Engine weaves algebraical patterns," she wrote, "just as the Jacquard-loom weaves flowers and leaves." She saw that it could work on more than numbers: given the rules of music, it might even compose. The engine was never built, but her notes are still read today.
- **Picture:** an open notebook with a quill, a lace of punched cards for a bookmark.
- **Checked:** 1843, her notes to her translation of Menabrea's article on the Analytical Engine; the quotation (Note A; "We may say most aptly, that ..." before it in full; public domain); the engine's use of cards for numbers and instructions (Columbia University Computing History); composing music, Note A ("might compose elaborate and scientific pieces of music of any degree of complexity or extent", if the rules of harmony could be written in its notation; Yale, "Ada Lovelace's Notes").
- **Left out:** her program for the Bernoulli numbers (Note G), often called the first program: true, but needs explaining. "Algebraical" is a hard word for a young player; the quotation could stop at "weaves patterns ... just as the Jacquard-loom weaves flowers and leaves".
- **Fit:** weak for Asking Questions. A better fit for the chapter (the engine looking at a result and choosing its next cards) is Babbage's, and Chromaton 2's frame; revisit when chapter 5 is planned.

### Choosing *(provisional, a planned chapter)*: The Sorting Box (1890)
- **Text:** Counting the people of the United States in 1880 took clerks about eight years. For 1890 Herman Hollerith punched each person's answers into a card: their age, their work, where they lived. His machine read a card in a moment and opened the lid of one box in its sorting cabinet, choosing where that card should go. The count of 62,622,250 people was finished that same year.
- **Picture:** a wooden cabinet of small boxes, one lid standing open, a punched card halfway in.
- **Checked:** the 1880 census took eight years (Wikipedia, "Tabulating machine"); the sorter, an oak box of 26 compartments with brass lids held shut by electric catches, one opening when its card was read (Smithsonian, "Hollerith Card Sorter"); the 1890 count finished on 12 December 1890 at 62,622,250 (Franklin Institute, "Case Files: Herman Hollerith").
- **Left out:** that the first rough count was ready in about six weeks (often told, not checked). That Hollerith's company grew into IBM.

### Plates *(open, a planned chapter)*
- To choose when Plates is planned (several looms, one machine sharing its parts between them). Candidates, unchecked: Henry Babbage, Charles's son, building part of the Analytical Engine's mill around 1910; punched cards everywhere in the 20th century. Neither is checked yet.

### Counting *(provisional, a planned chapter)*: The Engine That Waited (1991)
- **Text:** By 1849 Charles Babbage had drawn his Difference Engine No. 2, a machine that works out long tables of numbers by nothing but adding. It was never built while he lived. In 1991, two hundred years after his birth, London's Science Museum built it from his drawings: 4,000 parts of iron, steel and bronze. It worked.
- **Picture:** a tall frame of brass columns of number wheels, a crank handle on its side.
- **Checked:** designed 1847 to 1849; the calculating section finished in 1991 for the bicentenary of his birth (born 1791), 4,000 parts, 2.6 tonnes, iron, steel and bronze; the printer added later (Science Museum Group collection, "Difference Engine No. 2"; Computer History Museum, "A Modern Sequel"). "Nothing but adding": the method of differences, "a difference engine only needs to be able to add" (Wikipedia, "Difference engine"). "It worked": "The completed machine works as Babbage intended" (Computer History Museum).
- **Left out:** the museum had to draw new plans for each part, Babbage's twenty drawings not being detailed enough to make parts from (Computer History Museum). The printer's year (2000 or 2002, sources differ). The first Difference Engine (1822 on) and the piece of it finished in 1832.
