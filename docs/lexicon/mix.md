# Mix

- **Tags:** gameplay, design, implementation
- **Status:** ✅ two names (designer, 2026-10-05): the term is the algebra's and the code's name; the player sees the critter's name; the player word built 2026-10-05
- **Player word:** Mixing Tub
- **Journal:** unlocks in The Orange Pot; page on the Pieces tab

## Gameplay

The Mixing Tub takes two paints and gives back everything in either one. Red and yellow make orange; orange and blue make black. Mixing in a paint that's already there changes nothing.

## Design

- A wooden tub that stirs with a spoon; the paint swirls into the new paint.
- First offered in Orange (level 4). Back to Mix rebuilds it from two Third Paints; Mix Without Mix holds it back so the player rebuilds it from Invert and Missing From Either.
- Price 1.

## Implementation

`"mix"` in `core/pieces.gd`; `Paint.mix` in `core/paint.gd`.

## Related

[Critter](critter.md) · [Filter](filter.md) · [Paint](paint.md)
