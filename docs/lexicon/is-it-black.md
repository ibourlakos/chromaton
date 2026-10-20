# Is It Black?

- **Tags:** gameplay, design, implementation
- **Status:** 🟡 (working name; the inventions' names are open in package C)
- **Journal:** unlocks in The Owl, the level that invents it; page on the Pieces tab

## Gameplay

Is It Black? asks one question of a paint: is it every paint at once? It answers black for yes and white for no, so only the darkest spots of a picture come through.

## Cases

- Black → Black: every paint at once, so the answer is yes.
- Purple → White: red and blue, but no yellow, so the answer is no.
- Red → White: one paint is far from all three.
- White → White: no paint at all is the furthest from black.

## Design

- The second question of Asking Questions (chapter 7, DESIGN.md §5.1): earned in The Owl, shown off in The Bat, then used in The Castle (Contains?, on a mix with a flipped card) and The Dragon (Same Color?, on Same Paint's answer).
- The looking-glass twin of [Any Paint?](any-paint.md): where Any Paint? mixes a paint with its two turns, Is It Black? sieves them.

## Implementation

The check `is_black` in `core/invention.gd`; invention id `is_black`. One input. The solver and the card maker build it as `A & Shift(A) & Shift(Shift(A))`; the card rules `is_black`, `has_red`, `contains` and `same_color` feed its levels (`tools/make_cards.gd`).

## Related

[Invention](invention.md) · [Any Paint?](any-paint.md) · [Filter](filter.md) · [Shift](shift.md)
