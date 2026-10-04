# Paint

- **Tags:** gameplay, design, implementation
- **Status:** ✅ (the eight paints and how they mix, DESIGN.md §2.1; "paint", not "color", everywhere the player looks)
- **Journal:** unlocks in One Pot of Red; page on the Paint tab
- **Also called:** color (the code's and the algebra's word), colour

## Gameplay

There are eight paints. Red, yellow and blue mix into all the others: red and yellow make orange, and all three together make black. No paint at all is white, the bare cloth. More of the same paint changes nothing.

## Design

| Paint | Holds | Opposite |
|---|---|---|
| White | no paint | Black |
| Red | red | Green |
| Yellow | yellow | Purple |
| Orange | red, yellow | Blue |
| Blue | blue | Orange |
| Purple | red, blue | Yellow |
| Green | yellow, blue | Red |
| Black | red, yellow, blue | White |

- A paint is which primaries it holds, never how much. Paint mixes like pigment, not light: more paint is darker.
- A paint's opposite holds exactly the primaries it lacks: the complementary colors of art class.
- The order above is the journal order: threads, the Pattern Book's paint shelf and the journal list paints in it.
- Every drop wears glyph dots, one place per primary (red on top, yellow lower right, blue lower left), filled for the primaries it holds; white is a hollow, dashed drop. Always on.
- The eight signal hues are reserved for paint. Decorative art and UI never use them (DESIGN.md §7.1).
- Only the red pot is given; every other paint is earned as a pot in the Paint Box chapter (DESIGN.md §5.1).
- Players say paint; the designer and the code may say color. Text on screen says paint (level names included).

## Implementation

`core/paint.gd`: `WHITE` … `BLACK` (0–7), each paint stored as red, yellow and blue flags; the numbers never reach the player. Level files write paints as letters, `W R Y O B P G K` (`core/level.gd`). Drawn by `drop`, `pips` and `swatch` in `ui/draw_kit.gd`.

## Related

[Paint card](paint-card.md) · [Critter](critter.md) · [Journal](journal.md)

## Open questions

- Playtesters asked "why do red, yellow and blue make black?" and how the dark paints are made. The paint card answers on the bench; the journal's Paint page is the longer read.
