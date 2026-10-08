# Stars

- **Tags:** gameplay, design, implementation
- **Status:** ✅ (DESIGN.md §6)
- **Journal:** unlocks in One Pot of Red; page on the Scores tab
- **Also called:** score, scores (the journal tab)

## Gameplay

Every cloth you weave earns stars: one for weaving it, two for a machine with a low price, three for the lowest price anyone can make it for. Your journal keeps your best stars, your lowest price and your fewest ticks for every level.

## Design

- The kid-friendly face of the optimizer: ★ solved · ★★ at or under the level's budget · ★★★ at or under the best known count (proven minimal by the solver).
- Best Price and best Ticks are kept separately; no run history. The journal's Scores tab is the scoreboard.

## Implementation

`Level.stars_for`; `Progress.record_solve` keeps `stars`, `best_pieces` and `best_ticks` per level.

## Related

[Piece](piece.md) · [Tick](tick.md) · [Journal](journal.md)
