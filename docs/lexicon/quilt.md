# Quilt

- **Tags:** gameplay, design, implementation
- **Status:** ✅ (designer, 2026-10-04: a chapter's cloths join into a quilt)
- **Journal:** unlocks in The White Pot, the paint box's last level; page on the Cloths tab
- **Also called:** tapestry (kept for the finale), patchwork

## Gameplay

Weave every cloth in a chapter and they're sewn together into a quilt. Your quilts hang beside your cloths in the journal.

## Design

- The chapter payoff (DESIGN.md §4): each level weaves one cloth; finishing a chapter joins them. "Tapestry" stays free for the finale's woven picture.
- The paint box's nine single-row cloths stack into a square-ish block of the paints, the first quilt. Every other chapter has a multiple of three levels and a fixed number of patches across (chapter 2: 4 across × 3 down, its pictures all 4:3; chapters 3 and 4: 3 × 2, chess pieces on 8×8, the two quilts a pair in opposite paints), so each quilt fills its grid (designer's chapter plan, 2026-10-05).
- On the Cloths tab each chapter's quilt hangs beside its cloths. Until the chapter is done, its patches fill in one by one and the rest stay empty.

## Implementation

Drawn by `DrawKit.quilt` from the solved levels' targets (no save data): a chapter whose cloths are all single threads of one width stacks them; any other chapter sews each cloth into an equal patch, as many across as its `quilt_across` in `levels/index.json`.

## Related

[Cloth](cloth.md) · [Thread](thread.md) · [Journal](journal.md)
