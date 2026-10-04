# Tray

- **Tags:** gameplay, design, implementation, temporary (the playtest asked for a good name for the "tool area"; kept as tray for now)
- **Status:** 🟡
- **Journal:** unlocks in One Pot of Red
- **Also called:** parts tray, shelf, tool area (playtest notes)

## Gameplay

The tray along the bottom holds the pieces you can use. Drag one onto the workbench, or tap it to pick it up. A piece with a lock is one this level does without. To put a piece away, drag it back onto the tray.

## Design

- A shelf along the bottom of the workbench, room for about 9 pieces, with the trash at its right end.
- A level offers its own list of pieces. The tray also shows every piece an earlier level offered, locked, so a revisit looks like the first visit; pieces sit in the order the campaign first offers them, so no slot or number key ever moves (DESIGN.md §5.1).
- Keys 1–9 pick up that tray piece. A locked piece only wiggles its lock.
- Planned: the earned pots share one slot that fans out when tapped. Playtest: highlight a new piece in the tray when a level introduces it.

## Implementation

`Level.tray` (the kinds in order, offered or locked), worked out by `Level._lay_trays` from `levels/index.json`, not from the save. Drawn and handled in `ui/workbench.gd`.

## Related

[Piece](piece.md) · [Workbench](workbench.md)
