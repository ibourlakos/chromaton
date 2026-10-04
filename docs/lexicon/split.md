# Split

- **Tags:** gameplay, design, implementation
- **Status:** 🟡
- **Journal:** unlocks in Purple; page on the Pieces tab
- **Also called:** tube split, junction

## Gameplay

Split copies paint: one drop goes in, and the same paint comes out of both spouts. It's free, so it never counts toward your pieces.

## Design

- Plumbing, not a critter: a small junction with no face. Free, so any result can feed as many pieces as it likes; the solver relies on that.
- Teaches in Purple: two pots is ★★, splitting one pot's paint is ★★★.

## Implementation

`split` in `core/pieces.gd` (op `copy`, one input, two outputs, cost 0); drawn by `DrawKit.split`.

## Related

[Piece](piece.md) · [Tube](tube.md)
