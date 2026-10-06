# Pattern card

- **Tags:** gameplay, design, implementation
- **Status:** ✅ (the word since the prototype; its word and page, designer, 2026-10-05; built 2026-10-05)
- **Journal:** unlocks in The Sailboat, the level that brings the first card; page on the Loom tab
- **Also called:** card, input card

## Gameplay

A pattern card holds a picture as paint, one drop for every stitch, laid out like the cloth: left to right, row by row. It lets its drops out one at a time, in order; the ones already let out fade, and a little shuttle stands before the one that comes next. Tube it to a piece, or straight to the loom.

## Design

- The program, or input buffer, of the loom (DESIGN.md §4): the Jacquard loom's punched cards. Cards sit on the workshop's left edge, covering the first two cells of their rows (wider for a picture of more than 8 columns, and as tall as the picture, so rows 1 to 5; a picture is 4 to 12 columns by 1 to 9 rows, 8 by 6 by default), so paint always enters on the left. A card is the loom cloth's counterpart (Path B, 2026-10-06): the machine turns the pictures on its cards into a result cloth, which hints at an image algebra without naming it.
- A wrong machine fails visibly within `card_shows` stitches (DESIGN.md §5.1): 4 to 10 per level, the fewest that fail every wrong machine within the two-star budget. The player sees the whole card (2026-10-06, Path B); the number is the solver's decode depth, not a window.
- A level with several cards names them A, B, C; the letter, not the row, orders an invention's input ports.

## Implementation

- `core/level.gd` (`cards`, `card_names`, `card_shows`), drawn by `ui/draw_kit.gd` (`card_body` the whole picture, `card_paints` the faded drops, the shuttle and the ringed drop); derived from the target picture by `tools/make_cards.gd`, checked by `tools/level_solver.gd`.

## Related

[Loom](loom.md), [Shuttle](shuttle.md), [Stitch](stitch.md), [Tube](tube.md)
