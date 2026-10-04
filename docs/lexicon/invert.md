# Invert

- **Tags:** gameplay, design, implementation, temporary (a verb; noun names are wanted but deferred)
- **Status:** 🟡
- **Journal:** unlocks in Green; page on the Pieces tab (Opposites fills it at once)

## Gameplay

Invert turns a paint into its opposite. Red becomes green, yellow becomes purple, blue becomes orange, and white becomes black. Invert it again and you're back where you started.

## Design

- A tub that flips like a pancake; the paint lands as its opposite. During the first half of the flip it shows the paint it got.
- The opposite holds exactly the primaries the paint lacks, so the dots flip: filled dots empty and empty ones fill.
- First offered in Green (level 7). Opposites weaves one thread of all eight paints through it.
- Price 1. Idea from the playtest: a gerbil that shaves the input off a black paint.

## Implementation

`"invert"` in `core/pieces.gd`; `Paint.invert` in `core/paint.gd`.

## Related

[Critter](critter.md) · [Paint](paint.md) · [Paint card](paint-card.md)
