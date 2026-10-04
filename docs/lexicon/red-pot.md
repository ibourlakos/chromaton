# Red pot

- **Tags:** gameplay, design, implementation
- **Status:** ✅ (the only basic pot, DESIGN.md §2.5)
- **Journal:** unlocks in One Pot of Red; page on the Pieces tab
- **Also called:** red source (algebra notes), pot

## Gameplay

The red pot makes red paint: a new drop whenever its tube is free. Every other paint in the box starts from this one pot.

## Design

- The one biased source the kit needs: without any pot, nothing can single out one primary (DESIGN.md §2.4). Story beat: "you have one pot of red paint."
- A sleepy clay pot that burps a drop. The other seven pots are earned as inventions in the paint box; from chapter 2 on they join the red pot in its tray slot, which fans out when tapped ([tray](tray.md)).

## Implementation

`red_pot` in `core/pieces.gd` (op `red`, no inputs, cost 1); drawn by `DrawKit.pot`.

## Related

[Piece](piece.md) · [Invention](invention.md) · [Paint](paint.md)
