# Split

- **Tags:** gameplay, design, implementation
- **Status:** 🟡
- **Journal:** unlocks in The Purple Pot; page on the Pieces tab
- **Also called:** tube split, junction. Split is both its algebra name and its player word (designer, 2026-10-05: kept; a plumbing split is a noun).

## Gameplay

Split copies paint: one drop goes in, and the same paint comes out of both spouts. It's free, so it never counts toward your pieces.

## Design

- Plumbing, not a critter: a small junction with no face. Free, so any result can feed as many pieces as it likes; the solver relies on that.
- Teaches in Purple: two pots is ★★, splitting one pot's paint is ★★★.

## Implementation

`split` in `core/pieces.gd` (op `copy`, one input, two outputs, cost 0); drawn by `DrawKit.split`.

## Related

[Piece](piece.md) · [Tube](tube.md)
