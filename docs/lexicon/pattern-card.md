# Pattern card

- **Tags:** gameplay, design, implementation
- **Status:** ✅ (the word since the prototype; its word and page, designer, 2026-10-05; built 2026-10-05)
- **Journal:** unlocks in The Sailboat, the level that brings the first card; page on the Loom tab
- **Also called:** card, input card

## Gameplay

A pattern card holds a picture as paint, one drop for every stitch. It lets its drops out one at a time, in order, from its right end, and the drops it shows are the next ones coming. Tube it to a piece, or straight to the loom.

## Design

- The program, or input buffer, of the loom (DESIGN.md §4): the Jacquard loom's punched cards. Cards sit on the workshop's left edge, covering the first two cells of their rows, so paint always enters on the left.
- What a card shows decodes the level (designer, 2026-10-05, DESIGN.md §5.1): 4 to 10 drops per level, the fewest that fail every wrong machine within the two-star budget; the rest of the card is ceremony.
- A level with several cards names them A, B, C; the letter, not the row, orders an invention's input ports.

## Implementation

- `core/level.gd` (`cards`, `card_names`, `card_shows`), drawn by `ui/draw_kit.gd` (`card_body`, `card_paints`); derived from the target picture by `tools/make_cards.gd`, checked by `tools/level_solver.gd`.

## Related

[Loom](loom.md), [Stitch](stitch.md), [Tube](tube.md)
