# Invert

- **Tags:** gameplay, design, implementation
- **Status:** ✅ two names (designer, 2026-10-05): the term is the algebra's and the code's name; the player sees the critter's name
- **Player word (decided 2026-10-05, not built):** Flip Pan (first decided as Flip Tub, changed the same day: a pan that flips paint like an omelette). It becomes the Player word, and the Gameplay text uses it, when the rename is built (then `.\make words`).
- **Journal:** unlocks in Green; page on the Pieces tab (Opposites fills it at once)

## Gameplay

Invert turns a paint into its opposite. Red becomes green, yellow becomes purple, blue becomes orange, and white becomes black. Invert it again and you're back where you started.

## Design

- A tub that flips like a pancake; the paint lands as its opposite. (Decided 2026-10-05, not built: it becomes the Flip Pan, a frying pan that tosses the drop like an omelette so it lands on its other side; DESIGN.md §7.2.) During the first half of the flip it shows the paint it got.
- The opposite holds exactly the primaries the paint lacks, so the dots flip: filled dots empty and empty ones fill.
- First offered in Green (level 7). Opposites weaves a swatch through it, every row all eight paints in a different order. Neither, Twice rebuilds it from the Third Paint, Missing, Twice from Missing From Either.
- Price 1. Idea from the playtest: a gerbil that shaves the input off a black paint.

## Implementation

`"invert"` in `core/pieces.gd`; `Paint.invert` in `core/paint.gd`.

## Related

[Critter](critter.md) · [Paint](paint.md) · [Paint card](paint-card.md)
