# Quilt

- **Tags:** gameplay, design, implementation
- **Status:** ✅ (designer, 2026-10-04: a chapter's cloths join into a quilt)
- **Journal:** unlocks in The White Pot, the paint box's last level; page on the Cloths tab
- **Also called:** tapestry (kept for the finale), patchwork

## Gameplay

Weave every cloth in a chapter and they're sewn together into a quilt. Your quilts hang beside your cloths in the journal.

## Design

- The chapter payoff (DESIGN.md §4): each level weaves one cloth; finishing a chapter joins them. "Tapestry" stays free for the finale's woven picture.
- The paint box's eight single-row cloths stack into a square sampler of the paints, the first quilt, and Bargain Pots' eight hang as its pair, the cheap box beside the dear one, stacked in the paint box's paint order so the two match row for row (designer, 2026-10-18). Every other chapter has a multiple of four levels (three until 2026-10-18) and a fixed number of patches across, so each quilt fills its grid (chapter plan, 2026-10-05). Pattern Cards became Swatches (2 × 2) and Pictures (4 × 2), built 2026-10-19. The chess quilts went 4 × 2 on 2026-10-20, hung one above the other as a board on both chess pages of the Cloths tab (DESIGN.md §5.1).
- On the Cloths tab each chapter's quilt hangs beside its cloths. Until the chapter is done, its patches fill in one by one and the rest stay empty.

## Implementation

Drawn by `DrawKit.quilt` from the solved levels' targets (no save data): a chapter whose cloths are all single threads of one width stacks them; in level order, or in paint order with `"quilt_order": "paint"` (Bargain Pots); any other chapter sews each cloth into an equal patch, as many across as its `quilt_across` in `levels/index.json`.

## Related

[Cloth](cloth.md) · [Thread](thread.md) · [Journal](journal.md)
