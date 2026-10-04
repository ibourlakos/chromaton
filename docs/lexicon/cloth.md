# Cloth

- **Tags:** gameplay, design, implementation
- **Status:** 🟡
- **Journal:** unlocks in One Pot of Red; every finished cloth hangs on the Cloths tab
- **Also called:** tapestry, quilt (for bigger joined cloths; not settled)

## Gameplay

A cloth is the picture your machine weaves on the loom, stitch by stitch. Every cloth you finish goes into your journal.

## Design

- Pixel art is what the player makes: the cloth is the only pixel art in the game (DESIGN.md §7.2).
- Time is the cloth's vertical axis: rows are woven one after another, top to bottom (DESIGN.md §4).
- A level's design card shows the cloth to weave; a run that weaves it all, with no wrong stitch, solves the level.
- Journal: the Cloths tab is a picture gallery, one slot per level, with empty or greyed slots for cloths not woven yet.
- Chapter payoff idea: a chapter's cloths join into a quilt (🟡).

## Implementation

A solved level's cloth is always its target picture (`target` rows in the level JSON), so the gallery comes from the solved levels with no new save data.

## Related

[Stitch](stitch.md) · [Thread](thread.md) · [Journal](journal.md)

## Open questions

- Cloth, tapestry or quilt for the joined chapter pieces and the finale?
