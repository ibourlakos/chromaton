# Workbench

- **Tags:** gameplay, design, implementation
- **Status:** 🟡
- **Journal:** unlocks in One Pot of Red
- **Also called:** bench

## Gameplay

The workbench is where you build. Put pieces on it from the tray and join them with tubes. Paint comes in from the pattern cards on the left, flows to the right, and the loom on the right weaves it into a cloth.

## Design

- Paint flows left to right (DESIGN.md §9.1). The bench is 11 cells deep and 7 wide, one piece per cell; pattern cards sit on its left edge, the loom stands on the right with the design card above it and the pieces bar and Ticks below; the tray runs along the bottom.
- The top bar holds back, the level's name and goal, Paints, Undo, Reset, Step back, Step, Run/Pause and three speeds.
- Any edit rewinds the run; Undo covers every edit. A faint grid can be turned on in Options.

## Implementation

`ui/workbench.gd`, on one design canvas of 1280×800 scaled to the window. It draws in layers that redraw only when what they show changes (its Drawing section); `.\make bench` measures what a frame costs.

## Related

[Tray](tray.md) · [Piece](piece.md) · [Tube](tube.md) · [Paint card](paint-card.md)
