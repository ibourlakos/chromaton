# Same Paint

- **Tags:** gameplay, design, implementation
- **Status:** 🟡 (working name; the inventions' names are open in package C)
- **Journal:** unlocks in The Black Queen, the level that invents it; page on the Pieces tab

## Gameplay

Same Paint keeps what two paints agree on: what both have and what both lack.

## Cases

- Red + Red → Black: the same paint twice agrees on everything.
- Red + Yellow → Blue: they agree only on lacking blue.
- Orange + Red → Purple: both have red and both lack blue; they disagree on yellow.
- Green + Black → Green: with black, a paint stays as it is.
- Green + White → Red: with white, a paint turns into its opposite.
- Red + Green → White: opposites agree on nothing.

## Design

- An invention (DESIGN.md §5.1), earned in The Black Queen, the looking-glass twin of The Queen's Extreme Mix: Same Paint is Extreme Mix's opposite.

## Implementation

The check `same_paint` in `core/invention.gd` (the opposite of Contrast); invention id `same_paint`. Case rows as for [Contrast](contrast.md).

## Related

[Invention](invention.md) · [Contrast](contrast.md) · [Invert](invert.md)
