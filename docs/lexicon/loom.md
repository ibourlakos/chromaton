# Loom

- **Tags:** gameplay, design, implementation
- **Status:** 🟡 (the world's word, DESIGN.md §3–4)
- **Journal:** unlocks in One Pot of Red; page on the Loom tab
- **Also called:** output (code), weaver

## Gameplay

The loom weaves your cloth. Every tick it takes one drop from its tube and weaves it into the next stitch, row by row, left to right. If a stitch doesn't match the picture, the loom stops and shows where.

## Design

- The machine's only output today: one tube in, one stitch per tick (serial weaving, DESIGN.md §4). Braids that weave a whole row per tick come later.
- Stands on the right of the workbench with the design card above it; a tube can end anywhere on it.
- The journal's Loom tab is about time: the loom, ticks, tubes, stitches and threads.

## Implementation

`Pieces.LOOM`, a fixed node of every machine (`core/machine.gd`); the simulator weaves into `woven` and stops at the first wrong stitch (`core/simulator.gd`). Drawn by `DrawKit.loom` and `DrawKit.loom_shuttle`.

## Related

[Cloth](cloth.md) · [Stitch](stitch.md) · [Tick](tick.md) · [Tube](tube.md)
