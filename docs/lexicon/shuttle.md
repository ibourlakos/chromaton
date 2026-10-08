# Shuttle

- **Tags:** gameplay, design, implementation
- **Status:** 🟡
- **Journal:** unlocks in One Pot of Red; page on the Loom tab

## Gameplay

The shuttle is the little wooden boat that carries thread across the loom. It marks the stitch the loom weaves next, and slides on after every stitch lands. A pattern card has one too, marking the drop that comes next.

## Design

- On the loom the shuttle threads along the row being woven, trailing the weft it lays, and starts a new row from the left edge (DESIGN.md §4).
- Where it stands (✅ designer, playtest R4, 2026-10-08): both shuttles stand in the gap before what they point at, the card's before its next drop, the loom's before the slot it will weave, so neither covers it (the loom's sat on its slot until 2026-10-08).
- It stops where a wrong stitch is: the loom shows the wrong stitch's mark instead of the shuttle, and the card keeps its picture with the drop that wove it ringed and no shuttle.

## Implementation

`DrawKit.shuttle` draws the boat (a card's is smaller); `DrawKit.loom_shuttle` moves it on the loom, `DrawKit.card_paints` on a card.

## Related

[Loom](loom.md) · [Pattern card](pattern-card.md) · [Stitch](stitch.md) · [Thread](thread.md)
