# Mix

- **Tags:** gameplay, design, implementation, temporary (a verb; noun names are wanted but deferred)
- **Status:** 🟡
- **Journal:** unlocks in Orange; page on the Pieces tab

## Gameplay

Mix takes two paints and gives back everything in either one. Red and yellow make orange; orange and blue make black. Mixing in a paint that's already there changes nothing.

## Design

- A wooden tub that stirs with a spoon; the paint swirls into the new paint.
- First offered in Orange (level 4). Mix Without Mix holds it back so the player rebuilds it from Filter and Invert.
- Price 1.

## Implementation

`"mix"` in `core/pieces.gd`; `Paint.mix` in `core/paint.gd`.

## Related

[Critter](critter.md) · [Filter](filter.md) · [Paint](paint.md)
