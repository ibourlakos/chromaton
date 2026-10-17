# Third Paint

- **Tags:** gameplay, design, implementation
- **Status:** 🟡 (working name; the inventions' names are open in package C)
- **Journal:** unlocks in The Pawn, the level that invents it; page on the Pieces tab

## Gameplay

The Third Paint mixes two paints and gives back the opposite: whatever neither of them has.

## Cases

- Red + Yellow → Blue: blue is the one neither has.
- Orange + Red → Blue: what both have doesn't matter; blue is still missing.
- Red + Red → Green: the same paint twice gives its opposite.
- Purple + White → Yellow: white has nothing, so out comes the other paint's opposite.
- Orange + Blue → White: between them they have everything, so nothing is left.
- White + White → Black: neither has anything, so out comes everything.

## Design

- The first invention that isn't a pot (DESIGN.md §5.1), earned in The Pawn, chapter 3's first level; owning it opens The Chess Clock and The Rook.
- Back to Mix rebuilds the Mixing Tub from two Third Paints.

## Implementation

The check `third_paint` in `core/invention.gd` (the opposite of a mix); invention id `third_paint`. Case rows as for [Contrast](contrast.md).

## Related

[Invention](invention.md) · [Mix](mix.md) · [Invert](invert.md)
