# Contrast

- **Tags:** gameplay, design, implementation
- **Status:** ✅ two names (designer, 2026-10-05): Contrast is the algebra's and the code's name; the player sees Extreme Mix
- **Player word:** Extreme Mix
- **Journal:** unlocks in The Queen, the level that invents it; page on the Pieces tab

## Gameplay

Extreme Mix mixes two paints, but whatever they share washes out.

## Cases

- Red + Yellow → Orange: they share nothing, so it's a plain mix.
- Orange + Red → Yellow: the red they share washes out.
- Green + Green → White: the same paint twice shares everything, so nothing is left.
- Purple + White → Purple: white brings nothing, so nothing changes.
- Orange + Black → Blue: with black, any paint turns into its opposite, as on the Flip Pan.
- Green + Blue → Yellow: with blue, blue comes out if it was there and goes in if it wasn't.

## Design

- An invention (DESIGN.md §5.1), earned in The Queen, the third level of Invent What You Know. Its reference machine is two Third Paints and a Sieve.
- The Black row is The Crown's idea and the Blue row The Little Board's; the journal may give them away (designer, 2026-10-08: journal spoilers are fine).
- The R4 note's seventh row, Purple + Green → Orange (the shared blue washes out), is the same kind as Orange + Red, so it's left out (one row per kind of pair, 4 to 6 rows).

## Implementation

The check `contrast` (`Paint.contrast` in `core/paint.gd`); invention id `contrast`. Its case rows are the Cases section above, written into `data/words.json` by `.\make words`; the journal test checks each row's answer against the invention.

## Related

[Invention](invention.md) · [Mix](mix.md) · [Invert](invert.md)
