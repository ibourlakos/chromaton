# Stitch

- **Tags:** gameplay, design, implementation
- **Status:** 🟡
- **Journal:** unlocks in One Pot of Red; page on the Loom tab

## Gameplay

A stitch is one square of a cloth. The loom weaves one stitch from each drop it takes, row by row, left to right. If a stitch comes out wrong, the loom stops and shows you which one.

## Design

- The loom takes at most one drop a tick, so one stitch a tick.
- Unwoven stitches are sunken slots, darker than the cloth, each with a faint chip of the paint it wants; woven stitches carry no glyph dots (🟡), and the wrong-stitch bubble compares the two drops with dots.
- A pattern card holds paint for every stitch. (Smudges, stitches of a card marked as stray paint, were dropped, designer 2026-10-05: a paint with another mixed in is just a paint.)

## Implementation

`core/simulator.gd`: `woven` (the stitches so far), `target`, `wrong_index` (the first wrong stitch).

## Related

[Cloth](cloth.md) · [Thread](thread.md) · [Tick](tick.md)
