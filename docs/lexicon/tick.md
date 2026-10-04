# Tick

- **Tags:** gameplay, design, implementation
- **Status:** 🟡 (playtest: neither players nor the designer could say exactly what a tick is)
- **Journal:** unlocks in One Pot of Red; page on the Loom tab

## Gameplay

A tick is one beat of the workshop clock. On every tick, each piece that has paint waiting at every input, and room to send its paint on, does its job once. A pattern card lets out its next drop and the loom weaves one stitch. The clock counts the ticks until your cloth is done: fewer ticks, faster machine.

## Design

- Every piece takes one tick, inventions included, so an invention can make a machine faster without making it cheaper.
- Step moves one tick forward, Step back one tick back; Run keeps ticking at the chosen speed.
- A tick where nothing can move means the machine is stuck.
- The Ticks score is kept per level as best Ticks, apart from best Pieces (DESIGN.md §6).

## Implementation

Not shown in the journal; a reminder for us (`core/simulator.gd`, DESIGN.md §9):

- Every node decides from the state at the start of the tick, so the result never depends on the order nodes are visited.
- A piece fires if every input tube holds a drop and every output tube is empty or is being emptied this same tick (a chain reaction; firing sets only grow as the check repeats).
- A drop made this tick travels along its tube during the tick and waits at the far end.
- Run speeds: 0.55, 0.22 and 0.05 seconds a tick (Normal is the middle one).
- A run gives up after `MAX_TICKS` (20000); `Status.STALLED` is a stuck machine.
- Step back replays the run from the start to one tick earlier (the simulation is deterministic).

## Related

[Tube](tube.md) · [Stitch](stitch.md) · [Piece](piece.md)
