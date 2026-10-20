# Missing From Either

- **Tags:** gameplay, design, implementation
- **Status:** 🟡 (working name; the inventions' names are open in package C)
- **Journal:** unlocks in The Black Pawn, the level that invents it; page on the Pieces tab

## Gameplay

Missing From Either gives whatever one paint or the other lacks: the opposite of what the Sieve keeps.

## Cases

- Orange + Purple → Green: they share red; yellow and blue are each missing from one of them.
- Red + Yellow → Black: they share nothing, so everything is missing from one or the other.
- Blue + Blue → Orange: the same paint twice gives its opposite.
- Green + White → Black: white lacks everything.
- Purple + Black → Yellow: black lacks nothing, so out comes the other paint's opposite.

## Design

- An invention (DESIGN.md §5.1), earned in The Black Pawn, the first level of The Looking Glass, the looking-glass twin of The Pawn's Third Paint.
- Back to Filter rebuilds the Sieve from it; Mix Without Mix rebuilds the Mixing Tub from it and the Flip Pan.

## Implementation

The check `missing_from_either` in `core/invention.gd` (the opposite of a Sieve); invention id `missing_from_either`. Case rows as for [Contrast](contrast.md).

## Related

[Invention](invention.md) · [Filter](filter.md) · [Invert](invert.md)
