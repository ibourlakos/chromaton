# Tube

- **Tags:** gameplay, design, implementation
- **Status:** ✅ (2026-10-04: tubes connect pieces; "thread" means a line in the cloth)
- **Journal:** unlocks in One Pot of Red; page on the Loom tab
- **Also called:** thread (the old wire word in DESIGN.md §3, retired), wire

## Gameplay

A glass tube carries paint from one piece to the next: from the spout on a piece's right to the pipe on another's left. A tube holds one drop at a time, so the next drop waits until it's free.

## Design

- Drawn as a glass curve between ports; crossings are allowed (no routing rules yet).
- A drop travels along its tube during the tick it was made, then waits at the far end.
- Lay one by dragging from an output to an input (or the other way); drag its end off an input to re-route or drop it; tap it to select it, then tap its delete button. A tapped tube also shows its last few paints.
- A bundle of parallel tubes (the "braid" of DESIGN.md §3) is a candidate for later.

## Implementation

A machine's tubes are `{"from", "fp", "to", "tp"}` (`core/machine.gd`). In `core/simulator.gd` each tube holds one paint or -1 (`drops`). Drawn by `tube` and `tube_path` in `ui/draw_kit.gd`.

## Related

[Piece](piece.md) · [Tick](tick.md) · [Thread](thread.md)
