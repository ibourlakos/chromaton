# Filter

- **Tags:** gameplay, design, implementation
- **Status:** ✅ two names (designer, 2026-10-05): the term is the algebra's and the code's name; the player sees the critter's name
- **Player word (decided 2026-10-05, not built):** Sieve. It becomes the Player word, and the Gameplay text uses it, when the rename is built (then `.\make words`).
- **Journal:** unlocks in Sandy Crab; page on the Pieces tab

## Gameplay

Filter takes two paints and keeps only what they share. Orange and purple share red, so out comes red. Two paints that share nothing give white.

## Design

- A fussy, heavy-lidded tub with a sieve in its rim that shakes when it fires; grains of held-back paint hop on the rim.
- With a pot it works as a mask: Filter a card with Red and only the card's red is left (Sandy Crab, where the yellow on the card is sand).
- A starting critter (the middle kit, DESIGN.md §2.5). First offered in Sandy Crab (level 16). Keep What They Share holds it back so the player rebuilds it from Invert and the Third Paint; Back to Filter rebuilds it from two Missing From Eithers.
- Price 1.

## Implementation

`"filter"` in `core/pieces.gd`; `Paint.filter` in `core/paint.gd`.

## Related

[Critter](critter.md) · [Mix](mix.md) · [Paint](paint.md)

## Open questions

- Its noun name. The function is liked, the name isn't.
