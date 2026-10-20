# Any Paint?

- **Tags:** gameplay, design, implementation
- **Status:** 🟡 (working name; the inventions' names are open in package C)
- **Journal:** unlocks in The Rabbit, the level that invents it; page on the Pieces tab

## Gameplay

Any Paint? asks one question of a paint: is there any paint at all? It answers black for yes and white for no, so a picture comes out as its shadow.

## Cases

- Red → Black: red is a paint, so the answer is yes.
- Green → Black: any mix counts as paint too.
- Black → Black: every paint at once is still paint.
- White → White: white is no paint at all, so the answer is no.

## Design

- The first question (DESIGN.md §5.1): earned in The Rabbit, the first level of Asking Questions (chapter 7), shown off in The Dove, then flipped in The Moon (Is It White?) and fed a sieved card in The Fox (Any Red?). The Harbour Cat weaves the same machine before it has a name: a paint mixed with its two turns.
- Its looking-glass twin is [Is It Black?](is-it-black.md): Any Paint? mixes a paint's turns, Is It Black? sieves them.

## Implementation

The check `any_paint` in `core/invention.gd`; invention id `any_paint`. One input, so its case rows have one paint in. The solver and the card maker build it as `A | Shift(A) | Shift(Shift(A))` on their packed stitches (`tools/level_solver.gd`, `tools/functions.gd`); the card rules `any_paint` and `is_white` (`tools/make_cards.gd`).

## Related

[Invention](invention.md) · [Is It Black?](is-it-black.md) · [Mix](mix.md) · [Shift](shift.md)
