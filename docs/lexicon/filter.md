# Filter

- **Tags:** gameplay, design, implementation, temporary (a playtest called the name "badly failing"; renaming is deferred)
- **Status:** 🟡
- **Journal:** unlocks in Smudges; page on the Pieces tab

## Gameplay

Filter takes two paints and keeps only what they share. Orange and purple share red, so out comes red. Two paints that share nothing give white.

## Design

- A fussy, heavy-lidded tub with a sieve in its rim that shakes when it fires; grains of held-back paint hop on the rim.
- With a pot it works as a mask: Filter a card with Red and only the card's red is left (Smudges).
- A starting critter (the middle kit, DESIGN.md §2.5). First offered in Smudges (level 14). Missing From Either and Keep What They Share hold it back so the player rebuilds it from Mix and Invert.
- Price 1.

## Implementation

`"filter"` in `core/pieces.gd`; `Paint.filter` in `core/paint.gd`.

## Related

[Critter](critter.md) · [Mix](mix.md) · [Paint](paint.md)

## Open questions

- Its noun name. The function is liked, the name isn't.
