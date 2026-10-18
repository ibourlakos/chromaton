# Piece

- **Tags:** gameplay, design, implementation
- **Status:** 🟡 (in use everywhere, on screen included)
- **Journal:** unlocks in One Pot of Red; pages per piece on the Pieces tab, the player's inventions among them
- **Also called:** component (DESIGN.md); element, unit, tool (loose words from playtests; say piece). Its number is its cost (on screen; "price" 2026-10-08 to 2026-10-18)

## Gameplay

A piece is anything you take from the tray and put in the workshop to build your machine. Every piece has a cost, and the lower your machine's cost, the more stars it earns. Machines you invent become pieces you can use again.

## Design

- **Pieces:** the red pot, the critters (Mix, Filter, Invert, Shift), Split, the catch pot, earned pots and inventions. **Not pieces:** pattern cards and the loom, the fixed parts of a level.
- **Cost:** the red pot and each critter 1; Split and the catch pot are free; an invention costs every piece inside it, nested inventions included; an earned pot costs the cheapest machine the player has made it with.
- **The Cost score** (designer, 2026-10-18; "Price" from playtest R4, 2026-10-08, and "Pieces" before that: the number is the machine's cost, not how many pieces stand on the bench): the total cost of what's on the workbench, kept per level as the best cost (`best_pieces` in saves). "Cost" on the success panel, the Scores tab and under the bench's pieces bar ("Cost 3"); "A cost of N or less." in the level objectives' ★★ and ★★★ rows. ★★ at or under the level's budget, ★★★ at or under the best known count (DESIGN.md §6). The pieces bar fills one wooden slot per piece placed.
- **Ports:** paint goes in on a piece's left through short glass pipes and comes out on its right through wooden spouts; with two ports, the first is on top. [Tubes](tube.md) join an output to an input.
- **Firing:** a piece fires when every input holds a drop and every output tube is empty, or is being emptied the same [tick](tick.md) (a chain reaction). It takes one drop from each input and puts its result in each output. Every piece takes one tick, inventions included.
- On the workbench, one piece per cell. In the [tray](tray.md), a level offers its own list; pieces from earlier levels that it holds back sit there locked.
- On screen today: "Tray piece 1" in Options; each invention's "Cost 4" on its journal page.

## Implementation

`core/pieces.gd`: `TABLE` holds every placeable piece kind (name, ports, operation, cost, `look`); `CARD`, `LOOM` and `INVENTION` are the other node kinds of a machine, and of those only inventions count as pieces. `Pieces.cost` prices a node. A new piece kind also needs a line in `PIECE_NOTES` in `tools/algebra_check.gd`.

## Related

[Critter](critter.md) · [Tray](tray.md) · [Workbench](workbench.md) · [Tube](tube.md)
